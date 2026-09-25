import 'package:flutter/material.dart';
import '../models/form_template.dart';
import '../services/api_service.dart';
import '../utils/quill_html.dart';
import '../utils/form_theme.dart';
import '../utils/form_settings_meta.dart';
import '../widgets/share_form_dialog.dart';
import 'form_maker/models/form_builder_state.dart';
import 'form_maker/editor_canvas.dart';
import 'form_maker/preview_canvas.dart';
import 'form_maker/docx_import_sheet.dart';
import 'form_maker/components/form_settings_tab.dart';
import '../models/question_model.dart'; // Ensure QuestionType is imported for toolbar
import 'package:image_picker/image_picker.dart';
import 'form_maker/form_maker_result.dart';
// Re-export: 6+ file konsumen memakai FormMakerResult via import
// 'formmakerpage.dart' — tetap kompilasi tanpa perubahan (Tahap 6a).
export 'form_maker/form_maker_result.dart';

// Part: helper setelan & timer — Tahap 6b.
// Sama-sama satu library, call-site tidak berubah.
part 'form_maker/settings_part.dart';

// Part: pipeline simpan (draft/publish/status-only) — Tahap 6c1.
// Sama-sama satu library, call-site tidak berubah.
part 'form_maker/save_part.dart';

// Part: share, gambar & sheet tambah soal — Tahap 6d.
// Sama-sama satu library, call-site tidak berubah.
part 'form_maker/media_part.dart';

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

  /// true saat tombol "Simpan Pengaturan" (tab Setelan) sedang menyimpan.
  bool _isSavingSettings = false;

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _bgColor = const Color(0xFFE8EEF7);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _currentBgColor => _isDark ? const Color(0xFF1A1A2E) : _bgColor;
  Color get _cardColor => _isDark ? const Color(0xFF23233F) : Colors.white;
  Color get _textColor => _isDark ? const Color(0xFFEEF2FF) : Colors.black87;
  Color get _subTextColor => _isDark ? const Color(0xFF94A3B8) : Colors.black54;
  Color get _appBarIconColor =>
      _isDark ? const Color(0xFFCBD5E1) : Colors.black54;

  // State untuk Setelan (parity backend/web — SEMUA field di bawah ini
  // benar-benar terkirim ke API; tidak ada toggle dekoratif).
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

  bool _requireQuestionDefault = false;

  DateTime? _startDate;
  DateTime? _endDate;

  /// Aksen tema fill page ({"accent": hex} di backend, null = default).
  /// null di sini = belum tentu default; lihat _themeTouched.
  String? _themeAccent;
  /// true bila user mengubah tema di sesi ini (agar reset ke default
  /// ikut terkirim; tanpa ini PATCH tak bisa mengembalikan default).
  bool _themeTouched = false;

  bool _correctAnswers = false;
  bool _revealAnswers = false;

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
      // FIX: Apply template form settings (Bug: settings were staying as defaults)
      _applyFormSettings({
        'accept_responses': widget.initialTemplate!.acceptResponses,
        'allow_see_result': widget.initialTemplate!.allowSeeResult,
        'max_submissions': widget.initialTemplate!.maxSubmissions,
        'require_fullscreen': widget.initialTemplate!.requireFullscreen,
        'reveal_answers': widget.initialTemplate!.revealAnswers,
        'shuffle_questions': widget.initialTemplate!.shuffleQuestions,
        'shuffle_options': widget.initialTemplate!.shuffleOptions,
        'start_date': widget.initialTemplate!.startDate?.toIso8601String(),
        'end_date': widget.initialTemplate!.endDate?.toIso8601String(),
        'use_join_token': widget.initialTemplate!.useJoinToken,
        'theme': widget.initialTemplate!.theme,
      });
    } else {
      _builderState = FormBuilderState();
    }
  }

  // Helper tanggal timer untuk extension settings
  // (form_maker/settings_part.dart): setState HANYA di member State.
  // Isi = pindahan verbatim dari _pickTimerDate.
  void _applyTimerDate(bool start, DateTime? value) {
    setState(() {
      if (start) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  void _applyQuickDuration(Duration duration) {
    setState(() {
      final now = DateTime.now();
      _startDate ??= now;
      _endDate = now.add(duration);
    });
  }

  // Helper flag saving untuk extension save (form_maker/save_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim tiap situsnya.
  void _markSaving() {
    setState(() => _builderState.isSaving = true);
  }
  void _markSavingDone() {
    setState(() => _builderState.isSaving = false);
  }

  void _markSavingDoneIfMounted() {
    if (mounted) setState(() => _builderState.isSaving = false);
  }

  void _replaceBuilderState(FormBuilderState fresh) {
    setState(() => _builderState = fresh);
  }

  // Helper flag tombol "Simpan Pengaturan" untuk extension save:
  // setState HANYA di member State.
  void _markSavingSettings(bool value) {
    setState(() => _isSavingSettings = value);
  }

  /// Hapus semua kunci jawaban (parity web). Perubahan di editor,
  /// perlu Simpan/Publish agar tersimpan ke server.
  void _clearAllAnswerKeys() {
    final n = _builderState.clearAllAnswerKeys();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Tidak ada soal dengan kunci jawaban'
              : '$n kunci jawaban dihapus — tekan Simpan/Publish untuk menerapkan',
        ),
      ),
    );
  }

  /// Sinkronkan state pengaturan dari data kanonis server ( dipakai
  /// extension save setelah simpan sukses ). setState di member State.
  void _syncSettingsFromServer(Map<String, dynamic> data) {
    setState(() => _applyFormSettings(data));
  }

  // Helper banner untuk extension media (form_maker/media_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim dari _pickBanner.
  void _applyBannerUrl(String fileUrl) {
    setState(() => _builderState.bannerUrl = fileUrl);
  }

  // NOTE (Tahap 6b): _applyFormSettings, _parseDate, _pickTimerDate pindah
  // ke form_maker/settings_part.dart; setState tanggal didelegasikan ke
  // _applyTimerDate di atas (urutan + isi statement identik).
  // Tanpa perubahan logika/call-site.

  // NOTE (Tahap 6b): _formatTimerDate, _getDurationValue,
  // _getDurationValueAsDuration, _durationDisplayText pindah ke
  // form_maker/settings_part.dart (verbatim, tanpa perubahan apa pun).

  @override
  void dispose() {
    _builderState.dispose();
    _tabController.dispose();
    _customSubLimitCtrl.dispose();
    super.dispose();
  }

  // NOTE (Tahap 6b): _networkHint & _syncTitleFromPage pindah ke
  // form_maker/settings_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 6c1): _buildPublishSettings pindah ke
  // form_maker/save_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 6c1): _saveStatusOnly & _syncEditorFromServerData pindah ke
  // form_maker/save_part.dart; setState sync didelegasikan ke
  // _replaceBuilderState di atas (urutan + isi statement identik).

  // NOTE (Tahap 6c1): _saveForm seutuhnya (_buildPublishSettings dipakai di
  // dalamnya ikut pindah) ada di form_maker/save_part.dart; finally memakai
  // _markSavingDoneIfMounted (isi identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 6c2): _saveDraft & _saveChanges pindah ke
  // form_maker/save_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 6c2): _handleSaveResult pindah ke
  // form_maker/save_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 6c2): _saveAsTemplate pindah ke form_maker/save_part.dart;
  // 2 situs setState didelegasikan ke _markSaving/_markSavingDone
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 6c2): _publishForm pindah ke form_maker/save_part.dart;
  // 3 situs setState didelegasikan ke
  // _markSaving/_markSavingDone/_markSavingDoneIfMounted
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.

  // NOTE (Tahap 6d): _showShareDialog, _pickImage, _pickImageForQuestion
  // pindah ke form_maker/media_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 6d): _pickBanner, _applyRequiredToAll, _applyOptionalToAll,
  // _showAddQuestionSheet, _getIconForType pindah ke
  // form_maker/media_part.dart; setState banner didelegasikan ke
  // _applyBannerUrl (isi identik). Tanpa perubahan logika/call-site.
  // (_getIconForType hanya dipakai sheet — dicek tidak ada pemakai lain.)

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
                        themeAccent: _themeAccent,
                        onThemeAccentChanged: (v) => setState(() {
                          _themeAccent = v;
                          _themeTouched = true;
                        }),
                        correctAnswers: _correctAnswers,
                        onCorrectAnswersChanged: (v) =>
                            setState(() => _correctAnswers = v),
                        revealAnswers: _revealAnswers,
                        onRevealAnswersChanged: (v) =>
                            setState(() => _revealAnswers = v),
                        onClearAnswerKeys: _clearAllAnswerKeys,
                        requireQuestionDefault: _requireQuestionDefault,
                        onRequireQuestionDefaultChanged: (v) =>
                            setState(() => _requireQuestionDefault = v),
                        onApplyRequiredToAll: _applyRequiredToAll,
                        onApplyOptionalToAll: _applyOptionalToAll,
                        startDate: _startDate,
                        endDate: _endDate,
                        onPickTimerDate: _pickTimerDate,
                        onClearTimerDate: _clearTimerDate,
                        onSetQuickDuration: _applyQuickDuration,
                        formatTimerDate: _formatTimerDate,
                        onSaveSettings: _saveSettingsOnly,
                        isSavingSettings: _isSavingSettings,
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

  /// Buka lembar impor DOCX (parity web). Butuh draft tersimpan karena
  /// endpoint preview/confirm backend bekerja per form_id milik sendiri.
  Future<void> _openDocxImport() async {
    final formId = _draftFormId;
    if (formId == null || formId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Simpan sebagai draft dulu, lalu impor soal dari Word.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: DocxImportSheet(
            formId: formId,
            onImported: _reloadAfterDocxImport,
          ),
        ),
      ),
    );
  }

  /// Reload editor dari server setelah impor DOCX sukses.
  Future<void> _reloadAfterDocxImport() async {
    final formId = _draftFormId;
    if (formId == null || formId.isEmpty) return;
    final res = await ApiService.getForm(formId);
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      _syncEditorFromServerData(Map<String, dynamic>.from(res['data'] as Map));
    }
  }

  AppBar _buildAppBar() {    // Parity web (FormBuilderPage.jsx:1104-1140): saat mengedit form yang
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
            // Sama dengan ikon tab Draft di bottom navbar.
            icon: Icon(Icons.drafts_outlined, color: _appBarIconColor),
            onPressed: _builderState.isSaving ? null : _saveDraft,
            tooltip: 'Simpan Draft',
          ),
        if (!_isPreviewMode)
          IconButton(
            // Sama dengan ikon tab Template di bottom navbar.
            icon: Icon(Icons.description_outlined, color: _appBarIconColor),
            tooltip: 'Simpan sebagai Template',
            onPressed: _builderState.isSaving ? null : _saveAsTemplate,
          ),
        // Impor soal dari Word (parity web).
        if (!_isPreviewMode)
          IconButton(
            icon: Icon(Icons.upload_file_outlined, color: _appBarIconColor),
            tooltip: 'Impor soal dari Word (.docx)',
            onPressed: _openDocxImport,
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
