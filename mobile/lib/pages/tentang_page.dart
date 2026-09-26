// lib/pages/tentang_page.dart
// Halaman Tentang Form4x — selaras penuh dengan TentangPage.jsx (web).
// Hero + stats · Apa itu + Alur · Fitur (icon box) · Nilai · Tim · CTA

import 'package:flutter/material.dart';

class TentangPage extends StatelessWidget {
  const TentangPage({super.key});

  // ── data identik dengan web ──────────────────────────────────────────────
  static const _featureTitles = [
    'Formax AI Builder',
    'Pembuatan Form Fleksibel',
    'Import Soal Word',
    'Penilaian & Timer Otomatis',
    'Keamanan Mode Fullscreen',
    'QR & Export Spreadsheet',
  ];

  static const _featureDescs = [
    'Generate form, kuis, dan ujian cerdas secara otomatis dalam hitungan detik menggunakan AI & formula LaTeX.',
    'Teks, pilihan ganda, checkbox, dropdown, tanggal, dan upload file dengan editor kaya, validasi, serta pengaturan poin.',
    'Upload file .docx, preview otomatis, dan impor puluhan soal sekaligus tanpa input manual satu per satu.',
    'Kunci jawaban presisi, skor real-time, dan timer auto-submit dengan visualisasi rekap jawaban.',
    'Mode fullscreen wajib, pengacak soal, pengacak opsi jawaban, serta proteksi deteksi pindah tab.',
    'Generate Kode QR & link unik per form, serta ekspor seluruh hasil respons ke file Excel/Spreadsheet.',
  ];

  // icon yang cocok untuk setiap fitur (selaras dengan SVG path di web)
  static const _featureIcons = [
    Icons.auto_awesome_rounded,       // AI Builder — sparkle
    Icons.edit_note_rounded,          // Form Fleksibel — edit
    Icons.upload_file_rounded,        // Import Word — file upload
    Icons.check_circle_outline_rounded, // Timer & Penilaian — check
    Icons.security_rounded,           // Keamanan — lock/shield
    Icons.qr_code_rounded,            // QR & Export — QR
  ];

  static const _values = [
    ('Cerdas (AI-Powered)',
        'Pengemampuan AI untuk membuat kuis, survei, dan soal ujian otomatis dengan cepat.'),
    ('Sederhana',
        'Antarmuka bersih dan langkah yang jelas, fokus pada isi bukan pengaturan rumit.'),
    ('Andal & Terstruktur',
        'Penyimpanan terstruktur dengan autentikasi aman dan ekspor data yang akurat.'),
    ('Aman & Terverifikasi',
        'Pengisian form terintegrasi dengan akun pengguna terverifikasi demi validitas data.'),
  ];

  static const _team = [
    ('FJ', 'Fathin Jamaluddin', 'Project Manager'),
    ('GN', 'Gita Nur Amalia', 'Database Engineer'),
    ('AK', 'Andhika Khairul Fahmi', 'UI/UX Designer — Web Dev'),
    ('FS', 'Fajriah Salsabilla', 'UI/UX Designer — Web Dev'),
    ('FG', 'Farrel Ghifari', 'Android Dev'),
    ('RJ', 'Raka Julio Same', 'Android Dev'),
  ];

  static const _checklist = [
    'Integrasi Formax AI Builder untuk pembuatan form instan',
    'Cocok untuk pendidikan, pelatihan, survei internal, dan pendataan',
    'Tidak memerlukan instalasi di sisi responden',
    'Data tersimpan terstruktur dan siap diekspor ke Excel',
  ];

  static const _steps = [
    ('Susun', 'Tambah pertanyaan, atur tipe, dan tetapkan kunci jawaban'),
    ('Atur', 'Kelola status, jadwal, dan kontrol pengisian di Setelan'),
    ('Bagikan', 'Sebarkan tautan atau QR, responden dapat mengisi tanpa akun'),
    ('Analisis', 'Pantau skor, durasi, dan distribusi jawaban secara real-time'),
  ];
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tentang Form4x',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(),
            _buildAboutSection(isDark),
            _buildFeaturesSection(isDark),
            _buildValuesSection(isDark),
            _buildTeamSection(isDark),
            _buildCta(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── HERO ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E66D0), Color(0xFF0B76D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kicker — identik dengan web "tp-kicker"
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Tentang Form4x',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'Platform Pembuatan Formulir\nyang Rapi, Cepat, dan Terukur',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle
          const Text(
            'Form4x membantu pendidik, organisasi, dan tim menyusun formulir, kuis, serta survei yang terstruktur dengan alur yang konsisten — dari pembuatan hingga analisis hasil.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          // Stats Row — "AI Form · Import · Real-time" (sama dengan web)
          Row(
            children: [
              _heroStat('AI Form', 'Generate Otomatis'),
              _heroDot(),
              _heroStat('Import', '.docx Sekaligus'),
              _heroDot(),
              _heroStat('Real-time', 'Skor & Rekap'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70)),
        ],
      );

  Widget _heroDot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        ),
      );

  // ── APA ITU FORM4X + ALUR ─────────────────────────────────────────────────
  Widget _buildAboutSection(bool isDark) {
    final textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionKicker('Apa itu Form4x'),
          const SizedBox(height: 10),
          Text(
            'Dirancang untuk Kebutuhan Formulir yang Sesungguhnya',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Form4x berfokus pada kejelasan alur dan keandalan data. Anda dapat menyusun form secara otomatis dengan Formax AI Builder, mengimpor soal dari Word (.docx), atau menyusun dari awal, lalu membagikannya melalui tautan atau Kode QR tanpa langkah tambahan bagi responden.',
            style: TextStyle(fontSize: 13, height: 1.6, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Sistem mendukung penilaian otomatis, kontrol akses berbasis token, batas pengisian, timer auto-submit, serta mode fullscreen untuk integritas ujian. Hasil tersaji dalam rekap yang dapat diekspor ke spreadsheet dan divisualisasikan per pertanyaan.',
            style: TextStyle(fontSize: 13, height: 1.6, color: subColor),
          ),
          const SizedBox(height: 14),
          // Checklist — identik dengan web "tp-checklist"
          for (final item in _checklist)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 17, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: textColor)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Alur Card — identik dengan web "tp-about-card"
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E66D0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alur Form4x',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E66D0)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E66D0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _steps[i].$1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _steps[i].$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subColor,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FITUR UTAMA ───────────────────────────────────────────────────────────
  Widget _buildFeaturesSection(bool isDark) {
    final textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionKicker('Fitur Utama'),
          const SizedBox(height: 10),
          Text(
            'Fungsionalitas Lengkap dalam Satu Tempat',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Setiap fitur disusun agar saling melengkapi, tanpa elemen berlebihan.',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: _featureTitles.length,
            itemBuilder: (ctx, i) => Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // icon box — sama dengan web "tp-feature-icon"
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B76D4)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _featureIcons[i],
                      size: 20,
                      color: const Color(0xFF0B76D4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _featureTitles[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      _featureDescs[i],
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: subColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── NILAI ─────────────────────────────────────────────────────────────────
  Widget _buildValuesSection(bool isDark) {
    final textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionKicker('Nilai Kami'),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: _values.length,
            itemBuilder: (ctx, i) => Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _values[i].$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      _values[i].$2,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: subColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TIM PENGEMBANG ────────────────────────────────────────────────────────
  Widget _buildTeamSection(bool isDark) {
    final textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionKicker('Tim Pengembang'),
          const SizedBox(height: 10),
          Text(
            'Dikembangkan oleh Tim Form4x',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Setiap peran berkontribusi pada keseluruhan pengalaman aplikasi.',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: _team.length,
            itemBuilder: (ctx, i) => Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // tp-team-avatar: lingkaran biru dengan inisial
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _team[i].$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _team[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _team[i].$3,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA ───────────────────────────────────────────────────────────────────
  Widget _buildCta() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 36, 20, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E66D0), Color(0xFF0B76D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Siap Membuat Formulir Pertama Anda?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai dari template atau impor Word, bagikan dalam hitungan menit.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Buat Form Sekarang',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E66D0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  Widget _sectionKicker(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E66D0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E66D0).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E66D0),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
