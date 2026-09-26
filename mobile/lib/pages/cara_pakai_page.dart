// lib/pages/cara_pakai_page.dart
// Halaman Cara Pakai Form4x — selaras penuh dengan CaraPakaiPage.jsx (web).
// Hero · Timeline 3 langkah + sub-cards · Fitur (icon box) identik web

import 'package:flutter/material.dart';

class CaraPakaiPage extends StatefulWidget {
  const CaraPakaiPage({super.key});

  @override
  State<CaraPakaiPage> createState() => _CaraPakaiPageState();
}

class _CaraPakaiPageState extends State<CaraPakaiPage> {
  // ── data identik dengan CaraPakaiPage.jsx ──────────────────────────────
  // SVG path di web → IconData yang sesuai di Flutter
  static const _stepIcons = [
    Icons.person_add_rounded,     // Langkah 1: Daftar Akun
    Icons.edit_document,          // Langkah 2: Buat Form
    Icons.link_rounded,           // Langkah 3: Bagikan & Pantau
  ];

  static const _stepBadges  = ['LANGKAH 1', 'LANGKAH 2', 'LANGKAH 3'];
  static const _stepTitles  = ['Daftar Akun', 'Buat Form', 'Bagikan & Pantau'];
  static const _stepDescs   = [
    'Cukup daftar dengan email, tanpa perlu mengunduh apa pun untuk mulai menggunakan Form4x di browser.',
    'Susun form baru dari template siap pakai atau mulai dari halaman kosong.',
    'Sebarkan form Anda dan pantau jawaban yang masuk secara real-time.',
  ];

  // sub-cards per langkah: (nomor/✓, judul, deskripsi, isSuccess)
  static const _step1Cards = [
    ('1', 'Buka Halaman Daftar',
        'Klik tombol "Daftar Gratis" di halaman utama Form4x.', false),
    ('2', 'Isi Data Diri',
        'Masukkan nama, email, dan kata sandi Anda.', false),
    ('3', 'Verifikasi Email',
        'Cek kotak masuk Anda dan klik tautan verifikasi yang dikirim.', false),
    ('✓', 'Selesai!',
        'Akun Anda siap dipakai — langsung masuk ke dashboard.', true),
  ];

  static const _step2Cards = [
    ('1', 'Klik "+"',
        'Dari dashboard, klik tombol untuk membuat form baru.', false),
    ('2', 'Pilih Template / Kosong',
        'Gunakan template siap pakai, atau susun pertanyaan dari nol.', false),
    ('3', 'Gunakan AI / Import Word / Timer',
        'Manfaatkan Formax AI Builder, impor Word (.docx), atau aktifkan timer auto-submit.',
        false),
    ('✓', 'Publikasikan',
        'Klik "Terbitkan" agar form siap dibagikan ke responden.', true),
  ];

  static const _step3Cards = [
    ('1', 'Salin Tautan / QR',
        'Setiap form otomatis punya tautan dan kode QR sendiri.', false),
    ('2', 'Sebarkan ke Responden',
        'Bagikan lewat WhatsApp, email, atau media sosial.', false),
    ('3', 'Pantau Respon Masuk',
        'Lihat jawaban yang masuk secara real-time langsung dari dashboard.', false),
    ('✓', 'Selesai!',
        'Ekspor hasil respons ke spreadsheet kapan saja Anda butuhkan.', true),
  ];

  // Fitur cards — identik dengan bagian "Fitur yang Tersedia" web
  static const _featureIcons = [
    Icons.auto_awesome_rounded,
    Icons.bolt_rounded,
    Icons.timer_rounded,
    Icons.qr_code_rounded,
    Icons.bar_chart_rounded,
    Icons.lock_rounded,
  ];

  static const _featureTitles = [
    'AI Form Builder',
    'Buat Form Cepat',
    'Timer Otomatis',
    'Kode QR & Link',
    'Export ke Spreadsheet',
    'Akses Aman & Ujian',
  ];

  static const _featureDescs = [
    'Buat form, kuis, dan ujian cerdas secara otomatis dalam hitungan detik menggunakan AI.',
    'Susun form baru dengan editor serbaguna dan berbagai jenis pilihan pertanyaan.',
    'Atur batas waktu pengisian dengan auto-submit begitu waktu habis.',
    'Setiap form otomatis mendapat kode QR & tautan unik, siap untuk dibagikan.',
    'Semua jawaban rapi terekspor ke file Excel/Spreadsheet, siap diolah kapan saja.',
    'Mode fullscreen wajib, pengacak opsi jawaban, dan perlindungan data yang terjaga.',
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
          'Cara Pakai',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(isDark),
            _buildTimeline(isDark),
            _buildFeaturesSection(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── HERO — identik dengan ".cp-hero" ─────────────────────────────────────
  Widget _buildHero(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E66D0), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3),
              children: [
                TextSpan(text: 'Cara Menggunakan\n'),
                TextSpan(
                  text: 'Form4x',
                  style: TextStyle(color: Color(0xFF93C5FD)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Panduan singkat untuk mulai membuat, membagikan,\ndan memantau form Anda — semua langsung dari browser.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
          ),

        ],
      ),
    );
  }

  // ── TIMELINE — identik dengan ".cp-timeline-section" ─────────────────────
  Widget _buildTimeline(bool isDark) {
    final stepsData = [_step1Cards, _step2Cards, _step3Cards];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + nodes (kiri)
            _buildTimelineRail(isDark, stepsData.length),
            // Content (kanan)
            Expanded(
              child: Column(
                children: [
                  for (var s = 0; s < stepsData.length; s++)
                    _buildStepBlock(isDark, s, stepsData[s]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Garis vertikal + node lingkaran (cp-timeline-line + cp-node-circle)
  Widget _buildTimelineRail(bool isDark, int count) {
    return SizedBox(
      width: 48,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Garis vertikal — cp-timeline-line
          Positioned(
            top: 24,
            bottom: 24,
            left: 23,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Nodes akan di-overlay oleh setiap step block
        ],
      ),
    );
  }

  Widget _buildStepBlock(
      bool isDark, int index, List<(String, String, String, bool)> cards) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Apakah ada optional card di step 3 (cp-card-optional)?
    final hasOptCard = index == 2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node circle — cp-node-circle
        Padding(
          padding: const EdgeInsets.only(top: 32, left: 12),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF1E66D0),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E66D0),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge "LANGKAH N" — cp-step-badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E66D0).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          const Color(0xFF1E66D0).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _stepBadges[index],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E66D0),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Title dengan icon — cp-step-title + cp-step-icon
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E66D0)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _stepIcons[index],
                        size: 17,
                        color: const Color(0xFF1E66D0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _stepTitles[index],
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _stepDescs[index],
                  style: TextStyle(
                      fontSize: 13, height: 1.55, color: subColor),
                ),
                const SizedBox(height: 14),

                // Sub-cards — cp-card-grid + cp-subcard
                for (final card in cards)
                  _buildSubCard(isDark, card, textColor, subColor),

                // Optional card di langkah 3 — cp-card-optional
                if (hasOptCard)
                  _buildOptionalCard(isDark, textColor, subColor),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCard(
    bool isDark,
    (String, String, String, bool) card,
    Color textColor,
    Color subColor,
  ) {
    final isSuccess = card.$4;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSuccess
            ? (isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isSuccess
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFF2563EB).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              card.$1,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSuccess
                    ? const Color(0xFF10B981)
                    : const Color(0xFF2563EB),
              ),
            ),
          ),
        ),
        title: Text(
          card.$2,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: textColor,
          ),
        ),
        subtitle: Text(
          card.$3,
          style: TextStyle(fontSize: 12, color: subColor),
        ),
      ),
    );
  }

  // Optional card — cp-card-optional
  Widget _buildOptionalCard(bool isDark, Color textColor, Color subColor) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF713F12).withValues(alpha: 0.5)
              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'OPT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
        ),
        title: Text(
          'Pengaturan Opsional',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: textColor,
          ),
        ),
        subtitle: Text(
          'Anda dapat menggunakan Formax AI Builder, mengimpor file Word, atau mengaktifkan timer & pengacak soal kapan saja lewat Editor Formax.',
          style: TextStyle(fontSize: 11.5, color: subColor),
        ),
      ),
    );
  }

  // ── FITUR — identik dengan ".cp-features-section" ─────────────────────────
  Widget _buildFeaturesSection(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan sparkle icon — cp-features-icon-spark
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E66D0).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: Color(0xFF1E66D0)),
              ),
              const SizedBox(width: 10),
              Text(
                'Fitur yang Tersedia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Form4x hadir dengan berbagai fitur canggih untuk membuat form Anda lebih rapi, cepat, dan mudah dikelola.',
            style: TextStyle(
                fontSize: 13, height: 1.55, color: subColor),
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
              childAspectRatio: 0.90,
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
                  // cp-feature-icon-box
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E66D0)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _featureIcons[i],
                      size: 20,
                      color: const Color(0xFF1E66D0),
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
}
