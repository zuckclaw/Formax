import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/ngrok_image.dart';
import '../widgets/rich_text_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/activity_model.dart';
import 'submission_result_page.dart';

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

class _FillFormPageState extends State<FillFormPage>
    with WidgetsBindingObserver {
  // States
  bool _isLoading = true;
  String? _errorMsg;
  FormData? _formData;
  String? _submissionId;
  bool _isSubmitted = false;
  bool _isSubmitting = false;
  bool _loadingResult = false;

  // Anti-cheat fullscreen (parity web require_fullscreen):
  // - Form dengan require_fullscreen wajib mulai via intro "Mulai" (immersive).
  // - Keluar aplikasi (AppLifecycle paused/inactive/detached) saat ujian
  //   berjalan → tandai curang SEKALI via POST flag-cheated (seperti web
  //   fullscreenchange/visibilitychange → flagCheated).
  bool _isCheated = false;
  bool _cheatedFlagSent = false;
  bool _fullscreenStarted = false;
  bool _showFullscreenIntro = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadForm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Mobile setara web visibilitychange/fullscreenchange: user keluar
    // aplikasi (home, recent-app, pindah aplikasi, layar mati) saat ujian
    // fullscreen berjalan dianggap keluar fullscreen → tandai curang.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _handleAntiCheatTrigger();
    }
  }

  /// Tandai curang sekali (parity web handleFullscreenExit).
  Future<void> _handleAntiCheatTrigger() async {
    if (_cheatedFlagSent || _isSubmitted || _isSubmitting) return;
    if (_formData?.requireFullscreen != true) return;
    if (!_fullscreenStarted || _submissionId == null) return;
    _cheatedFlagSent = true;
    if (mounted) setState(() => _isCheated = true);
    try {
      await ApiService.flagCheated(_submissionId!);
    } catch (_) {
      // best-effort seperti web (.catch(() => {})) — banner lokal tetap tampil
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Keluar aplikasi terdeteksi — submission ditandai curang. Kamu tetap bisa melanjutkan.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Masuk mode layar penuh imersif (parity web enterFullscreen).
  Future<void> _enterFullscreen() async {
    setState(() {
      _fullscreenStarted = true;
      _showFullscreenIntro = false;
    });
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // best-effort — lanjut walau System UI gagal disembunyikan
    }
  }

  /// Keluar mode imersif — dipanggil saat submit / dispose.
  Future<void> _exitFullscreenMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitFullscreenMode();
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
    final normalized = s.trim().replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return null;
    // Naik ISO tanpa info zona (mis. dari mobile/web) dianggap waktu lokal.
    if (!normalized.contains('Z') && !normalized.contains('+')) return dt;
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
      // FAIL-CLOSED (anti-anonim, parity web PrivateRoute /f/:slug):
      // halaman form WAJIB dibuka dengan sesi login. Tanpa token →
      // bersihkan state + kembali ke Login, JANGAN lanjut sebagai anonim.
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        await ApiService.forceLogout();
        return;
      }
      final respondentKey = await ApiService.getRespondentKey();

      // 1. Fetch form data by slug
      final formResponse = await ApiService.client.get(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}'),
        headers: ApiService.defaultHeaders(
          token: token,
          respondentKey: respondentKey,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (formResponse.statusCode != 200) {
        final decoded = _safeJsonDecode(formResponse.body);
        final detail = (decoded is Map && decoded['detail'] != null)
            ? decoded['detail'].toString()
            : 'Form tidak ditemukan (${formResponse.statusCode})';
        // 401/403 sesi invalid (backend: "Token tidak valid atau
        // kadaluarsa") → sesi mati → force logout, bukan error biasa.
        if (_isSessionAuthFailure(
            formResponse.statusCode, decoded, detail)) {
          await ApiService.forceLogout();
          return;
        }
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
      });
      _startCountdown();

      // Parity web: pemilik BOLEH mengisi form sendiri (join + submit normal).
      // Backend tidak melarang owner join, jadi mobile jangan memblokir.
      // 3. Try joining the form (auto-join if no token required)
      await _joinForm(token, null);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      // Fail-closed: backend tak terjangkau (mati/timeout/refused) saat
      // membuka form → sesi tak bisa divalidasi → force logout.
      if (_isTransportFailure(e)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() => _errorMsg = 'Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// True jika error adalah kegagalan transport (backend down/timeout).
  static bool _isTransportFailure(Object e) {
    final s = e.toString().toLowerCase();
    return e is TimeoutException ||
        s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('connection closed') ||
        s.contains('network is unreachable') ||
        s.contains('connection timed out');
  }

  /// True jika status/detail menunjukkan SESI invalid (bukan error form).
  /// Cermin matcher backend 401 "Token tidak valid atau kadaluarsa".
  static bool _isSessionAuthFailure(
      int statusCode, dynamic decoded, String detail) {
    if (statusCode != 401 && statusCode != 403) return false;
    final d = detail.toLowerCase();
    return d.contains('tidak valid') ||
        d.contains('kadaluarsa') ||
        d.contains('unauthorized') ||
        d.contains('silakan login');
  }

  Future<void> _joinForm(String? token, String? joinToken) async {
    try {
      final body = <String, dynamic>{};
      if (joinToken != null && joinToken.isNotEmpty) {
        body['token'] = joinToken;
      }

      final respondentKey = await ApiService.getRespondentKey();
      final response = await ApiService.client.post(
        Uri.parse('${ApiService.baseUrl}/forms/public/${widget.slug}/join'),
        headers: ApiService.defaultHeaders(
          token: token,
          respondentKey: respondentKey,
        ),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _safeJsonDecode(response.body);
        if (decoded is! Map) {
          setState(() => _errorMsg = 'Format respons tidak valid');
          return;
        }
        final subJson = Map<String, dynamic>.from(decoded);
        setState(() {
          _submissionId = subJson['id'];
          _showJoinTokenDialog = false;
          _joinTokenError = null;
        });

        // Parity web: submission yang sudah ditandai curang tetap tampil + banner.
        if (subJson['is_cheated'] == true) {
          if (!mounted) return;
          setState(() {
            _isCheated = true;
            _cheatedFlagSent = true;
          });
        } else if (_formData?.requireFullscreen == true &&
            subJson['submitted_at'] == null) {
          // Parity web: form fullscreen wajib mulai via intro overlay.
          if (!mounted) return;
          setState(() => _showFullscreenIntro = true);
        }

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

        // Fail-closed DULU: 401/403 sesi ("Token tidak valid atau
        // kadaluarsa") bukan join-token form ("Token salah atau belum
        // diisi"). Sesi mati → logout, jangan tampilkan dialog token.
        if (_isSessionAuthFailure(
            response.statusCode, decoded, detail)) {
          await ApiService.forceLogout();
          return;
        }
        if (lowerDetail.contains('token') || (_formData?.requireJoinToken == true)) {
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
      // Fail-closed: join gagal karena transport → force logout.
      if (_isTransportFailure(e)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() => _errorMsg = 'Gagal terhubung ke server');
    }
  }

  Future<bool> _saveAnswer(String questionId) async {
    if (_submissionId == null) return false;

    final token = await ApiService.getToken();
    final answer = _answers[questionId];
    if (answer == null) return false;

    try {
      final respondentKey = await ApiService.getRespondentKey();
      final response = await ApiService.client.put(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/answers'),
        headers: ApiService.defaultHeaders(
          token: token,
          respondentKey: respondentKey,
        ),
        body: jsonEncode({
          'question_id': questionId,
          'answer_text': answer['answer_text'],
          'answer_options': answer['answer_options'],
          'file_url': answer['file_url'],
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      // Auto-save gagal silent — user tetap bisa lanjut isi
      return false;
    }
  }

  Future<void> _submitForm() async {
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

      final response = await ApiService.client.post(
        Uri.parse('${ApiService.baseUrl}/submissions/$_submissionId/submit'),
        headers: ApiService.defaultHeaders(
          token: token,
          respondentKey: respondentKey,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        _countdownTimer?.cancel();
        // Parity web: keluar fullscreen setelah submit selesai.
        await _exitFullscreenMode();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark
        ? Theme.of(context).colorScheme.onSurface
        : const Color(0xFF374151);

    return AppBar(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFB4C5D4),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: fgColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        RichTextView.stripHtml(_formData?.title ?? 'Memuat Form...'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fgColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
      actions: [
        if (_timeLeft > Duration.zero)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _timeLeft < const Duration(minutes: 1)
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCountdown(_timeLeft),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          tooltip: 'Zoom (${(_zoom * 100).round()}%)',
          icon: const Icon(Icons.zoom_in, color: Color(0xFF374151)),
          onPressed: _showZoomDialog,
        ),
        IconButton(
          tooltip: _showBookmarkedOnly
              ? 'Tampilkan semua soal'
              : 'Tampilkan soal yang ditandai',          icon: Icon(
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
        // Info akun (parity web profile popover: nama, email, status).
        IconButton(
          tooltip: 'Info akun',
          icon: const Icon(Icons.account_circle_outlined,
              color: Color(0xFF374151)),
          onPressed: _showAccountSheet,
        ),
      ],
    );
  }

  /// Bottom sheet info akun responden (nama, email, status login).
  Future<void> _showAccountSheet() async {
    final res = await ApiService.getMe();
    if (!mounted) return;
    String name = 'Pengguna';
    String email = '-';
    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      name = (data['full_name'] ?? 'Pengguna').toString();
      email = (data['email'] ?? '-').toString();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF1E40AF),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        'Masuk sebagai responden',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    // Parity web: form fullscreen wajib mulai via intro overlay.
    if (_showFullscreenIntro &&
        _formData?.requireFullscreen == true &&
        !_isSubmitted) {
      return _buildFullscreenIntro();
    }

    // Already submitted
    if (_isSubmitted) {
      return _buildSubmittedState();
    }

    // Form content (responden join — termasuk pemilik, parity web)
    if (_formData != null && _submissionId != null) {
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x2EEF4444)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
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
              Text(
                'Token Diperlukan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Form "${RichTextView.stripHtml(_formData?.title ?? '')}" membutuhkan token untuk diakses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Builder(builder: (context) {
                final isDark =
                    Theme.of(context).brightness == Brightness.dark;
                return TextField(
                  controller: _joinTokenController,
                  textAlign: TextAlign.center,
                  // Warna ketikan eksplisit: hitam di terang, terang di gelap.
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan Token',
                    hintStyle: TextStyle(
                      letterSpacing: 1,
                      fontWeight: FontWeight.normal,
                      color: isDark
                          ? const Color(0xFF7A8599)
                          : const Color(0xFF9CA3AF),
                    ),
                    errorText: _joinTokenError,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A4A)
                        : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF3A3A5C)
                              : const Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: Color(0xFF1E66D0),
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Parity web: join token boleh anonim — teruskan token
                    // apa adanya (bisa null, identitas via respondent-key).
                    final token = await ApiService.getToken();
                    await _joinForm(token, _joinTokenController.text.trim());
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
  // FULLSCREEN INTRO + CHEATED BANNER (parity web require_fullscreen)
  // ============================================================
  /// Overlay wajib fullscreen: pengguna harus tekan "Mulai" (masuk imersif)
  /// sebelum bisa mengisi. Keluar aplikasi setelah mulai → ditandai curang.
  Widget _buildFullscreenIntro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: const Color(0xFF2D2D4A))
                : null,
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
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.fullscreen,
                  size: 40,
                  color: isDark
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF1E66D0),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mode Layar Penuh',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Form "${RichTextView.stripHtml(_formData?.title ?? '')}" mewajibkan mode layar penuh. '
                'Selama mengisi, JANGAN keluar aplikasi / pindah aplikasi — '
                'submission Anda akan ditandai sebagai curang oleh sistem.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enterFullscreen,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Mulai',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E66D0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner peringatan curang (parity web .cheated-banner).
  Widget _buildCheatedBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x2EEF4444) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFB91C1C),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ditandai curang',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submission Anda ditandai curang karena keluar aplikasi / keluar dari mode layar penuh. Anda tetap bisa melanjutkan.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubmissionResult() async {
    if (_submissionId == null) return;
    setState(() => _loadingResult = true);
    try {
      final res = await ApiService.getSubmissionResult(_submissionId!);
      if (!mounted) return;
      if (res['success'] != true || res['data'] is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat hasil: ${res['message'] ?? 'Respons tidak valid'}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      final result = ActivityResultModel.fromJson(
        Map<String, dynamic>.from(res['data'] as Map),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubmissionResultPage(result: result),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat memuat hasil: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingResult = false);
    }
  }

  // ============================================================
  // SUBMITTED STATE
  // ============================================================
  Widget _buildSubmittedState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formTitle = _formData?.title ?? 'Formulir';
    final canSeeResult = (_formData?.allowSeeResult == true) && _submissionId != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23233F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Checkmark Circle Icon
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                      : const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Jawaban Berhasil Terkirim!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Terima kasih telah mengisi $formTitle. Jawaban Anda telah tersimpan dengan aman di server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              // Parity web: submission curang tetap bisa submit, tampilkan banner.
              if (_isCheated) ...[
                const SizedBox(height: 16),
                _buildCheatedBanner(),
              ],
              const SizedBox(height: 28),
              // Action Buttons
              if (canSeeResult) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loadingResult ? null : _openSubmissionResult,
                    icon: _loadingResult
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.assignment_turned_in_rounded, size: 20),
                    label: Text(
                      _loadingResult ? 'Memuat Hasil...' : 'Lihat Hasil & Rincian Jawaban',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Kembali ke Halaman Utama'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF1E66D0),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E66D0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
        // Parity web success-cheated-banner: tampil di atas daftar soal.
        if (_isCheated && !bookmarkedMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildCheatedBanner(),
          ),

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

  // NOTE (Tahap 3a): _buildFormHeader,
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
