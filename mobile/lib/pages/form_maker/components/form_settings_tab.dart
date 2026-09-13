import 'package:flutter/material.dart';
import '../models/form_builder_state.dart';
import '../../../../widgets/ngrok_image.dart';

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

  // NOTE (Tahap 7a): _buildBannerCard pindah ke
  // components/settings_basic_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7a): _buildFormAccessCard pindah ke
  // components/settings_basic_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7b): _buildQuizSettingsCard pindah ke
  // components/settings_quiz_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7b): _buildResponseSettingsCard pindah ke
  // components/settings_quiz_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7b): _buildDefaultSettingsCard pindah ke
  // components/settings_quiz_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7c): _buildTimerSettingsCard pindah ke
  // components/settings_timer_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 7c): _buildRadioOption & _settingsSwitchRow pindah ke
  // components/settings_timer_part.dart (verbatim, tanpa perubahan apa pun).
  // Keduanya dipakai semua kartu lintas-part satu library.
}
