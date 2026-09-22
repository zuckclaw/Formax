// Kartu Kuis, Jawaban & Default FormSettingsTab.
// Dipindah verbatim dari `components/form_settings_tab.dart` (Tahap 7b)
// tanpa perubahan apa pun (pre-scan: StatelessWidget — tidak ada setState
// maupun static member di blok ini). File ini adalah `part` dari library
// yang sama; call-site di build() tidak berubah.
// _settingsSwitchRow & _buildRadioOption dipakai lintas-part satu library
// (didefinisikan di settings_timer_part.dart, Tahap 7c).
part of 'form_settings_tab.dart';

extension _SettingsQuiz on FormSettingsTab {
  /// Kartu Kuis & Nilai — HANYA setelan yang terkirim ke backend
  /// (allow_see_result, reveal_answers). Toggle dekoratif tanpa efek
  /// backend sengaja tidak ditampilkan agar tidak menyimpang dari web.
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
                        'Kuis & Nilai',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kontrol hasil dan kunci jawaban (tersimpan ke server)',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              subtitle:
                  'Setelah submit, responden bisa melihat skor dan rincian',
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
              subtitle:
                  'Responden melihat jawaban yang benar di halaman hasil',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onClearAnswerKeys,
                icon: const Icon(Icons.clear_all_outlined, size: 18),
                label: const Text('Hapus semua kunci jawaban'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Menghapus kunci di editor — tekan Simpan/Publish agar tersimpan.',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu Tema Tampilan (parity web). Satu-satunya sumber preset ada di
  /// utils/form_theme.dart (sama dengan web utils/formTheme.js).
  Widget _buildThemeCard(
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
            Text(
              'Tema Tampilan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Warna aksen halaman pengisi & pratinjau (tersimpan ke server)',
              style: TextStyle(fontSize: 13, color: subTextColor),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in kFormThemePresets)
                  _ThemeSwatch(
                    accent: p.accent,
                    name: p.name,
                    selected: (themeAccent ?? kFormDefaultAccent) ==
                        p.accent,
                    onTap: () => onThemeAccentChanged(
                      p.accent == kFormDefaultAccent ? null : p.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _accentColorOf(themeAccent),
                    shape: BoxShape.circle,
                    border: Border.all(color: subTextColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    themeAccent == null
                        ? 'Aktif: Biru Default ($kFormDefaultAccent)'
                        : 'Aktif: ${themeAccent!.toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ),
                if (themeAccent != null)
                  TextButton(
                    onPressed: () => onThemeAccentChanged(null),
                    child: const Text('Reset default'),
                  ),
              ],
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
            Divider(height: 1, color: isDark ? const Color(0xFF2D2D4A) : null),
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

class _ThemeSwatch extends StatelessWidget {
  final String accent;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.accent,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(
        'FF${accent.replaceFirst('#', '')}',
        radix: 16));
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : Colors.grey.withValues(alpha: 0.4),
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

Color _accentColorOf(String? accent) {
  final norm = normalizeFormAccent(accent) ?? kFormDefaultAccent;
  return Color(
      int.parse('FF${norm.replaceFirst('#', '')}', radix: 16));
}
