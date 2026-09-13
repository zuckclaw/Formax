// Kartu Banner & Form-Akses FormSettingsTab.
// Dipindah verbatim dari `components/form_settings_tab.dart` (Tahap 7a)
// tanpa perubahan apa pun (pre-scan: StatelessWidget — tidak ada setState
// maupun static member di blok ini). File ini adalah `part` dari library
// yang sama; call-site di build() tidak berubah.
// _settingsSwitchRow & _buildRadioOption dipakai lintas-part satu library
// (didefinisikan di settings_timer_part.dart, Tahap 7c).
part of 'form_settings_tab.dart';

extension _SettingsBasic on FormSettingsTab {
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
}
