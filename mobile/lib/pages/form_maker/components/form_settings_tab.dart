import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';
import '../../../../widgets/ngrok_image.dart';

class FormSettingsTab extends StatelessWidget {
  final FormBuilderState builderState;
  final VoidCallback onPickBanner;

  // Form & Access
  final String formStatus;
  final ValueChanged<String> onFormStatusChanged;
  final bool acceptResponses;
  final ValueChanged<bool> onAcceptResponsesChanged;
  final String submissionLimit;
  final ValueChanged<String> onSubmissionLimitChanged;
  final TextEditingController customSubLimitCtrl;
  final bool requireFullscreen;
  final ValueChanged<bool> onRequireFullscreenChanged;
  final bool useJoinToken;
  final ValueChanged<bool> onUseJoinTokenChanged;
  final bool shuffleQuestions;
  final ValueChanged<bool> onShuffleQuestionsChanged;
  final bool shuffleOptions;
  final ValueChanged<bool> onShuffleOptionsChanged;

  // Quiz Settings
  final bool isQuiz;
  final ValueChanged<bool> onIsQuizChanged;
  final String releaseGrade;
  final ValueChanged<String> onReleaseGradeChanged;
  final bool missedQuestions;
  final ValueChanged<bool> onMissedQuestionsChanged;
  final bool correctAnswers;
  final ValueChanged<bool> onCorrectAnswersChanged;
  final bool revealAnswers;
  final ValueChanged<bool> onRevealAnswersChanged;
  final bool pointValues;
  final ValueChanged<bool> onPointValuesChanged;
  final TextEditingController pointValueCtrl;

  // Response Settings
  final String sendCopy;
  final ValueChanged<String> onSendCopyChanged;
  final bool hideResponses;
  final ValueChanged<bool> onHideResponsesChanged;
  final bool allowMultipleEdits;
  final ValueChanged<bool> onAllowMultipleEditsChanged;

  // Default Settings
  final bool requireQuestionDefault;
  final ValueChanged<bool> onRequireQuestionDefaultChanged;
  final VoidCallback onApplyRequiredToAll;
  final VoidCallback onApplyOptionalToAll;

  // Timer Settings
  final bool enableTimer;
  final ValueChanged<bool> onEnableTimerChanged;
  final String timerMode;
  final ValueChanged<String> onTimerModeChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController durationCtrl;
  final String durationUnit;
  final ValueChanged<String> onDurationUnitChanged;
  final Future<void> Function({required bool start}) onPickTimerDate;
  final String Function(DateTime?) formatTimerDate;
  final VoidCallback onSaveSettings;

  const FormSettingsTab({
    super.key,
    required this.builderState,
    required this.onPickBanner,
    required this.formStatus,
    required this.onFormStatusChanged,
    required this.acceptResponses,
    required this.onAcceptResponsesChanged,
    required this.submissionLimit,
    required this.onSubmissionLimitChanged,
    required this.customSubLimitCtrl,
    required this.requireFullscreen,
    required this.onRequireFullscreenChanged,
    required this.useJoinToken,
    required this.onUseJoinTokenChanged,
    required this.shuffleQuestions,
    required this.onShuffleQuestionsChanged,
    required this.shuffleOptions,
    required this.onShuffleOptionsChanged,
    required this.isQuiz,
    required this.onIsQuizChanged,
    required this.releaseGrade,
    required this.onReleaseGradeChanged,
    required this.missedQuestions,
    required this.onMissedQuestionsChanged,
    required this.correctAnswers,
    required this.onCorrectAnswersChanged,
    required this.revealAnswers,
    required this.onRevealAnswersChanged,
    required this.pointValues,
    required this.onPointValuesChanged,
    required this.pointValueCtrl,
    required this.sendCopy,
    required this.onSendCopyChanged,
    required this.hideResponses,
    required this.onHideResponsesChanged,
    required this.allowMultipleEdits,
    required this.onAllowMultipleEditsChanged,
    required this.requireQuestionDefault,
    required this.onRequireQuestionDefaultChanged,
    required this.onApplyRequiredToAll,
    required this.onApplyOptionalToAll,
    required this.enableTimer,
    required this.onEnableTimerChanged,
    required this.timerMode,
    required this.onTimerModeChanged,
    required this.startDate,
    required this.endDate,
    required this.durationCtrl,
    required this.durationUnit,
    required this.onDurationUnitChanged,
    required this.onPickTimerDate,
    required this.formatTimerDate,
    required this.onSaveSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBannerCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 12),
          _buildFormAccessCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 12),
          _buildQuizSettingsCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 12),
          _buildResponseSettingsCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 12),
          _buildDefaultSettingsCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 12),
          _buildTimerSettingsCard(
            context,
            isDark,
            primaryColor,
            cardColor,
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBannerCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    final banner = builderState.bannerUrl;
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined, color: Color(0xFF1E66D0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Banner Form',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gambar header di atas judul form',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (banner != null && banner.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: NgrokImage(
                    banner,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: const Color(0xFFE5E7EB),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickBanner,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(
                      banner != null && banner.isNotEmpty
                          ? 'Ganti Banner'
                          : 'Unggah Banner',
                    ),
                  ),
                ),
                if (banner != null && banner.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => builderState.bannerUrl = null,
                    tooltip: 'Hapus Banner',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormAccessCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form & Akses',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status, penerimaan respons, dan pembatasan',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'STATUS FORM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.black12,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: formStatus,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'draft',
                      child: Text(
                        'Draft',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'published',
                      child: Text(
                        'Dipublikasikan',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'closed',
                      child: Text(
                        'Ditutup',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                  ],
                  dropdownColor: isDark ? const Color(0xFF1E293B) : null,
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  onChanged: (v) {
                    if (v != null) onFormStatusChanged(v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _settingsSwitchRow(
              'Terima respons',
              acceptResponses,
              onAcceptResponsesChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
              subtitle:
                  'Matikan untuk berhenti menerima jawaban tanpa menutup form',
            ),
            const SizedBox(height: 20),
            Text(
              'BATAS RESPONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildRadioOption(
              '1 kali per orang',
              'once',
              submissionLimit,
              onSubmissionLimitChanged,
              textColor: textColor,
              primaryColor: primaryColor,
            ),
            _buildRadioOption(
              'Tanpa batas',
              'unlimited',
              submissionLimit,
              onSubmissionLimitChanged,
              textColor: textColor,
              primaryColor: primaryColor,
            ),
            _buildRadioOption(
              'Kustom (jumlah tertentu)',
              'custom',
              submissionLimit,
              onSubmissionLimitChanged,
              textColor: textColor,
              primaryColor: primaryColor,
            ),
            if (submissionLimit == 'custom') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: customSubLimitCtrl,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Batas (>= 2)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF475569)
                            : Colors.black12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Paksa layar penuh (anti-cheat)',
              requireFullscreen,
              onRequireFullscreenChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
              subtitle:
                  'Form ditandai "curang" jika responden keluar dari form',
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Perlukan token (ujian bareng)',
              useJoinToken,
              onUseJoinTokenChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
              subtitle: 'Token dibuat otomatis saat form pertama kali disimpan',
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Acak soal per bagian',
              shuffleQuestions,
              onShuffleQuestionsChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
              subtitle: 'Urutan soal diacak untuk setiap responden',
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Acak opsi jawaban',
              shuffleOptions,
              onShuffleOptionsChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
              subtitle: 'Urutan opsi diacak untuk setiap responden',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF451A03)
                    : const Color(0xFFFFF7ED),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF9A3412)
                      : const Color(0xFFFDBA74),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFEA580C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setelan tersimpan saat form disimpan (Simpan Draft / Publish). '
                      'Jadwal timer memakai durasi di kartu Form Timer.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFFED7AA)
                            : const Color(0xFF9A3412),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSettingsCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jadikan ini sebagai kuis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menetapkan pertanyaan dan nilai poin, serta menyediakan masukan secara otomatis',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isQuiz,
                  onChanged: onIsQuizChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: primaryColor,
                ),
              ],
            ),
            if (isQuiz) ...[
              const SizedBox(height: 24),
              Text(
                'RILIS NILAI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildRadioOption(
                'Langsung setelah setiap pengiriman',
                'langsung',
                releaseGrade,
                onReleaseGradeChanged,
                textColor: textColor,
                primaryColor: primaryColor,
              ),
              _buildRadioOption(
                'Nanti, setelah peninjauan manual\nAktifkan Respons -> Kumpulkan alamat email',
                'nanti',
                releaseGrade,
                onReleaseGradeChanged,
                textColor: textColor,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'SETELAN RESPONDEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 8),
              _settingsSwitchRow(
                'Responden dapat melihat hasil',
                correctAnswers,
                (v) {
                  onCorrectAnswersChanged(v);
                  if (!v) onRevealAnswersChanged(false);
                },
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _settingsSwitchRow(
                'Pertanyaan tak terjawab',
                missedQuestions,
                onMissedQuestionsChanged,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _settingsSwitchRow(
                'Jawaban yang benar',
                revealAnswers,
                (v) => onRevealAnswersChanged(correctAnswers && v),
                enabled: correctAnswers,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _settingsSwitchRow(
                'Nilai poin',
                pointValues,
                onPointValuesChanged,
                textColor: textColor,
                subTextColor: subTextColor,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              Text(
                'DEFAULT KUIS GLOBAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nilai poin pertanyaan default',
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.black12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      controller: pointValueCtrl,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'poin',
                    style: TextStyle(fontSize: 14, color: subTextColor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseSettingsCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(onSurface: textColor),
        ),
        child: ExpansionTile(
          title: Text(
            'Jawaban',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          subtitle: Text(
            'Mengelola cara respons dikumpulkan dan dilindungi',
            style: TextStyle(fontSize: 13, color: subTextColor),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mengirim salinan jawaban responden',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.black12,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sendCopy,
                    isExpanded: false,
                    items: ['Nonaktif', 'Aktif']
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ),
                        )
                        .toList(),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : null,
                    icon: Icon(Icons.arrow_drop_down, color: textColor),
                    onChanged: (v) {
                      if (v != null) onSendCopyChanged(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow(
              'Sembunyikan jawaban',
              hideResponses,
              onHideResponsesChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _settingsSwitchRow(
              'Isi Form lebih dari 1 kali',
              allowMultipleEdits,
              onAllowMultipleEditsChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSettingsCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(onSurface: textColor),
        ),
        child: ExpansionTile(
          title: Text(
            'Default',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pertanyaan default',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Setelan diterapkan untuk semua pertanyaan',
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
            ),
            const SizedBox(height: 12),
            _settingsSwitchRow(
              'Buat pertanyaan wajib diisi secara default',
              requireQuestionDefault,
              onRequireQuestionDefaultChanged,
              textColor: textColor,
              subTextColor: subTextColor,
              primaryColor: primaryColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Terapkan ke semua pertanyaan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onApplyRequiredToAll,
                    icon: const Icon(Icons.checklist, size: 18),
                    label: const Text('Set Semua Wajib'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E66D0),
                      side: const BorderSide(color: Color(0xFF1E66D0)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onApplyOptionalToAll,
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Set Semua Opsional'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSettingsCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.av_timer, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage constraints and timing for this form',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? const Color(0xFF334155) : null),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Timer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Turn off timer constraints',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enableTimer,
                  onChanged: onEnableTimerChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Timer Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : Colors.black12,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: timerMode,
                  isExpanded: true,
                  items:
                      [
                        'Start when respondent opens the form',
                        'Start at a specific date and time',
                      ].map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                        );
                      }).toList(),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : null,
                  icon: Icon(Icons.arrow_drop_down, color: textColor),
                  onChanged: (v) {
                    if (v != null) onTimerModeChanged(v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF475569)
                              : Colors.black12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? const Color(0xFF475569) : Colors.black12,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(6),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: durationUnit,
                      isExpanded: true,
                      items:
                          const [
                            'detik',
                            'menit',
                            'jam',
                            'hari',
                            'bulan',
                            'tahun',
                          ].map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(
                                unit,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) onDurationUnitChanged(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (enableTimer &&
                timerMode == 'Start at a specific date and time') ...[
              const SizedBox(height: 20),
              Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onPickTimerDate(start: true),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mulai: ${formatTimerDate(startDate)}'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => onPickTimerDate(start: false),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Selesai: ${formatTimerDate(endDate)}'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFFEFF6FF),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFFBFDBFE),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The form will auto-submit and lock once the timer runs out. Respondents will see a countdown display at the top of the page.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1D4ED8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onSaveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(
    String title,
    String value,
    String groupValue,
    ValueChanged<String> onChanged, {
    required Color textColor,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: RadioGroup<String>(
                groupValue: groupValue,
                onChanged: (selected) {
                  if (selected != null) onChanged(selected);
                },
                child: Radio<String>(value: value, activeColor: primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
    bool enabled = true,
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: enabled ? textColor : subTextColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: enabled && value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: Colors.white,
          activeTrackColor: primaryColor,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: isDark
              ? const Color(0xFF475569)
              : Colors.grey.shade400,
        ),
      ],
    );
  }
}
