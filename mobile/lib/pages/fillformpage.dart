import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/ngrok_image.dart';
import '../widgets/rich_text_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// ============================================================
/// MODEL CLASSES
/// ============================================================

class QuestionOption {
  final String id;
  final String label;
  final String? value;
  final int orderIndex;
  final bool isCorrect;
  final bool isOther;

  QuestionOption({
    required this.id,
    required this.label,
    this.value,
    this.orderIndex = 0,
    this.isCorrect = false,
    this.isOther = false,
  });

  factory QuestionOption.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return QuestionOption(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      value: map['value'],
      orderIndex: map['order_index'] ?? 0,
      isCorrect: map['is_correct'] ?? false,
      isOther: map['is_other'] ?? false,
    );
  }
}

class Question {
  final String id;
  final String
  type; // text, single_choice, checkbox, dropdown, date, file_upload
  final String label;
  final String? placeholder;
  final bool isRequired;
  final int orderIndex;
  final Map<String, dynamic> settings;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.isRequired = false,
    this.orderIndex = 0,
    this.settings = const {},
    this.options = const [],
  });

  factory Question.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    final settingsRaw = map['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    final optionsRaw = map['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((o) => QuestionOption.fromJson(o)).toList()
        : <QuestionOption>[];

    return Question(
      id: map['id'] ?? '',
      type: map['type'] ?? 'text',
      label: map['label'] ?? '',
      placeholder: map['placeholder'],
      isRequired: map['is_required'] ?? false,
      orderIndex: map['order_index'] ?? 0,
      settings: settings,
      options: options,
    );
  }

  String? get imageUrl => settings['image_url'] as String?;

  /// Semua URL gambar yang ditempel ke pertanyaan (urut: utama lalu tambahan),
  /// tanpa duplikat dan tanpa nilai kosong.
  List<String> get allImageUrls {
    final list = <String>[];
    final primary = settings['image_url'];
    if (primary is String && primary.isNotEmpty) list.add(primary);
    final extras = settings['image_urls'];
    if (extras is List) {
      for (final e in extras) {
        if (e is String && e.isNotEmpty && !list.contains(e)) list.add(e);
      }
    }
    return list;
  }
}

class FormData {
  final String id;
  final String title;
  final String? description;
  final String? bannerUrl;
  final String slug;
  final String? joinToken;
  final bool acceptResponses;
  final String? startDate;
  final String? endDate;
  // ID pemilik form (dari FormOut.owner_id) — dipakai untuk mode pratinjau
  // pemilik: pembuka yang adalah owner tidak di-join sebagai responden
  // sehingga tidak tercatat di Aktivitas Saya (parity perilaku web).
  final String? ownerId;
  final List<Question> questions;

  FormData({
    required this.id,
    required this.title,
    this.description,
    this.bannerUrl,
    required this.slug,
    this.joinToken,
    this.acceptResponses = true,
    this.startDate,
    this.endDate,
    this.ownerId,
    this.questions = const [],
  });

  factory FormData.fromJson(Map<dynamic, dynamic> json) {
    final map = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json);
    return FormData(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      bannerUrl: map['banner_url'],
      slug: map['slug'] ?? '',
      joinToken: map['join_token'],
      acceptResponses: map['accept_responses'] ?? true,
      startDate: map['start_date'],
      endDate: map['end_date'],
      ownerId: map['owner_id']?.toString(),
      questions:
          (map['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromJson(q as Map))
              .toList() ??
          [],
    );
  }
}

/// ============================================================
/// FillFormPage — Halaman pengisian form via link / QR code
/// ============================================================

class FillFormPage extends StatefulWidget {
  final String slug;

  const FillFormPage({super.key, required this.slug});

  @override
  State<FillFormPage> createState() => _FillFormPageState();
}

class _FillFormPageState extends State<FillFormPage> {
  // States
  bool _isLoading = true;
  String? _errorMsg;
  FormData? _formData;
  String? _submissionId;
  bool _isSubmitted = false;
  bool _isSubmitting = false;

  // Answers: { questionId: { "answer_text": ..., "answer_options": [...] } }
  final Map<String, Map<String, dynamic>> _answers = {};
  // FIX Bug 32: cache TextEditingController per question agar cursor tidak lompat tiap rebuild
  final Map<String, TextEditingController> _textCtrls = {};
  // Soal file_upload yang sedang mengunggah (id) + future-nya utk ditunggu saat submit
  final Set<String> _uploadingQids = {};
  final Map<String, Future<void>> _pendingUploads = {};

  // State opsi "Lainnya" (is_other): teks bebas + status terpilih per soal
  final Map<String, TextEditingController> _otherCtrls = {};
  final Map<String, bool> _otherSelected = {};
  final Map<String, String> _lastOtherText = {};

  // Join Token
  bool _showJoinTokenDialog = false;
  final TextEditingController _joinTokenController = TextEditingController();
  String? _joinTokenError;

  // Mode pratinjau pemilik: pembuka form adalah owner-nya. Ditampilkan
  // read-only tanpa join/submit sehingga tidak tercatat sebagai responden
  // (tidak muncul di Aktivitas Saya, tidak makan kuota max_submissions,
  // tidak mengunci edit soal via 409). Parity perilaku web: owner yang
  // membuka link sendiri tidak menjadi "aktivitas pengisian".
  bool _isOwnerPreview = false;

  /// True jika user login saat ini adalah pemilik [formData].
  /// Gagal mengambil profil → false (fail-open ke alur normal).
  Future<bool> _isOwnerOf(FormData formData, String? token) async {
    try {
      if (token == null) return false;
      final ownerId = formData.ownerId;
      if (ownerId == null || ownerId.isEmpty) return false;
      final me = await ApiService.getMe();
      if (me['success'] != true || me['data'] is! Map) return false;
      final myId = (me['data'] as Map)['id']?.toString();
      return myId != null && myId.isNotEmpty && myId == ownerId;
    } catch (_) {
      return false;
    }
  }

  // Countdown timer (form dengan end_date/jadwal)
  Timer? _countdownTimer;
  DateTime? _countdownEnd;
  Duration _timeLeft = Duration.zero;
  bool _hasAttemptedAutoSubmit = false;

  // Pagination
  static const int _questionsPerPage = 4;
  int _currentPage = 0;

  // Zoom (50%–200%): menskalakan teks form untuk keterbacaan.
  double _zoom = 1.0;
  // Bookmark per soal: id soal yang ditandai + mode filter.
  final Set<String> _bookmarkedQids = {};
  bool _showBookmarkedOnly = false;

  static bool _looksLikeHtml(String s) => s.contains('<');

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _joinTokenController.dispose();
    _countdownTimer?.cancel();
    for (var c in _textCtrls.values) {
      c.dispose();
    }
    for (var c in _otherCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Countdown helper ──────────────────────────────────────
  DateTime? _parseEndDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    // Naik ISO tanpa info zona (mis. dari mobile) dianggap waktu lokal.
    if (!s.contains('Z') && !s.contains('+')) return dt;
    return dt.toLocal();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _hasAttemptedAutoSubmit = false;
    final end = _parseEndDate(_formData?.endDate);
    if (end == null || !end.isAfter(DateTime.now())) {
      _timeLeft = Duration.zero;
      return;
    }
    _countdownEnd = end;
    _timeLeft = end.difference(DateTime.now());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _countdownEnd == null) return;
      final left = _countdownEnd!.difference(DateTime.now());
      if (left <= Duration.zero) {
        _countdownTimer?.cancel();
        setState(() => _timeLeft = Duration.zero);
        _autoSubmitOnTimeout();
      } else {
        setState(() => _timeLeft = left);
      }
    });
  }

  Future<void> _autoSubmitOnTimeout() async {
    // Mode pratinjau pemilik: tidak ada submission → abaikan timer.
    if (_isOwnerPreview) return;
    if (_hasAttemptedAutoSubmit || _isSubmitted || _isSubmitting) return;
    _hasAttemptedAutoSubmit = true;

    if (_submissionId == null) {
      if (mounted) {
        setState(() => _isSubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waktu habis — form ditutup otomatis.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _missingRequired.isEmpty
                ? 'Waktu habis — jawaban dikirim otomatis.'
                : 'Waktu habis — jawaban yang sudah terisi tetap dikirim.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    await _submitForm();
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }

  TextEditingController _getTextCtrl(Question q) {
    var ctrl = _textCtrls[q.id];
    final cur = _answers[q.id]?['answer_text'] ?? '';
    if (ctrl == null) {
      ctrl = TextEditingController(text: cur);
      // capture local reference agar tidak perlu !
      final c = ctrl;
      c.addListener(() => _answers[q.id] = {'answer_text': c.text});
      _textCtrls[q.id] = c;
    } else if (ctrl.text != cur) {
      // sync jika jawaban diupdate dari luar (misal load draft)
      ctrl.text = cur;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    return ctrl;
  }

  /// Safe json decode — return null jika body kosong / bukan JSON
  dynamic _safeJsonDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // API CALLS
  // ============================================================

  Future<void> _loadForm() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }

    try {
      // Login optional: kalau ada token dipakai, kalau tidak pakai identitas anonim
      final token = await ApiService.getToken();
      final respondentKey = await ApiService.getRespondentKey();

      // 1. Fetch form data by slug (publik — boleh tanpa login)
      final formResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respondent-Key': respondentKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      if (formResponse.statusCode != 200) {
        final decoded = _safeJsonDecode(formResponse.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Form tidak ditemukan (${formResponse.statusCode})';
        setState(() {
          _errorMsg = detail;
          _isLoading = false;
        });
        return;
      }

      final formJson = _safeJsonDecode(formResponse.body);
      if (formJson == null) {
        setState(() => _errorMsg = 'Format data form tidak valid');
        return;
      }
      final formData = FormData.fromJson(formJson);
      if (!mounted) return;
      setState(() {
        _formData = formData;
        _isOwnerPreview = false;
      });
      _startCountdown();

      // 2. Pemilik form → mode pratinjau (TANPA join): tidak membuat
      // submission sehingga tidak tercatat di Aktivitas Saya.
      if (await _isOwnerOf(formData, token)) {
        if (!mounted) return;
        setState(() => _isOwnerPreview = true);
        _startCountdown();
        return;
      }

      // 3. Try joining the form (auto-join if no token required)
      await _joinForm(token, null);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinForm(String? token, String? joinToken) async {
    try {
      final body = <String, dynamic>{};
      if (joinToken != null && joinToken.isNotEmpty) {
        body['token'] = joinToken;
      }

      final respondentKey = await ApiService.getRespondentKey();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}/join'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respondent-Key': respondentKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final subJson = _safeJsonDecode(response.body);
        if (subJson == null) {
          setState(() => _errorMsg = 'Format respons tidak valid');
          return;
        }
        setState(() {
          _submissionId = subJson['id'];
          _showJoinTokenDialog = false;
          _joinTokenError = null;
        });

        // Check if already submitted
        if (subJson['submitted_at'] != null) {
          if (!mounted) return;
          setState(() => _isSubmitted = true);
        }
      } else {
        final decoded = _safeJsonDecode(response.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Gagal memulai form (${response.statusCode})';
        final lowerDetail = detail.toLowerCase();

        if (lowerDetail.contains('token') || (_formData?.joinToken != null)) {
          setState(() {
            _showJoinTokenDialog = true;
            _joinTokenError = joinToken != null ? detail : null;
          });
        } else if (lowerDetail.contains('sudah submit')) {
          setState(() => _isSubmitted = true);
        } else {
          setState(() => _errorMsg = detail);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Gagal terhubung ke server');
    }
  }

  Future<bool> _saveAnswer(String questionId) async {
    // Mode pratinjau pemilik: jawaban hanya lokal, tidak autosave ke server.
    if (_isOwnerPreview || _submissionId == null) return false;

    final token = await ApiService.getToken();
    final answer = _answers[questionId];
    if (answer == null) return false;

    try {
      final respondentKey = await ApiService.getRespondentKey();
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/answers'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respondent-Key': respondentKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question_id': questionId,
          'answer_text': answer['answer_text'],
          'answer_options': answer['answer_options'],
          'file_url': answer['file_url'],
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      // Auto-save gagal silent — user tetap bisa lanjut isi
      return false;
    }
  }

  Future<void> _submitForm() async {
    // Mode pratinjau pemilik: tidak ada submission → tidak bisa submit.
    if (_isOwnerPreview) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mode pratinjau pemilik — jawaban tidak dikirim. Uji pengisian tanpa login atau dengan akun lain.'),
          ),
        );
      }
      return;
    }
    if (_submissionId == null) {
      if (mounted) setState(() => _isSubmitted = true);
      return;
    }

    if (mounted) setState(() => _isSubmitting = true);

    // Tunggu semua upload yang masih berjalan agar file ikut tersimpan sebelum finalisasi.
    final pending = _pendingUploads.values.toList();
    if (pending.isNotEmpty) {
      await Future.wait(pending);
      if (!mounted) return;
    }

    try {
      final token = await ApiService.getToken();
      final respondentKey = await ApiService.getRespondentKey();

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/submit'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respondent-Key': respondentKey,
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        _countdownTimer?.cancel();
        setState(() => _isSubmitted = true);
      } else {
        final decoded = _safeJsonDecode(response.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Gagal submit (${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  int get _totalPages {
    if (_formData == null) return 0;
    return (_formData!.questions.length / _questionsPerPage).ceil();
  }

  List<Question> get _currentQuestions {
    if (_formData == null) return [];
    final start = _currentPage * _questionsPerPage;
    final end = (start + _questionsPerPage).clamp(
      0,
      _formData!.questions.length,
    );
    return _formData!.questions.sublist(start, end);
  }

  int get _answeredCount {
    return _answers.values.where((a) {
      final text = a['answer_text'] as String?;
      final options = a['answer_options'] as List?;
      final file = a['file_url'] as String?;
      return (text != null && text.isNotEmpty) ||
          (options != null && options.isNotEmpty) ||
          (file != null && file.isNotEmpty);
    }).length;
  }

  // ── Validasi soal wajib diisi ─────────────────────────────
  bool _isQuestionAnswered(Question q) {
    final a = _answers[q.id];
    if (a == null) return false;
    final text = a['answer_text'] as String?;
    if (text != null && text.isNotEmpty) return true;
    final options = a['answer_options'] as List?;
    if (options != null && options.isNotEmpty) return true;
    final fileUrl = a['file_url'] as String?;
    if (fileUrl != null && fileUrl.isNotEmpty) return true;
    return false;
  }

  List<Question> get _missingRequired {
    if (_formData == null) return const [];
    return _formData!.questions
        .where((q) => q.isRequired && !_isQuestionAnswered(q))
        .toList();
  }

  List<Question> get _missingRequiredOnCurrentPage {
    return _currentQuestions
        .where((q) => q.isRequired && !_isQuestionAnswered(q))
        .toList();
  }

  int _pageOfQuestion(Question q) {
    final idx = _formData?.questions.indexOf(q) ?? 0;
    return idx ~/ _questionsPerPage;
  }

  String _shortLabel(Question q) {
    final t = q.label
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim()
        .replaceAll('\n', ' ');
    return t.length > 28 ? '${t.substring(0, 28)}...' : t;
  }

  void _toggleBookmark(String questionId) {
    setState(() {
      if (!_bookmarkedQids.remove(questionId)) {
        _bookmarkedQids.add(questionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Soal ditandai. Ketuk ikon tanda lagi untuk batal.',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _updateAnswer(String questionId, {String? text, List<String>? options}) {
    setState(() {
      _answers[questionId] = {
        'answer_text': text ?? _answers[questionId]?['answer_text'],
        'answer_options': options ?? _answers[questionId]?['answer_options'],
        'file_url': _answers[questionId]?['file_url'],
      };
    });
    _saveAnswer(questionId);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFB4C5D4),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        RichTextView.stripHtml(_formData?.title ?? 'Memuat Form...'),
        style: const TextStyle(
          color: Color(0xFF374151),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Zoom (${(_zoom * 100).round()}%)',
          icon: const Icon(Icons.zoom_in, color: Color(0xFF374151)),
          onPressed: _showZoomDialog,
        ),
        IconButton(
          tooltip: _showBookmarkedOnly
              ? 'Tampilkan semua soal'
              : 'Tampilkan soal yang ditandai',
          icon: Icon(
            _showBookmarkedOnly ? Icons.filter_alt : Icons.bookmarks_outlined,
            color: _showBookmarkedOnly
                ? const Color(0xFFB45309)
                : const Color(0xFF374151),
          ),
          onPressed: () {
            if (_bookmarkedQids.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Belum ada soal yang ditandai. Ketuk ikon tanda pada soal.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            setState(() {
              _showBookmarkedOnly = !_showBookmarkedOnly;
              if (_showBookmarkedOnly) _currentPage = 0;
            });
          },
        ),
      ],
    );
  }

  void _showZoomDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Ukuran Tampilan (Zoom)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(_zoom * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E66D0),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('50%', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        label: '${(_zoom * 100).round()}%',
                        onChanged: (v) => setDialogState(() {
                          setState(() => _zoom = v);
                        }),
                      ),
                    ),
                    const Text('200%', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Memperbesar/memperkecil ukuran teks form agar mudah dibaca.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(() {
                  setState(() => _zoom = 1.0);
                }),
                child: const Text('Reset 100%'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1E66D0)),
            SizedBox(height: 16),
            Text('Memuat form...', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    // Error state
    if (_errorMsg != null) {
      return _buildErrorState();
    }

    // Join Token Dialog
    if (_showJoinTokenDialog) {
      return _buildJoinTokenForm();
    }

    // Already submitted
    if (_isSubmitted) {
      return _buildSubmittedState();
    }

    // Form content (responden join ATAU pemilik pratinjau)
    if (_formData != null && (_submissionId != null || _isOwnerPreview)) {
      return _buildFormContent();
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // ERROR STATE
  // ============================================================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadForm,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // JOIN TOKEN FORM
  // ============================================================
  Widget _buildJoinTokenForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Color(0xFF1E66D0),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Token Diperlukan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Form "${RichTextView.stripHtml(_formData?.title ?? '')}" membutuhkan token untuk diakses.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _joinTokenController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Masukkan Token',
                  hintStyle: const TextStyle(
                    letterSpacing: 1,
                    fontWeight: FontWeight.normal,
                  ),
                  errorText: _joinTokenError,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E66D0),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final token = await ApiService.getToken();
                    if (token != null) {
                      await _joinForm(token, _joinTokenController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E66D0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mulai Isi Form',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUBMITTED STATE
  // ============================================================
  Widget _buildSubmittedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Jawaban Terkirim!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terima kasih telah mengisi form ini.\nJawaban kamu sudah berhasil disimpan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORM CONTENT
  // ============================================================
  Widget _buildFormContent() {
    // Saat mode "hanya yang ditandai" aktif, tampilkan semua soal yang
    // di-bookmark (ignore pagination) agar mudah navigasi.
    final bookmarkedMode = _showBookmarkedOnly;
    final questions = bookmarkedMode
        ? (_formData?.questions
                  .where((q) => _bookmarkedQids.contains(q.id))
                  .toList() ??
              [])
        : _currentQuestions;

    return Column(
      children: [
        if (bookmarkedMode) _buildBookmarkIndicator(),
        if (!bookmarkedMode) _buildProgressBar(),
        // Banner mode pratinjau pemilik (hanya halaman pertama)
        if (_isOwnerPreview && _currentPage == 0 && !bookmarkedMode)
          _buildOwnerPreviewBanner(),

        // Questions list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(_zoom)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form header (only on first page)
                  if (_currentPage == 0 && !bookmarkedMode) _buildFormHeader(),

                  // Questions
                  if (bookmarkedMode && questions.isEmpty)
                    _buildNoBookmarkState()
                  else
                    ...questions.asMap().entries.map((entry) {
                      return _buildQuestionCard(entry.value, entry.key);
                    }),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // Navigation buttons
        if (!bookmarkedMode) _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildBookmarkIndicator() {
    final count = _bookmarkedQids.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF9C3),
      child: Row(
        children: [
          const Icon(Icons.bookmark, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 0
                  ? 'Belum ada soal yang ditandai'
                  : 'Menampilkan $count soal yang ditandai',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _showBookmarkedOnly = false),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Tutup'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBookmarkState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.bookmark_border, size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          const Text(
            'Belum ada soal yang ditandai',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ketik ikon tanda pada setiap soal untuk mengaturnya.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _formData?.questions.length ?? 0;
    final progress = total > 0 ? _answeredCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_answeredCount / $total terjawab',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Halaman ${_currentPage + 1} / $_totalPages',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1E66D0),
              ),
              minHeight: 6,
            ),
          ),
          if (_timeLeft > Duration.zero) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _timeLeft < const Duration(minutes: 1)
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _timeLeft < const Duration(minutes: 1)
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _timeLeft < const Duration(minutes: 1)
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sisa waktu:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const Spacer(),
                  Text(
                    _formatCountdown(_timeLeft),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _timeLeft < const Duration(minutes: 1)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Banner info mode pratinjau pemilik — menjelaskan mengapa tombol
  /// Submit tidak ada dan mengapa pratinjau tidak masuk Aktivitas Saya.
  Widget _buildOwnerPreviewBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined,
              color: Color(0xFF1E66D0), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau pemilik',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ini form buatanmu. Kamu melihatnya sebagai pratinjau — '
                  'jawaban tidak dikirim dan tidak tercatat di Aktivitas Saya. '
                  'Untuk menguji pengisian, buka link ini tanpa login atau '
                  'dengan akun lain.',
                  style: TextStyle(
                      color: Color(0xFF1E40AF), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          if (_formData?.bannerUrl != null && _formData!.bannerUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 150,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NgrokImage.provider(_formData!.bannerUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          _looksLikeHtml(_formData!.title)
              ? RichTextView(
                  html: _formData!.title,
                  textStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )
              : Text(
                  _formData!.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
          if (_formData?.description != null &&
              _formData!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _looksLikeHtml(_formData!.description!)
                ? RichTextView(
                    html: _formData!.description!,
                    textStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  )
                : Text(
                    _formData!.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formData!.questions.length} pertanyaan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUESTION CARD
  // ============================================================
  Widget _buildQuestionCard(Question question, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question label
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E66D0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: question.label.contains('<')
                    ? RichTextView(
                        html: question.label,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          text: question.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          children: [
                            if (question.isRequired)
                              const TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _toggleBookmark(question.id),
                tooltip: _bookmarkedQids.contains(question.id)
                    ? 'Hapus tanda'
                    : 'Tandai soal ini',
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                icon: Icon(
                  _bookmarkedQids.contains(question.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _bookmarkedQids.contains(question.id)
                      ? const Color(0xFFB45309)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (question.type != 'image' && question.allImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final url in question.allImageUrls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NgrokImage(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),

          // Answer input based on question type
          _buildAnswerInput(question),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(Question question) {
    switch (question.type) {
      case 'text':
      case 'paragraph':
        return _buildTextInput(question);
      case 'single_choice':
        return _buildSingleChoiceInput(question);
      case 'checkbox':
        return _buildCheckboxInput(question);
      case 'dropdown':
        return _buildDropdownInput(question);
      case 'date':
        return _buildDateInput(question);
      case 'time':
        return _buildTextInput(question);
      case 'linear_scale':
        return _buildLinearScaleInput(question);
      case 'rating':
        return _buildRatingInput(question);
      case 'multiple_choice_grid':
      case 'tick_box_grid':
        return _buildGridInput(question);
      case 'file_upload':
        return _buildFileUploadInput(question);
      case 'image':
        final urls = question.allImageUrls;
        if (urls.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final url in urls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NgrokImage(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        );
      case 'text_block':
        return const SizedBox.shrink();
      default:
        return _buildTextInput(question);
    }
  }

  // --- TEXT INPUT ---
  Widget _buildTextInput(Question question) {
    final ctrl = _getTextCtrl(question);
    return TextField(
      controller: ctrl,
      onChanged: (value) => _updateAnswer(question.id, text: value),
      maxLines: 3,
      decoration: InputDecoration(
        hintText: question.placeholder ?? 'Ketik jawaban di sini...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E66D0), width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  // --- SINGLE CHOICE (RADIO) ---
  // Render label opsi sebagai rich text bila berisi markup HTML (dari builder).
  Widget _renderOptionText(String label, TextStyle style) {
    return label.contains('<')
        ? RichTextView(html: label, textStyle: style)
        : Text(label, style: style);
  }

  TextEditingController _otherCtrl(String questionId) {
    return _otherCtrls.putIfAbsent(questionId, () => TextEditingController());
  }

  Widget _buildSingleChoiceInput(Question question) {
    final other = question.options.where((o) => o.isOther).firstOrNull;
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';
    final otherActive = _otherSelected[question.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...question.options.map((option) {
          final isOther = option.isOther;
          final isSelected = isOther
              ? otherActive
              : selectedValue == option.label;
          return InkWell(
            onTap: () {
              if (isOther) {
                setState(() {
                  _otherSelected[question.id] = true;
                  _answers[question.id] = {
                    'answer_text': _otherCtrl(question.id).text,
                    'answer_options': null,
                  };
                });
                _saveAnswer(question.id);
              } else {
                _otherSelected[question.id] = false;
                _otherCtrl(question.id).clear();
                _updateAnswer(question.id, text: option.label);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? const Color(0xFF1E66D0)
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _renderOptionText(
                      option.label,
                      TextStyle(
                        fontSize: 15,
                        color: isSelected
                            ? const Color(0xFF1E40AF)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (other != null && otherActive)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: TextField(
              key: ValueKey('other_${question.id}'),
              controller: _otherCtrl(question.id),
              onChanged: (v) => _updateAnswer(question.id, text: v),
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis jawabanmu...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC7D2FE)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- CHECKBOX (MULTI CHOICE) ---
  Widget _buildCheckboxInput(Question question) {
    final other = question.options.where((o) => o.isOther).firstOrNull;
    final selectedOptions = List<String>.from(
      _answers[question.id]?['answer_options'] ?? [],
    );
    final otherActive = _otherSelected[question.id] ?? false;

    void commit(List<String> newOptions) {
      _updateAnswer(question.id, options: newOptions);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...question.options.map((option) {
          final isOther = option.isOther;
          final isSelected = isOther
              ? otherActive
              : selectedOptions.contains(option.label);
          return InkWell(
            onTap: () {
              final newOptions = List<String>.from(selectedOptions);
              if (isOther) {
                if (otherActive) {
                  _otherSelected[question.id] = false;
                  final last = _lastOtherText[question.id];
                  if (last != null && last.isNotEmpty) {
                    newOptions.remove(last);
                  }
                  _lastOtherText[question.id] = '';
                  _otherCtrl(question.id).clear();
                  commit(newOptions);
                } else {
                  _otherSelected[question.id] = true;
                  final text = _otherCtrl(question.id).text;
                  if (text.isNotEmpty && !newOptions.contains(text)) {
                    newOptions.add(text);
                  }
                  commit(newOptions);
                }
              } else {
                if (isSelected) {
                  newOptions.remove(option.label);
                } else {
                  newOptions.add(option.label);
                }
                commit(newOptions);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E66D0)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: isSelected
                        ? const Color(0xFF1E66D0)
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _renderOptionText(
                      option.label,
                      TextStyle(
                        fontSize: 15,
                        color: isSelected
                            ? const Color(0xFF1E40AF)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (other != null && otherActive)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: TextField(
              key: ValueKey('other_${question.id}'),
              controller: _otherCtrl(question.id),
              onChanged: (v) {
                final newOptions = List<String>.from(
                  (_answers[question.id]?['answer_options'] as List? ?? [])
                      .where((x) => x.toString() != _lastOtherText[question.id])
                      .toList(),
                );
                if (v.isNotEmpty) newOptions.add(v);
                _lastOtherText[question.id] = v;
                commit(newOptions);
              },
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis jawabanmu...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC7D2FE)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- DROPDOWN ---
  Widget _buildDropdownInput(Question question) {
    final selectedValue = _answers[question.id]?['answer_text'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedValue.isEmpty ? null : selectedValue,
          hint: const Text(
            'Pilih jawaban...',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          items: question.options.map((option) {
            return DropdownMenuItem<String>(
              value: option.label,
              child: _renderOptionText(
                option.label,
                const TextStyle(fontSize: 15, color: Color(0xFF374151)),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) _updateAnswer(question.id, text: value);
          },
        ),
      ),
    );
  }

  // --- DATE INPUT ---
  Widget _buildDateInput(Question question) {
    final currentDate = _answers[question.id]?['answer_text'] ?? '';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1E66D0),
                  brightness: Theme.of(context).brightness,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted =
              '${picked.day.toString().padLeft(2, '0')}/'
              '${picked.month.toString().padLeft(2, '0')}/'
              '${picked.year}';
          _updateAnswer(question.id, text: formatted);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              currentDate.isEmpty ? 'Pilih tanggal...' : currentDate,
              style: TextStyle(
                fontSize: 15,
                color: currentDate.isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LINEAR SCALE ---
  Widget _buildLinearScaleInput(Question question) {
    final settings = question.settings;
    final min = settings['scale_min'] ?? 1;
    final max = settings['scale_max'] ?? 5;
    final current =
        int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              settings['min_label'] ?? '$min',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              settings['max_label'] ?? '$max',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(max - min + 1, (i) {
            final val = min + i;
            final selected = current == val;
            return ChoiceChip(
              label: Text('$val'),
              selected: selected,
              onSelected: (_) => _updateAnswer(question.id, text: '$val'),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRatingInput(Question question) {
    final count = (question.settings['rating_count'] as int?) ?? 5;
    final current =
        int.tryParse(_answers[question.id]?['answer_text'] ?? '') ?? 0;
    return Row(
      children: List.generate(count, (i) {
        final filled = i < current;
        return IconButton(
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: const Color(0xFFF59E0B),
          ),
          onPressed: () => _updateAnswer(question.id, text: '${i + 1}'),
        );
      }),
    );
  }

  Widget _buildGridInput(Question question) {
    final rowLabels =
        (question.settings['row_labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Baris 1'];
    final isRadio = question.type == 'multiple_choice_grid';
    final selectedSet =
        (_answers[question.id]?['answer_options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
    // Setiap baris disimpan sebagai "NamaBaris => Opsi" supaya pilihan tiap baris
    // independen (FIX: sebelumnya radio membersihkan seluruh baris → data hilang).
    String keyFor(String row, String label) => '$row => $label';
    return Column(
      children: rowLabels.map((row) {
        final rowKeyPrefix = '$row => ';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _renderOptionText(
                row,
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: question.options.map((opt) {
                  final k = keyFor(row, opt.label);
                  final isSel = selectedSet.contains(k);
                  return FilterChip(
                    label: _renderOptionText(
                      opt.label,
                      const TextStyle(fontSize: 13),
                    ),
                    selected: isSel,
                    onSelected: (_) {
                      final cur = selectedSet.toList();
                      if (isRadio) {
                        cur.removeWhere((e) => e.startsWith(rowKeyPrefix));
                        cur.add(k);
                      } else {
                        if (cur.contains(k)) {
                          cur.remove(k);
                        } else {
                          cur.add(k);
                        }
                      }
                      _updateAnswer(question.id, text: null, options: cur);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- FILE UPLOAD ---
  Widget _buildFileUploadInput(Question question) {
    final fileUrl = _answers[question.id]?['file_url'] as String?;
    final uploading = _uploadingQids.contains(question.id);
    final colorScheme = Theme.of(context).colorScheme;

    final Widget content;
    if (uploading) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 10),
          Text(
            'Mengunggah file…',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      final fileName = _fileNameFromUrl(fileUrl);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 40, color: Color(0xFF059669)),
          const SizedBox(height: 8),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'File berhasil diunggah',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickAndUploadFile(question),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Ganti'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              TextButton.icon(
                onPressed: () => _removeFile(question),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Hapus'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 40,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap untuk upload file',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            'Gambar, video, PDF, atau file lain',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return InkWell(
      onTap: uploading ? null : () => _pickAndUploadFile(question),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: content,
      ),
    );
  }

  Future<void> _pickAndUploadFile(Question question) async {
    // Mode pratinjau pemilik: jangan mengunggah file ke server.
    if (_isOwnerPreview) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mode pratinjau pemilik — upload file dinonaktifkan.'),
          ),
        );
      }
      return;
    }
    if (_uploadingQids.contains(question.id)) return;

    final source = await showModalBottomSheet<_FileSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Upload File',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, _FileSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, _FileSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Dokumen / File lain'),
              onTap: () => Navigator.pop(ctx, _FileSource.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    Uint8List? bytes;
    var fileName = '';
    try {
      if (source == _FileSource.gallery || source == _FileSource.camera) {
        final img = await ImagePicker().pickImage(
          source: source == _FileSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          maxWidth: 2048,
          imageQuality: 85,
        );
        if (img == null) return;
        bytes = await img.readAsBytes();
        fileName = img.name;
      } else {
        final picked = await FilePicker.pickFile();
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        fileName = picked.name;
      }
      if (bytes.isEmpty) return;
      final upload = _performUpload(question, bytes, fileName);
      _pendingUploads[question.id] = upload;
      try {
        await upload;
      } finally {
        _pendingUploads.remove(question.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memilih file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performUpload(
    Question question,
    Uint8List bytes,
    String fileName,
  ) async {
    if (_submissionId == null) return;

    setState(() => _uploadingQids.add(question.id));
    try {
      final token = await ApiService.getToken();
      final respondentKey = await ApiService.getRespondentKey();

      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiService.baseUrl}/uploads'),
            )
            ..headers['X-Respondent-Key'] = respondentKey
            // Ngrok free mewajibkan header ini (konsisten dgn ApiService._uploadOnce);
            // tanpanya request bisa diarahkan ke halaman interstitial sehingga upload gagal.
            ..headers['ngrok-skip-browser-warning'] = 'true'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: fileName,
                contentType: null,
              ),
            );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        final fileUrl = (data is Map) ? data['file_url'] : null;
        if (fileUrl is String && fileUrl.isNotEmpty) {
          setState(() {
            _answers[question.id] = {
              'answer_text': null,
              'answer_options': null,
              'file_url': fileUrl,
            };
          });
          final saved = await _saveAnswer(question.id);
          if (!saved && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'File terunggah, tapi belum tersinkron — coba lagi',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File berhasil diunggah'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengunggah file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final decoded = _safeJsonDecode(response.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Gagal mengunggah (${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingQids.remove(question.id));
    }
  }

  void _removeFile(Question question) {
    setState(() {
      _answers[question.id] = {
        'answer_text': null,
        'answer_options': null,
        'file_url': null,
      };
    });
    _saveAnswer(question.id);
  }

  String _fileNameFromUrl(String url) {
    final segment = url.split('/').last;
    try {
      var name = Uri.decodeComponent(segment);
      if (name.length > 32) name = '${name.substring(0, 29)}...';
      return name;
    } catch (_) {
      return segment;
    }
  }

  // ============================================================
  // NAVIGATION BUTTONS
  // ============================================================
  Widget _buildNavigationButtons() {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (!isFirstPage)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentPage--),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Sebelumnya'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          if (!isFirstPage && !isLastPage) const SizedBox(width: 12),

          // Next / Submit button (mode pratinjau pemilik: tanpa Submit)
          Expanded(
            child: (_isOwnerPreview && isLastPage)
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text(
                          'Mode pratinjau',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (isLastPage) {
                              _showSubmitConfirmation();
                            } else {
                              _handleNext();
                            }
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isLastPage ? Icons.send : Icons.arrow_forward,
                            size: 18,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'Mengirim...'
                          : isLastPage
                          ? 'Submit'
                          : 'Selanjutnya',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPage
                          ? const Color(0xFF059669)
                          : const Color(0xFF1E66D0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT CONFIRMATION DIALOG
  // ============================================================
  void _handleNext() {
    final missing = _missingRequiredOnCurrentPage;
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wajib diisi di halaman ini: ${missing.take(3).map(_shortLabel).join(', ')}${missing.length > 3 ? ', ...' : ''}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    setState(() => _currentPage++);
  }

  void _showSubmitConfirmation() {
    final missing = _missingRequired;
    if (missing.isNotEmpty) {
      // Karena ada yang belum dijawab: lompat ke halaman pertama yang belum lengkap.
      if (_currentPage != _pageOfQuestion(missing.first)) {
        setState(() => _currentPage = _pageOfQuestion(missing.first));
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
              SizedBox(width: 10),
              Text('Masih Ada yang Kosong'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${missing.length} soal wajib belum dijawab. Lengkapi dulu ya:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                ...missing
                    .take(8)
                    .map(
                      (q) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _shortLabel(q),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (missing.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'dan ${missing.length - 8} soal lainnya...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _currentPage = _pageOfQuestion(missing.first));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lengkapi'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send, color: Color(0xFF059669)),
            SizedBox(width: 12),
            Text('Kirim Jawaban?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu telah menjawab $_answeredCount dari ${_formData?.questions.length ?? 0} pertanyaan.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setelah dikirim, jawaban tidak bisa diubah lagi.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Kirim!'),
          ),
        ],
      ),
    );
  }
}

enum _FileSource { gallery, camera, file }
