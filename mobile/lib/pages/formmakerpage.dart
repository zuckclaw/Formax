import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../utils/quill_html.dart';
import '../widgets/share_form_dialog.dart';
import 'form_maker/models/form_builder_state.dart';
import 'form_maker/editor_canvas.dart';
import 'form_maker/preview_canvas.dart';
import 'form_maker/components/form_settings_tab.dart';
import '../models/question_model.dart'; // Ensure QuestionType is imported for toolbar
import 'package:image_picker/image_picker.dart';

class FormMakerResult {
  final String? draftFormId;
  final String? draftFormTitle;
  final FormTemplate? template;

  const FormMakerResult({this.draftFormId, this.draftFormTitle, this.template});

  bool get savedDraft => draftFormId != null && draftFormId!.isNotEmpty;
  bool get savedTemplate => template != null;
}

class FormMakerPage extends StatefulWidget {
  final FormTemplate? initialTemplate;

  /// JSON lengkap form draft (dari GET /forms/{id}) untuk dilanjutkan editing.
  final Map<String, dynamic>? initialDraft;

  const FormMakerPage({super.key, this.initialTemplate, this.initialDraft});

  @override
  State<FormMakerPage> createState() => _FormMakerPageState();
}

class _FormMakerPageState extends State<FormMakerPage>
    with SingleTickerProviderStateMixin {
  late FormBuilderState _builderState;
  late TabController _tabController;
  bool _isPreviewMode = false;
  String? _draftTemplateId; // untuk PATCH template (bukan POST berulang)
  String?
  _draftFormId; // untuk PATCH form draft (bukan POST berulang / duplikat)

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgColor = const Color(0xFFE8EEF7);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _currentBgColor => _isDark ? const Color(0xFF0F172A) : _bgColor;
  Color get _cardColor => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : Colors.black87;
  Color get _subTextColor => _isDark ? const Color(0xFF94A3B8) : Colors.black54;
  Color get _appBarIconColor =>
      _isDark ? const Color(0xFFCBD5E1) : Colors.black54;

  // State untuk Setelan
  bool _isQuiz = true;
  String _releaseGrade = 'langsung';
  bool _missedQuestions = true;
  bool _correctAnswers = false;
  bool _revealAnswers = false;
  bool _pointValues = true;

  String _sendCopy = 'Nonaktif';
  // Setelan Form (parity dengan web): status, penerimaan respons, batas respons, fullscreen, join token.
  String _formStatus = 'draft'; // draft / published / closed
  bool _acceptResponses = true;
  String _submissionLimit = 'once'; // once / unlimited / custom
  final TextEditingController _customSubLimitCtrl = TextEditingController(
    text: '2',
  );
  bool _requireFullscreen = false;
  bool _useJoinToken = false;
  bool _shuffleQuestions = false;
  bool _shuffleOptions = false;
  bool _hideResponses = false;
  bool _allowMultipleEdits = false;

  bool _requireQuestionDefault = false;

  bool _enableTimer = true;
  String _timerMode = 'Start when respondent opens the form';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _durationCtrl = TextEditingController(text: '1');
  String _durationUnit = 'hari';
  final TextEditingController _pointValueCtrl = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialDraft != null) {
      final map = Map<String, dynamic>.from(widget.initialDraft!);
      _draftFormId = map['id']?.toString();
      _applyFormSettings(map);
      _builderState = FormBuilderState.fromForm(map);
    } else if (widget.initialTemplate != null) {
      _builderState = FormBuilderState.fromTemplate(widget.initialTemplate!);
      _draftTemplateId = widget.initialTemplate!.id;
    } else {
      _builderState = FormBuilderState();
    }
  }

  // Muat setelan form dari draft (GET /forms/{id}) supaya panel Setelan
  // menampilkan status & limit yang benar saat lanjutkan draft.
  void _applyFormSettings(Map<String, dynamic> map) {
    _formStatus = map['status']?.toString() ?? 'draft';
    _acceptResponses = map['accept_responses'] as bool? ?? true;
    _requireFullscreen = map['require_fullscreen'] as bool? ?? false;
    _correctAnswers = map['allow_see_result'] as bool? ?? false;
    _revealAnswers =
        _correctAnswers && (map['reveal_answers'] as bool? ?? false);
    _useJoinToken = map['join_token']?.toString().isNotEmpty ?? false;
    _shuffleQuestions = map['shuffle_questions'] as bool? ?? false;
    _shuffleOptions = map['shuffle_options'] as bool? ?? false;
    _startDate = _parseDate(map['start_date']);
    _endDate = _parseDate(map['end_date']);
    if (_startDate != null || _endDate != null) {
      _timerMode = 'Start at a specific date and time';
    }
    final maxSub = map['max_submissions'];
    if (maxSub is int) {
      if (maxSub == 1) {
        _submissionLimit = 'once';
      } else if (maxSub == 0) {
        _submissionLimit = 'unlimited';
      } else {
        _submissionLimit = 'custom';
        _customSubLimitCtrl.text = '$maxSub';
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _pickTimerDate({required bool start}) async {
    final current = start ? _startDate : _endDate;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime.now(),
    );
    if (!mounted || pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (!mounted || pickedTime == null) return;
    final value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (start) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  String _formatTimerDate(DateTime? value) {
    if (value == null) return 'Pilih tanggal dan waktu';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  int _getDurationValue() {
    final raw = _durationCtrl.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
    final numMatch = RegExp(r'\d+').firstMatch(raw);
    final value = int.tryParse(numMatch?.group(0) ?? '1') ?? 1;
    return value < 1 ? 1 : value;
  }

  Duration _getDurationValueAsDuration() {
    final value = _getDurationValue();
    switch (_durationUnit) {
      case 'detik':
        return Duration(seconds: value);
      case 'menit':
        return Duration(minutes: value);
      case 'jam':
        return Duration(hours: value);
      case 'bulan':
        return Duration(days: value * 30);
      case 'tahun':
        return Duration(days: value * 365);
      case 'hari':
      default:
        return Duration(days: value);
    }
  }

  String get _durationDisplayText =>
      '${_durationCtrl.text.trim()} $_durationUnit';

  @override
  void dispose() {
    _builderState.dispose();
    _tabController.dispose();
    _durationCtrl.dispose();
    _pointValueCtrl.dispose();
    _customSubLimitCtrl.dispose();
    super.dispose();
  }

  String _networkHint(String msg) {
    return msg.contains('SocketException') ||
            msg.contains('Failed host') ||
            msg.contains('Connection refused') ||
            msg.contains('No token')
        ? '\n\nCek: backend jalan di ${ApiService.baseUrl}?\nEmulator: 10.0.2.2:8000 | HP fisik: adb reverse tcp:8000 tcp:8000 + --dart-define=API_URL=http://127.0.0.1:8000'
        : '';
  }

  void _syncTitleFromPage() {
    if (_builderState.pages.isNotEmpty) {
      _builderState.formTitle = _builderState.pages[0].title;
      _builderState.formDescription = _builderState.pages[0].description;
    }
  }

  Map<String, dynamic> _buildPublishSettings() {
    // Fix: sesuaikan dengan web â€” hanya kirim start/end_date jika Form Timer benar-benar butuh window
    // Jika Enable Timer OFF atau mode 'Start when respondent opens' (per-responden, bukan window global) â†’ jangan kirim window
    // Ini yang sebelumnya bikin publish langsung 403 'Form belum dibuka' karena start_date = now future + naive WIB mismatch
    DateTime? startDate;
    DateTime? endDate;
    final isPerRespondent =
        _timerMode == 'Start when respondent opens the form';
    if (!_enableTimer || isPerRespondent) {
      startDate = null;
      endDate = null;
    } else {
      // Start at specific date and time â†’ window global.
      // Backend mengharapkan format waktu LOKAL (WIB) tanpa zona (seperti datetime-local di web).
      // Kurangi 5 menit (bukan 60s) untuk mencegah error "Form belum dibuka" jika jam HP lebih cepat dari server.
      startDate =
          _startDate ?? DateTime.now().subtract(const Duration(minutes: 5));
      endDate = _endDate ?? startDate.add(_getDurationValueAsDuration());
    }

    // Batas respons: 1 kali / tanpa batas / kustom (>= 2) â€” seperti web.
    int maxSub;
    switch (_submissionLimit) {
      case 'unlimited':
        maxSub = 0;
        break;
      case 'custom':
        final n = int.tryParse(_customSubLimitCtrl.text.trim()) ?? 1;
        maxSub = n >= 2 ? n : 1;
        break;
      case 'once':
      default:
        maxSub = 1;
    }

    return {
      'allow_see_result': _correctAnswers,
      'max_submissions': maxSub,
      'require_fullscreen': _requireFullscreen,
      'reveal_answers': _revealAnswers,
      'accept_responses': _acceptResponses,
      'status': _formStatus,
      'shuffle_questions': _shuffleQuestions,
      'shuffle_options': _shuffleOptions,
      'use_join_token': _useJoinToken,
      // Kirim waktu lokal tanpa Z, sesuai ekspektasi backend (seperti datetime-local)
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  // Simpan sebagian (status-only): dipakai saat PATCH atomik gagal karena
  // soal terkunci (409) atau tidak valid (422). Mengirim ulang field
  // non-soal TANPA questions ke endpoint PATCH yang sama, lalu me-refresh
  // editor dari data kanonis server agar tidak tampilkan soal basi.
  // Return: {'success', 'data', 'questionsLocked'|'questionsNotSaved'}.
  Future<Map<String, dynamic>> _saveStatusOnly({
    required String formId,
    required String titleHtml,
    required String descriptionHtml,
    required Map<String, dynamic> settings,
    required String originalError,
  }) async {
    final msgLower = originalError.toLowerCase();
    final isLocked = msgLower.contains('sudah punya jawaban');
    final statusOnlyPayload = <String, dynamic>{
      'title': titleHtml,
      'description': descriptionHtml,
      'banner_url': _builderState.bannerUrl,
      ...settings,
    };
    final patched = await ApiService.updateForm(formId, statusOnlyPayload);
    if (patched['success'] != true) return patched;
    Map<String, dynamic>? canonical;
    if (patched['data'] is Map) {
      canonical = Map<String, dynamic>.from(patched['data'] as Map);
    }
    try {
      final saved = await ApiService.getForm(formId);
      if (saved['success'] == true && saved['data'] is Map) {
        canonical = Map<String, dynamic>.from(saved['data'] as Map);
      }
    } catch (_) {}
    return {
      'success': true,
      'data': canonical ?? {'id': formId},
      if (isLocked) 'questionsLocked': true,
      if (!isLocked) ...{
        'questionsNotSaved': true,
        'questionsError': originalError,
      },
    };
  }

  // Sinkronkan editor ke data kanonis server (dipanggil setelah partial save
  // agar soal yang ditolak backend tidak tetap tampil sebagai sudah tersimpan).
  void _syncEditorFromServerData(Map<String, dynamic> data) {
    try {
      _applyFormSettings(data);
      final fresh = FormBuilderState.fromForm(data);
      final old = _builderState;
      setState(() => _builderState = fresh);
      old.dispose();
    } catch (e) {
      debugPrint('[FormMaker] sync editor gagal: $e');
    }
  }

  // Simpan draft/publish form ke /forms. Kalau sudah punya _draftFormId,
  // pakai PATCH (update field + replace questions) supaya tidak duplikat.
  Future<Map<String, dynamic>?> _saveForm({required bool publish}) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return null;
    setState(() => _builderState.isSaving = true);
    try {
      _syncTitleFromPage();

      final titleHtml = _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul';
      final descriptionHtml = _builderState.formDescription.trim();
      final questionsPayload = _builderState.buildApiPayload();
      final settings = _buildPublishSettings();
      // Tombol Publish selalu menghasilkan status published (seperti web).
      if (publish) settings['status'] = 'published';

      Map<String, dynamic> res;
      if (_draftFormId != null) {
        res = await ApiService.updateForm(_draftFormId!, {
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          ...settings,
          'questions': questionsPayload,
        });
      } else {
        res = await ApiService.createForm({
          'title': titleHtml,
          'description': descriptionHtml,
          'banner_url': _builderState.bannerUrl,
          'slug': ApiService.generateSlug(QuillHtml.htmlToPlainText(titleHtml)),
          'questions': questionsPayload,
          ...settings,
          if (_useJoinToken) 'use_join_token': true,
        });
        if (res['success'] == true) {
          final data = res['data'];
          if (data is Map && data['id'] != null) {
            // FormCreate tidak punya status/accept_responses â†’ persist via PATCH
            // supaya status closed/published & 'Terima respons' benar-benar tersimpan.
            if ((!publish && _formStatus != 'draft') || !_acceptResponses) {
              await ApiService.updateForm(data['id'].toString(), {
                'status': _formStatus,
                'accept_responses': _acceptResponses,
              });
            }
          }
        }
      }

      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftFormId = data['id'].toString();
          if (publish && _useJoinToken) {
            final tokenRes = await ApiService.regenerateJoinToken(
              _draftFormId!,
            );
            if (tokenRes['success'] != true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Token form gagal dibuat: ${tokenRes['message'] ?? 'terjadi kesalahan'}',
                  ),
                  backgroundColor: Colors.orange.shade700,
                ),
              );
            }
          }

          // Read back the saved form so the editor reflects the canonical
          // server state, matching the web editor after an atomic PATCH.
          final saved = await ApiService.getForm(_draftFormId!);
          if (saved['success'] == true && saved['data'] is Map) {
            res = saved;
          }
        }
      } else if (_draftFormId != null && res['success'] != true) {
        // Inti perbaikan (parity web + lebih kuat): PATCH atomik di atas selalu
        // menggabungkan status/settings dengan questions. Dua kasus gagal total:
        //  (a) 409 — form sudah punya jawaban → backend menolak ganti soal
        //        (tapi SUDAH commit status/settings sebelum raise);
        //  (b) 422 — satu soal tidak valid → Pydantic menolak SELURUH request
        //        termasuk perubahan status.
        // Agar Published→Closed (dan judul/pengaturan) SELALU tersimpan walau
        // soal terkunci/invalid, kirim ulang PATCH TANPA questions (endpoint
        // yang sama — tidak ada endpoint baru). Soal yang gagal disimpan
        // dilaporkan jujur via flag, bukan dianggap sukses.
        final msgLower =
            res['message']?.toString().toLowerCase() ?? '';
        final isLocked = msgLower.contains('sudah punya jawaban');
        final isValidation = msgLower.contains('422') ||
            msgLower.contains('format data tidak valid') ||
            msgLower.contains('failed to update form');
        if (isLocked || isValidation) {
          final retry = await _saveStatusOnly(
            formId: _draftFormId!,
            titleHtml: titleHtml,
            descriptionHtml: descriptionHtml,
            settings: settings,
            originalError: res['message']?.toString() ??
                'Format soal tidak valid — status & pengaturan tetap tersimpan.',
          );
          if (retry['success'] == true) return retry;
          debugPrint(
              '[FormMaker] status-only retry gagal: ${retry['message']}');
        }
        // Parity web (FormBuilderPage.jsx): jika publish dan soal terkunci,
        // coba publish tanpa ubah soal agar link tetap bisa dibagikan.
        if (publish) {
          bool publishOk = false;
          Map<String, dynamic>? patchedData;
          try {
            final patched = await ApiService.updateForm(_draftFormId!, {
              'status': 'published',
            });
            if (patched['success'] == true) {
              publishOk = true;
              if (patched['data'] is Map) {
                patchedData = Map<String, dynamic>.from(patched['data'] as Map);
              }
            }
          } catch (_) {}
          if (!publishOk) {
            try {
              final pub = await ApiService.publishForm(_draftFormId!);
              if (pub['success'] == true) {
                publishOk = true;
                if (pub['data'] is Map) {
                  patchedData = Map<String, dynamic>.from(pub['data'] as Map);
                }
              }
            } catch (_) {}
          }
          if (publishOk) {
            return {
              'success': true,
              'data': patchedData ?? {'id': _draftFormId},
              'questionsLocked': true,
            };
          }
        }
      }
      return res;
    } finally {
      if (mounted) setState(() => _builderState.isSaving = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_builderState.isSaving) return;
    final res = await _saveForm(publish: false);
    if (!mounted || res == null) return;
    _handleSaveResult(res, isUpdate: false);
  }

  /// Simpan perubahan pada form yang sudah ada (mode edit) — parity web:
  /// tombol "Simpan"/"Perbarui" memanggil save biasa (publish:false) sehingga
  /// status pilihan user (termasuk Closed) dihormati, bukan dipaksa published.
  /// Setelah sukses penuh pada form published, QR di-refresh diam-diam
  /// (parity FormBuilderPage.jsx:364-368) tanpa dialog share yang mengganggu.
  Future<void> _saveChanges() async {
    if (_builderState.isSaving) return;
    final res = await _saveForm(publish: false);
    if (!mounted || res == null) return;
    _handleSaveResult(res, isUpdate: true);
    if (res['success'] == true &&
        res['questionsLocked'] != true &&
        res['questionsNotSaved'] != true &&
        _draftFormId != null &&
        _formStatus == 'published') {
      try {
        await ApiService.generateQrCode(_draftFormId!);
      } catch (_) {}
    }
  }

  /// Menampilkan hasil simpan secara jujur + sinkron editor ke server.
  /// [isUpdate] = true untuk mode edit (wording "diperbarui", parity tombol
  /// "Perbarui" pada web), false untuk form baru/draft.
  void _handleSaveResult(Map<String, dynamic> res, {required bool isUpdate}) {
    if (!mounted) return;
    if (res['success'] == true) {
      // Sinkronkan editor ke state kanonis server (penting setelah partial
      // save: soal yang ditolak backend tidak boleh tetap tampil seolah tersimpan).
      final data = res['data'];
      if (data is Map &&
          (res['questionsLocked'] == true ||
              res['questionsNotSaved'] == true)) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      if (res['questionsLocked'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengaturan tersimpan (termasuk status). Soal tidak diubah karena form sudah ada jawaban responden — duplikasi form dulu jika perlu.',
            ),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 5),
          ),
        );
      } else if (res['questionsNotSaved'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status & pengaturan tersimpan. Tetapi soal gagal disimpan: ${res['questionsError'] ?? 'periksa kembali isian soal'}.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'Form berhasil diperbarui! Link siap dibagikan.'
                  : 'Draft berhasil disimpan — bisa dilanjutkan dari Dashboard / web',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      var msg = res['message']?.toString() ?? 'Unknown error';
      if (msg.toLowerCase().contains('sudah punya jawaban')) {
        // Parity web: judul/deskripsi/pengaturan tetap tersimpan (backend
        // commit sebelum 409), hanya ganti soal yang ditolak.
        msg =
            'Form sudah ada jawaban responden — judul & pengaturan tetap tersimpan, tapi soal tidak bisa diubah. Duplikasi form dulu jika perlu.';
      }
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isUpdate ? 'Gagal memperbarui form' : 'Gagal menyimpan draft'}: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan (isUpdate=$isUpdate): $msg');
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    _syncTitleFromPage();

    final titleHtml = _builderState.formTitle.trim().isNotEmpty
        ? _builderState.formTitle
        : 'Form Tanpa Judul';
    final descriptionHtml = _builderState.formDescription.trim();
    final questionsPayload = _builderState.buildApiPayload();

    setState(() => _builderState.isSaving = true);

    final payload = {
      'title': titleHtml,
      'description': descriptionHtml,
      'banner_url': _builderState.bannerUrl,
      'questions': questionsPayload,
    };

    final String? targetId = _draftTemplateId ?? widget.initialTemplate?.id;
    final res = targetId != null
        ? await ApiService.updateTemplate(targetId, payload)
        : await ApiService.createTemplate(payload);
    if (!mounted) return;
    setState(() => _builderState.isSaving = false);

    if (res['success'] == true) {
      if (_draftTemplateId == null && widget.initialTemplate?.id == null) {
        final data = res['data'];
        if (data is Map && data['id'] != null) {
          _draftTemplateId = data['id'].toString();
        }
      }
      Navigator.pop(
        context,
        FormMakerResult(
          template: FormTemplate(
            title: QuillHtml.htmlToPlainText(titleHtml),
            subtitle: 'Baru saja disimpan',
            id: _draftTemplateId ?? widget.initialTemplate?.id,
            questionsJson: questionsPayload,
          ),
        ),
      );
    } else {
      final msg = res['message']?.toString() ?? 'Unknown error';
      final hint = _networkHint(msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan template: $msg$hint'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      debugPrint('[FormMaker] Gagal simpan template: $msg');
    }
  }

  void _publishForm() async {
    if (_builderState.isSaving) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (_builderState.formTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul formulir tidak boleh kosong')),
      );
      return;
    }

    // Cegah status Closed tertimpa diam-diam: tombol Publish selalu
    // menghasilkan status published (parity web). Minta konfirmasi dulu.
    if (_formStatus == 'closed') {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Status form Closed'),
          content: const Text(
            'Status di Setelan saat ini Closed. Tombol Publish akan mengubah '
            'status kembali menjadi Published agar link bisa dibagikan.\n\n'
            'Untuk menutup form, gunakan Simpan (status Closed tetap dipertahankan).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'save_closed'),
              child: const Text('Simpan sebagai Closed'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'publish'),
              child: const Text('Tetap Publish'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null || choice == 'cancel') return;
      if (choice == 'save_closed') {
        await _saveDraft();
        return;
      }
      // 'publish' → lanjut ke alur publish normal di bawah.
    }

    final res = await _saveForm(publish: true);
    if (!mounted) return;
    if (res == null) return;
    if (res['success'] != true) {
      var msg = res['message']?.toString() ?? 'terjadi kesalahan';
      if (msg.toLowerCase().contains('sudah punya jawaban')) {
        msg =
            'Form sudah ada jawaban responden â€” hapus soal akan menghapus jawaban. Duplikasi form dulu jika perlu.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal publish form: $msg${_networkHint(msg)}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // Parity web: publish via fallback status-only (soal terkunci karena
    // sudah ada jawaban) — beri tahu user sebelum dialog share muncul.
    // Sinkronkan juga editor ke data server agar tidak tampilkan soal basi.
    if (res['questionsLocked'] == true && mounted) {
      final data = res['data'];
      if (data is Map) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Form berhasil dipublikasikan! (Soal tidak diubah karena sudah ada jawaban)',
          ),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 4),
        ),
      );
    }
    if (res['questionsNotSaved'] == true && mounted) {
      final data = res['data'];
      if (data is Map) {
        _syncEditorFromServerData(Map<String, dynamic>.from(data));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status & pengaturan tersimpan. Tetapi soal gagal disimpan: ${res['questionsError'] ?? 'periksa kembali isian soal'}.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }

    // FIX: jangan asal force-unwrap â€” kalau _draftFormId belum ke-set (mis. data
    // response tak punya id), ambil dari res supaya tidak null-crash.
    var formId = _draftFormId;
    if (formId == null) {
      final data = res['data'];
      if (data is Map && data['id'] != null) {
        _draftFormId = data['id'].toString();
        formId = _draftFormId;
      }
    }
    if (formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal publish form: tidak ada id form'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() => _builderState.isSaving = true);

    final titlePlain = QuillHtml.htmlToPlainText(
      _builderState.formTitle.trim().isNotEmpty
          ? _builderState.formTitle
          : 'Form Tanpa Judul',
    );

    // FIX Bug 17-18: createForm selalu draft, maka publish via endpoint khusus.
    // Pastikan benar-benar published (jangan lanjut generate QR kalau gagal).
    final pubRes = await ApiService.publishForm(formId);
    if (pubRes['success'] != true) {
      setState(() => _builderState.isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal publish form: ${pubRes['message'] ?? 'terjadi kesalahan'}',
            ),
          ),
        );
      }
      return;
    }

    final qrRes = await ApiService.generateQrCode(formId);

    if (qrRes['success'] == true) {
      var shareLink = qrRes['data']['share_link'] as String;
      // Paksa link publik selalu menunjuk ke frontend yang dideploy (Vercel),
      // bukan localhost yang mungkin di-set di env backend.
      shareLink = ApiService.publicFormLink(shareLink);
      String qrUrl = qrRes['data']['qr_code_url'] as String;
      if (qrUrl.contains('localhost')) {
        final apiHost = Uri.parse(ApiService.baseUrl).host;
        qrUrl = qrUrl.replaceAll('localhost', apiHost);
      }
      if (mounted) _showShareDialog(shareLink, qrUrl, formId, titlePlain);
    } else {
      if (mounted) {
        setState(() => _builderState.isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate QR: ${qrRes['message']}')),
        );
      }
    }
  }

  void _showShareDialog(
    String link,
    String qrUrl,
    String formId,
    String title,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShareFormDialog(link: link, qrUrl: qrUrl),
    ).then((_) {
      if (mounted) {
        Navigator.pop(
          context,
          FormMakerResult(draftFormId: formId, draftFormTitle: title),
        );
      }
    });
  }

  void _pickImage() async {
    final picker = ImagePicker();
    // Kompres gambar saat diambil agar ukuran file kecil. Foto kamera full-res
    // (bisa 4-12 MB) gagal diupload lewat tunnel ngrok HTTPS dengan error
    // "HTTPS request failed, statusCode: 0" (koneksi putus saat tubuh request besar).
    // Pola ini sama dengan profil (avatar) & isi form (file upload) yang sudah bekerja.
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final activePageId =
          _builderState.activePageId ?? _builderState.pages.first.id;

      // Upload the image to the backend first
      final uploadResult = await ApiService.uploadFile(pickedFile);
      if (uploadResult['success'] == true) {
        final fileUrl = uploadResult['file_url'] as String;

        // Perilaku seperti Google Form: jika ada pertanyaan yang sedang dipilih,
        // gambar ditempel ke pertanyaan itu (bukan membuat pertanyaan baru).
        final attached = _builderState.attachImageToActiveQuestion(fileUrl);
        if (!attached) {
          _builderState.addQuestion(
            activePageId,
            QuestionType.image,
            imageUrl: fileUrl,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
            ),
          );
        }
      }
    }
  }

  /// Pilih & tempelkan gambar ke pertanyaan tertentu (perilaku Google Form,
  /// tombol gambar di toolbar pertanyaan aktif). Tidak membuat pertanyaan baru.
  /// Gambar kedua dst. menumpuk di bawah gambar pertama â€” teks pertanyaan
  /// (label) tidak pernah diubah.
  Future<void> _pickImageForQuestion(QuestionData q) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      q.addAttachedImage(fileUrl);
      _builderState.triggerUpdate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah gambar: ${uploadResult['message']}'),
        ),
      );
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    // Kompres banner sama seperti _pickImage agar upload via ngrok tidak putus
    // dengan error "HTTPS request failed, statusCode: 0".
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final uploadResult = await ApiService.uploadFile(pickedFile);
    if (!mounted) return;
    if (uploadResult['success'] == true) {
      final fileUrl = uploadResult['file_url'] as String;
      setState(() => _builderState.bannerUrl = fileUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah banner: ${uploadResult['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _applyRequiredToAll() {
    _builderState.setAllQuestionsRequired(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua pertanyaan dijadikan wajib diisi'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  void _applyOptionalToAll() {
    _builderState.setAllQuestionsRequired(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua pertanyaan dijadikan opsional')),
      );
    }
  }

  void _showAddQuestionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          // Parity web (QUESTION_TYPES): hanya 6 jenis soal + Section lewat
          // tombol "Tambah Bagian". Lihat QuestionTypeExtension.pickerTypes.
          children: QuestionTypeExtension.pickerTypes.map((type) {
                return ListTile(
                  leading: Icon(_getIconForType(type), color: _primaryColor),
                  title: Text(
                    type.label,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    final activePageId =
                        _builderState.activePageId ??
                        _builderState.pages.first.id;
                    _builderState.addQuestion(activePageId, type);
                    Navigator.pop(context);
                  },
                );
              })
              .toList(),
        );
      },
    );
  }

  IconData _getIconForType(QuestionType type) {
    switch (type) {
      case QuestionType.shortAnswer:
        return Icons.short_text;
      case QuestionType.paragraph:
        return Icons.notes;
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked;
      case QuestionType.checkboxes:
        return Icons.check_box;
      case QuestionType.dropdown:
        return Icons.arrow_drop_down_circle;
      case QuestionType.fileUpload:
        return Icons.cloud_upload;
      case QuestionType.linearScale:
        return Icons.linear_scale;
      case QuestionType.rating:
        return Icons.star;
      case QuestionType.date:
        return Icons.event;
      case QuestionType.time:
        return Icons.access_time;
      case QuestionType.image:
        return Icons.image_outlined;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _builderState,
      builder: (context, _) {
        // Editor Form Maker dirancang light-only (latar `_bgColor` terang +
        // teks hitam yang dikunci). Bungkus dengan tema terang agar semua teks
        // yang tidak diberi warna eksplisit tetap gelap & terbaca walau berada
        // di mode gelap aplikasi (mencegah teks terang di atas latar terang).
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(scaffoldBackgroundColor: _currentBgColor),
          child: Scaffold(
            backgroundColor: _currentBgColor,
            appBar: _buildAppBar(),
            body: _isPreviewMode
                ? PreviewCanvas(state: _builderState)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      EditorCanvas(
                        state: _builderState,
                        onAddImage: _pickImageForQuestion,
                      ),
                      FormSettingsTab(
                        builderState: _builderState,
                        onPickBanner: _pickBanner,
                        formStatus: _formStatus,
                        onFormStatusChanged: (v) =>
                            setState(() => _formStatus = v),
                        acceptResponses: _acceptResponses,
                        onAcceptResponsesChanged: (v) =>
                            setState(() => _acceptResponses = v),
                        submissionLimit: _submissionLimit,
                        onSubmissionLimitChanged: (v) =>
                            setState(() => _submissionLimit = v),
                        customSubLimitCtrl: _customSubLimitCtrl,
                        requireFullscreen: _requireFullscreen,
                        onRequireFullscreenChanged: (v) =>
                            setState(() => _requireFullscreen = v),
                        useJoinToken: _useJoinToken,
                        onUseJoinTokenChanged: (v) =>
                            setState(() => _useJoinToken = v),
                        shuffleQuestions: _shuffleQuestions,
                        onShuffleQuestionsChanged: (v) =>
                            setState(() => _shuffleQuestions = v),
                        shuffleOptions: _shuffleOptions,
                        onShuffleOptionsChanged: (v) =>
                            setState(() => _shuffleOptions = v),
                        isQuiz: _isQuiz,
                        onIsQuizChanged: (v) => setState(() => _isQuiz = v),
                        releaseGrade: _releaseGrade,
                        onReleaseGradeChanged: (v) =>
                            setState(() => _releaseGrade = v),
                        missedQuestions: _missedQuestions,
                        onMissedQuestionsChanged: (v) =>
                            setState(() => _missedQuestions = v),
                        correctAnswers: _correctAnswers,
                        onCorrectAnswersChanged: (v) =>
                            setState(() => _correctAnswers = v),
                        revealAnswers: _revealAnswers,
                        onRevealAnswersChanged: (v) =>
                            setState(() => _revealAnswers = v),
                        pointValues: _pointValues,
                        onPointValuesChanged: (v) =>
                            setState(() => _pointValues = v),
                        pointValueCtrl: _pointValueCtrl,
                        sendCopy: _sendCopy,
                        onSendCopyChanged: (v) => setState(() => _sendCopy = v),
                        hideResponses: _hideResponses,
                        onHideResponsesChanged: (v) =>
                            setState(() => _hideResponses = v),
                        allowMultipleEdits: _allowMultipleEdits,
                        onAllowMultipleEditsChanged: (v) =>
                            setState(() => _allowMultipleEdits = v),
                        requireQuestionDefault: _requireQuestionDefault,
                        onRequireQuestionDefaultChanged: (v) =>
                            setState(() => _requireQuestionDefault = v),
                        onApplyRequiredToAll: _applyRequiredToAll,
                        onApplyOptionalToAll: _applyOptionalToAll,
                        enableTimer: _enableTimer,
                        onEnableTimerChanged: (v) =>
                            setState(() => _enableTimer = v),
                        timerMode: _timerMode,
                        onTimerModeChanged: (v) =>
                            setState(() => _timerMode = v),
                        startDate: _startDate,
                        endDate: _endDate,
                        durationCtrl: _durationCtrl,
                        durationUnit: _durationUnit,
                        onDurationUnitChanged: (v) =>
                            setState(() => _durationUnit = v),
                        onPickTimerDate: _pickTimerDate,
                        formatTimerDate: _formatTimerDate,
                        onSaveSettings: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Pengaturan dicatat — tekan Simpan untuk menerapkan (status: $_formStatus, batas respons: $_submissionLimit, timer: ${_enableTimer ? _durationDisplayText : 'nonaktif'}). Catatan: tombol Publish selalu menerbitkan (status published); untuk Closed gunakan Simpan.',
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
            floatingActionButton: (!_isPreviewMode && _tabController.index == 0)
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _isDark ? 0.3 : 0.1,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.image_outlined,
                                color: _textColor,
                              ),
                              onPressed: _pickImage,
                              tooltip: 'Tambah Gambar',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.view_agenda_outlined,
                                color: _textColor,
                              ),
                              onPressed: () {
                                _builderState.addPage();
                              },
                              tooltip: 'Tambah Bagian',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'add_question_btn',
                        onPressed: _showAddQuestionSheet,
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        child: const Icon(Icons.add, size: 28),
                      ),
                    ],
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    // Parity web (FormBuilderPage.jsx:1104-1140): saat mengedit form yang
    // sudah ada, tombol utama adalah Simpan/Perbarui (save changes, hormati
    // status), bukan Publish. Publish hanya untuk form baru.
    final bool isEdit = _draftFormId != null;
    final String primaryLabel =
        !isEdit ? 'Publish' : (_formStatus == 'published' ? 'Perbarui' : 'Simpan');
    return AppBar(
      backgroundColor: _currentBgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: Container(
          decoration: BoxDecoration(color: _cardColor, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _textColor, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: null,
      bottom: _isPreviewMode
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(kTextTabBarHeight),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: _primaryColor,
                  unselectedLabelColor: _subTextColor,
                  indicatorColor: _primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  onTap: (index) {
                    setState(() {}); // refresh floating button
                  },
                  tabs: const [
                    Tab(text: 'Soal'),
                    Tab(text: 'Setelan'),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined,
            color: _appBarIconColor,
          ),
          onPressed: () {
            setState(() {
              _isPreviewMode = !_isPreviewMode;
              // Clear active selection when switching modes
              _builderState.setActiveQuestion(null, null);
            });
          },
          tooltip: _isPreviewMode ? 'Editor Mode' : 'Preview Mode',
        ),
        if (!_isPreviewMode && !isEdit)
          IconButton(
            icon: Icon(Icons.save_outlined, color: _appBarIconColor),
            onPressed: _builderState.isSaving ? null : _saveDraft,
            tooltip: 'Simpan Draft',
          ),
        if (!_isPreviewMode)
          IconButton(
            icon: Icon(Icons.account_balance, color: _appBarIconColor),
            tooltip: 'Simpan sebagai Template',
            onPressed: _builderState.isSaving ? null : _saveAsTemplate,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
          child: FilledButton.icon(
            onPressed: _builderState.isSaving
                ? null
                : (isEdit ? _saveChanges : _publishForm),
            icon: _builderState.isSaving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(isEdit ? Icons.check : Icons.send, size: 16),
            label: Text(
              primaryLabel,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}
