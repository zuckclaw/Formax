// Halaman Tentang Form4x (parity web TentangPage.jsx).
// Visi, fitur utama, nilai, dan tim pengembang.

import 'package:flutter/material.dart';

class TentangPage extends StatelessWidget {
  const TentangPage({super.key});

  static const _features = [
    ('✨', 'Formax AI Builder',
        'Generate form, kuis, dan ujian cerdas otomatis dalam hitungan detik menggunakan AI & formula LaTeX.'),
    ('📝', 'Pembuatan Form Fleksibel',
        'Teks, pilihan ganda, checkbox, dropdown, tanggal, dan upload file dengan editor kaya serta kunci jawaban.'),
    ('📄', 'Import Soal Word',
        'Upload file .docx, preview otomatis, dan impor puluhan soal sekaligus tanpa input manual.'),
    ('⏱️', 'Penilaian & Timer Otomatis',
        'Kunci jawaban presisi, skor real-time, dan timer auto-submit dengan rekap jawaban.'),
    ('🔒', 'Keamanan Mode Fullscreen',
        'Mode fullscreen wajib, pengacak soal dan opsi, serta proteksi deteksi pindah tab.'),
    ('🔲', 'QR & Export Spreadsheet',
        'Generate Kode QR & link unik per form, serta ekspor hasil ke Excel/Spreadsheet.'),
  ];

  static const _values = [
    ('Cerdas (AI-Powered)',
        'AI untuk membuat kuis, survei, dan soal ujian otomatis dengan cepat.'),
    ('Sederhana',
        'Antarmuka bersih dan langkah jelas, fokus pada isi bukan pengaturan rumit.'),
    ('Andal & Terstruktur',
        'Penyimpanan terstruktur dengan autentikasi aman dan ekspor data akurat.'),
    ('Aman & Terverifikasi',
        'Pengisian terintegrasi akun terverifikasi demi validitas data.'),
  ];

  static const _team = [
    ('FJ', 'Fathin Jamaluddin', 'Project Manager'),
    ('GN', 'Gita Nur Amalia', 'Database Engineer'),
    ('AK', 'Andhika Khairul Fahmi', 'UI/UX Designer — Web Dev'),
    ('FS', 'Fajriah Salsabilla', 'UI/UX Designer — Web Dev'),
    ('FG', 'Farrel Ghifari', 'Android Dev'),
    ('RJ', 'Raka Julio Same', 'Android Dev'),
  ];

  static const _steps = [
    ('Susun', 'Tambah pertanyaan, atur tipe, dan tetapkan kunci jawaban'),
    ('Atur', 'Kelola status, jadwal, dan kontrol pengisian di Setelan'),
    ('Bagikan', 'Sebarkan tautan atau QR ke responden'),
    ('Analisis', 'Pantau skor dan distribusi jawaban real-time'),
  ];

  static const _checklist = [
    'Integrasi Formax AI Builder untuk pembuatan form instan',
    'Cocok untuk pendidikan, pelatihan, survei internal, dan pendataan',
    'Tidak memerlukan instalasi di sisi responden',
    'Data tersimpan terstruktur dan siap diekspor ke Excel',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0.5,
        title: const Text(
          'Tentang Form4x',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E66D0), Color(0xFF0B76D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TENTANG FORM4X',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Platform Formulir yang Rapi, Cepat, dan Terukur',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Form4x membantu pendidik, organisasi, dan tim menyusun formulir, kuis, serta survei terstruktur — dari pembuatan hingga analisis hasil.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Apa itu
            _sectionTitle(context, 'Apa itu Form4x'),
            const SizedBox(height: 8),
            Text(
              'Form4x berfokus pada kejelasan alur dan keandalan data. Susun form dengan AI Builder, impor soal dari Word (.docx), atau mulai dari awal, lalu bagikan via tautan atau Kode QR.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Mendukung penilaian otomatis, token akses, batas pengisian, timer auto-submit, dan mode fullscreen. Hasil terekspor ke spreadsheet dan divisualisasikan per pertanyaan.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final c in _checklist)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Alur
            _sectionTitle(context, 'Alur Form4x'),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.12),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                  title: Text(
                    _steps[i].$1,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(_steps[i].$2,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 20),
            // Fitur
            _sectionTitle(context, 'Fitur Utama'),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemCount: _features.length,
              itemBuilder: (context, i) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_features[i].$1,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        _features[i].$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          _features[i].$3,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              height: 1.4),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Nilai
            _sectionTitle(context, 'Nilai Kami'),
            const SizedBox(height: 8),
            for (final v in _values)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(v.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle:
                      Text(v.$2, style: const TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 20),
            // Tim
            _sectionTitle(context, 'Tim Pengembang'),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: _team.length,
              itemBuilder: (context, i) => Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1E40AF),
                      child: Text(
                        _team[i].$1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _team[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      _team[i].$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '© 2026 Form4x. All rights reserved.',
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
