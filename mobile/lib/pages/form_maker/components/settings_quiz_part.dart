// Kartu Kuis, Jawaban & Default FormSettingsTab.
// Dipindah verbatim dari `components/form_settings_tab.dart` (Tahap 7b)
// tanpa perubahan apa pun (pre-scan: StatelessWidget — tidak ada setState
// maupun static member di blok ini). File ini adalah `part` dari library
// yang sama; call-site di build() tidak berubah.
// _settingsSwitchRow & _buildRadioOption dipakai lintas-part satu library
// (didefinisikan di settings_timer_part.dart, Tahap 7c).
part of 'form_settings_tab.dart';

extension _SettingsQuiz on FormSettingsTab {
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
}
