import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';
import '../../../../widgets/ngrok_image.dart';
import '../../../../utils/form_theme.dart';

// Part: kartu Banner & Form-Akses — Tahap 7a.
// Sama-sama satu library, call-site di build() tidak berubah.
part 'settings_basic_part.dart';

// Part: kartu Kuis, Jawaban & Default — Tahap 7b.
// Sama-sama satu library, call-site di build() tidak berubah.
part 'settings_quiz_part.dart';

// Part: kartu Form Timer + shared radio/switch row — Tahap 7c.
// Sama-sama satu library, call-site di build() tidak berubah.
part 'settings_timer_part.dart';

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

  // Quiz Settings (parity backend/web — HANYA field yang terkirim ke API)
  final bool correctAnswers;
  final ValueChanged<bool> onCorrectAnswersChanged;
  final bool revealAnswers;
  final ValueChanged<bool> onRevealAnswersChanged;

  /// Hapus semua kunci jawaban (aksi lokal, perlu Simpan/Publish).
  final VoidCallback onClearAnswerKeys;

  // Tema tampilan fill page (parity web; null = default).
  final String? themeAccent;
  final ValueChanged<String?> onThemeAccentChanged;

  // Default Settings
  final bool requireQuestionDefault;
  final ValueChanged<bool> onRequireQuestionDefaultChanged;
  final VoidCallback onApplyRequiredToAll;
  final VoidCallback onApplyOptionalToAll;

  // Timer Settings
  final DateTime? startDate;
  final DateTime? endDate;
  final Future<void> Function({required bool start}) onPickTimerDate;
  final void Function({required bool start})? onClearTimerDate;
  final ValueChanged<Duration>? onSetQuickDuration;
  final String Function(DateTime?) formatTimerDate;
  final VoidCallback onSaveSettings;

  /// true saat penyimpanan pengaturan sedang berjalan (tombol bawah).
  final bool isSavingSettings;

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
    required this.correctAnswers,
    required this.onCorrectAnswersChanged,
    required this.revealAnswers,
    required this.onRevealAnswersChanged,
    required this.onClearAnswerKeys,
    required this.themeAccent,
    required this.onThemeAccentChanged,
    required this.requireQuestionDefault,
    required this.onRequireQuestionDefaultChanged,
    required this.onApplyRequiredToAll,
    required this.onApplyOptionalToAll,
    required this.startDate,
    required this.endDate,
    required this.onPickTimerDate,
    this.onClearTimerDate,
    this.onSetQuickDuration,
    required this.formatTimerDate,
    required this.onSaveSettings,
    this.isSavingSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF2563EB);
    final cardColor = isDark ? const Color(0xFF23233F) : Colors.white;
    final textColor = isDark ? const Color(0xFFEEF2FF) : Colors.black87;
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
          _buildThemeCard(
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
          const SizedBox(height: 20),
          // Tombol Simpan Pengaturan — PALING BAWAH, di luar semua
          // container kartu, agar jelas mencakup seluruh pengaturan.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSavingSettings ? null : onSaveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isSavingSettings
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan Pengaturan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // NOTE (Tahap 7a): _buildBannerCard pindah ke
  // components/settings_basic_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7a): _buildFormAccessCard pindah ke
  // components/settings_basic_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7b): _buildQuizSettingsCard & _buildThemeCard pindah ke
  // components/settings_quiz_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7b): _buildDefaultSettingsCard pindah ke
  // components/settings_quiz_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7c): _buildTimerSettingsCard pindah ke
  // components/settings_timer_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7c): _buildRadioOption & _settingsSwitchRow pindah ke
  // components/settings_timer_part.dart (verbatim, tanpa perubahan apa pun).
  // Keduanya dipakai semua kartu lintas-part satu library.
}
