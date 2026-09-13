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

// Model dipindah ke fill_form/models/fill_form_models.dart (Tahap 1).
// import: agar file ini sendiri tetap mengenal FormData/Question.
// export: agar import lama `import 'fillformpage.dart'` dari file lain
// yang memakai FormData/Question tetap kompilasi tanpa perubahan.
import 'fill_form/models/fill_form_models.dart';
export 'fill_form/models/fill_form_models.dart';

// Part: input jawaban (dispatcher, teks, single-choice) — Tahap 2a.
// Sama-sama satu library, jadi akses state privat tetap sah & call-site
// (`_buildAnswerInput(question)`) tidak berubah.
part 'fill_form/answer_inputs_part.dart';

// Part: display widgets (bookmark, progress, banner, header, kartu soal)
// — Tahap 3a. Sama-sama satu library, call-site tidak berubah.
part 'fill_form/display_part.dart';

// Part: navigasi bawah + konfirmasi submit — Tahap 3b.
// Sama-sama satu library, call-site tidak berubah.
part 'fill_form/navigation_part.dart';

/// ============================================================
/// FillFormPage — Halaman pengisian form via link / QR code
/// (orkestrator; model ada di fill_form/models/fill_form_models.dart)
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

  // Dipakai extension input jawaban (fill_form/answer_inputs_part.dart):
  // setState HANYA boleh di member State — extension tidak boleh memanggilnya
  // langsung (lint invalid_use_of_protected_member). Isi = pindahan verbatim
  // blok onTap "Lainnya" single-choice, tanpa perubahan urutan/isi.
  void _selectSingleChoiceOther(Question question) {
    setState(() {
      _otherSelected[question.id] = true;
      _answers[question.id] = {
        'answer_text': _otherCtrl(question.id).text,
        'answer_options': null,
      };
    });
    _saveAnswer(question.id);
  }

  // Helper upload file untuk extension input jawaban
  // (fill_form/answer_inputs_part.dart): setState HANYA di member State.
  // Isi = pindahan verbatim dari _performUpload/_removeFile sekitarnya.
  void _markUploadStarted(Question question) {
    setState(() => _uploadingQids.add(question.id));
  }

  // Terapkan URL hasil upload ke jawaban + sinkronkan; kembalikan hasil save.
  Future<bool> _applyUploadedFileUrl(Question question, String fileUrl) {
    setState(() {
      _answers[question.id] = {
        'answer_text': null,
        'answer_options': null,
        'file_url': fileUrl,
      };
    });
    return _saveAnswer(question.id);
  }

  void _markUploadFinished(String questionId) {
    if (mounted) setState(() => _uploadingQids.remove(questionId));
  }

  // Helper filter bookmark untuk extension display
  // (fill_form/display_part.dart): setState HANYA di member State.
  // Isi = pindahan verbatim callback "Tutup" _buildBookmarkIndicator.
  void _clearBookmarkFilter() {
    setState(() => _showBookmarkedOnly = false);
  }

  // Helper navigasi halaman untuk extension navigation
  // (fill_form/navigation_part.dart): setState HANYA di member State.
  // Isi = pindahan verbatim tiap situs setState navigasi.
  void _goToPreviousPage() {
    setState(() => _currentPage--);
  }

  void _goToNextPage() {
    setState(() => _currentPage++);
  }

  void _jumpToQuestionPage(Question question) {
    setState(() => _currentPage = _pageOfQuestion(question));
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

  // NOTE (Tahap 3a): _buildBookmarkIndicator, _buildNoBookmarkState,
  // _buildProgressBar pindah ke fill_form/display_part.dart.
  // setState "Tutup" filter didelegasikan ke _clearBookmarkFilter di atas
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 3a): _buildOwnerPreviewBanner, _buildFormHeader,
  // _buildQuestionCard (+ header section QUESTION CARD) pindah ke
  // fill_form/display_part.dart (tanpa perubahan logika/call-site).

  // NOTE (Tahap 2a): _buildAnswerInput, _buildTextInput, _renderOptionText,
  // _otherCtrl, _buildSingleChoiceInput pindah ke
  // fill_form/answer_inputs_part.dart (extension FillFormAnswerInputs,
  // satu library via `part of` — tanpa perubahan logika/call-site).

  // NOTE (Tahap 2b): _buildCheckboxInput pindah ke
  // fill_form/answer_inputs_part.dart (tanpa perubahan logika/call-site).

  // NOTE (Tahap 2b): _buildDropdownInput, _buildDateInput,
  // _buildLinearScaleInput, _buildRatingInput pindah ke
  // fill_form/answer_inputs_part.dart (tanpa perubahan logika/call-site).

  // NOTE (Tahap 2c): _buildGridInput & _buildFileUploadInput pindah ke
  // fill_form/answer_inputs_part.dart (tanpa perubahan logika/call-site).

  // NOTE (Tahap 2c): _pickAndUploadFile & _performUpload pindah ke
  // fill_form/answer_inputs_part.dart; setState-nya didelegasikan ke
  // _markUploadStarted/_applyUploadedFileUrl/_markUploadFinished di atas
  // (urutan + isi statement identik). _removeFile tetap di State.

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

  // NOTE (Tahap 2c): _fileNameFromUrl (murni, tanpa state) pindah ke
  // fill_form/answer_inputs_part.dart.

  // ============================================================
  // NAVIGATION BUTTONS
  // ============================================================
  // NOTE (Tahap 3b): _buildNavigationButtons & _handleNext pindah ke
  // fill_form/navigation_part.dart; setState dinavigasi didelegasikan ke
  // _goToPreviousPage/_goToNextPage/_jumpToQuestionPage di atas
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 3b): _showSubmitConfirmation pindah ke
  // fill_form/navigation_part.dart (tanpa perubahan logika/call-site).
}

enum _FileSource { gallery, camera, file }
