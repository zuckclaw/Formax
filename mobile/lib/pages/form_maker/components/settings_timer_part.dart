// Kartu Form Timer + shared row FormSettingsTab.
// Dipindah verbatim dari `components/form_settings_tab.dart` (Tahap 7c)
// tanpa perubahan apa pun (pre-scan: StatelessWidget — tidak ada setState
// maupun static member di blok ini). File ini adalah `part` dari library
// yang sama; call-site di build() tidak berubah.
// _buildRadioOption & _settingsSwitchRow dipakai semua kartu lintas-part
// satu library (kartu 7a/7b sudah memanggilnya sejak Tahap 7a).
part of 'form_settings_tab.dart';

extension _SettingsTimer on FormSettingsTab {
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
