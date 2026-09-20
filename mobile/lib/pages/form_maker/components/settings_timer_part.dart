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
    final hasTimer = endDate != null;
    final hasStart = startDate != null;

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
                  child: Icon(Icons.timer_outlined, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jadwal & Timer Formulir',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atur batas waktu pengerjaan dan jadwal buka/tutup form',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? const Color(0xFF2D2D4A) : null),
            const SizedBox(height: 12),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasTimer
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                    : (isDark ? const Color(0xFF23233F) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasTimer
                      ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                      : (isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasTimer ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                    color: hasTimer
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                        : subTextColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasTimer
                          ? 'Timer Aktif — Selesai & auto-submit: ${formatTimerDate(endDate)}'
                          : (hasStart
                              ? 'Jadwal Mulai: Form dibuka pada ${formatTimerDate(startDate)}'
                              : 'Timer Nonaktif — Form dapat diisi tanpa batas waktu'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasTimer
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                            : textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Waktu Mulai (Opsional)
            Text(
              'Waktu Mulai (Buka Form)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Opsional. Jika diatur, responden baru bisa membuka form setelah waktu ini.',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onPickTimerDate(start: true),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasStart ? formatTimerDate(startDate) : 'Pilih waktu mulai...',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasStart ? textColor : subTextColor,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3A3A5C) : Colors.black12,
                      ),
                    ),
                  ),
                ),
                if (hasStart) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Hapus waktu mulai',
                    onPressed: () => onClearTimerDate?.call(start: true),
                    color: Colors.red.shade400,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Waktu Selesai (Batas Waktu / Timer)
            Text(
              'Waktu Selesai (Batas Waktu & Timer)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acuan batas waktu ujian & pemicu countdown timer responden (auto-submit).',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onPickTimerDate(start: false),
                    icon: Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: hasTimer ? primaryColor : null,
                    ),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasTimer ? formatTimerDate(endDate) : 'Pilih batas waktu selesai...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasTimer ? FontWeight.w600 : FontWeight.normal,
                          color: hasTimer ? textColor : subTextColor,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: BorderSide(
                        color: hasTimer
                            ? primaryColor
                            : (isDark ? const Color(0xFF3A3A5C) : Colors.black12),
                      ),
                    ),
                  ),
                ),
                if (hasTimer) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Hapus batas waktu (nonaktifkan timer)',
                    onPressed: () => onClearTimerDate?.call(start: false),
                    color: Colors.red.shade400,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Tombol Cepat Batas Waktu
            Text(
              'Atur Cepat Batas Waktu (dari sekarang):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('+15 mnt'),
                  avatar: const Icon(Icons.add, size: 14),
                  onPressed: () => onSetQuickDuration?.call(const Duration(minutes: 15)),
                ),
                ActionChip(
                  label: const Text('+30 mnt'),
                  avatar: const Icon(Icons.add, size: 14),
                  onPressed: () => onSetQuickDuration?.call(const Duration(minutes: 30)),
                ),
                ActionChip(
                  label: const Text('+1 jam'),
                  avatar: const Icon(Icons.add, size: 14),
                  onPressed: () => onSetQuickDuration?.call(const Duration(hours: 1)),
                ),
                ActionChip(
                  label: const Text('+2 jam'),
                  avatar: const Icon(Icons.add, size: 14),
                  onPressed: () => onSetQuickDuration?.call(const Duration(hours: 2)),
                ),
                ActionChip(
                  label: const Text('+1 hari'),
                  avatar: const Icon(Icons.add, size: 14),
                  onPressed: () => onSetQuickDuration?.call(const Duration(days: 1)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info Card
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
                      'Sistem timer di Form4x terintegrasi dengan waktu Selesai (sama seperti web). '
                      'Saat waktu Selesai diatur, responden akan melihat countdown timer di atas layar '
                      'dan form akan otomatis dikumpulkan saat waktu habis.',
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
            const SizedBox(height: 24),
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
                'Simpan Pengaturan',
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
              ? const Color(0xFF3A3A5C)
              : Colors.grey.shade400,
        ),
      ],
    );
  }
}
