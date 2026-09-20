// Halaman Cara Pakai Form4x (parity web CaraPakaiPage.jsx).
// Panduan 3 langkah + daftar fitur, tanpa animasi scroll web.

import 'package:flutter/material.dart';

class CaraPakaiPage extends StatelessWidget {
  const CaraPakaiPage({super.key});

  static const _steps = [
    (
      'LANGKAH 1',
      '👤+ Daftar Akun',
      'Cukup daftar dengan email, tanpa perlu mengunduh apa pun.',
      [
        ('1', 'Buka Halaman Daftar',
            'Ketuk "Register" di halaman login aplikasi Form4x.', false),
        ('2', 'Isi Data Diri',
            'Masukkan nama, email, dan kata sandi Anda.', false),
        ('3', 'Verifikasi Email',
            'Masukkan 6 digit kode OTP yang dikirim ke email Anda.', false),
        ('✓', 'Selesai!',
            'Akun siap dipakai — langsung masuk ke dashboard.', true),
      ],
    ),
    (
      'LANGKAH 2',
      '📄 Buat Form',
      'Susun form baru dari template siap pakai atau dari kosong.',
      [
        ('1', 'Ketuk "Buat Formulir"',
            'Dari dashboard, buat form baru dalam sekali ketuk.', false),
        ('2', 'Pilih Template / Kosong',
            'Gunakan template siap pakai, atau susun dari nol.', false),
        ('3', 'Gunakan AI / Import Word / Timer',
            'Manfaatkan AI Builder, impor Word (.docx), atau timer auto-submit.',
            false),
        ('✓', 'Publikasikan',
            'Ketuk "Publish" agar form siap dibagikan.', true),
      ],
    ),
    (
      'LANGKAH 3',
      '🔗 Bagikan & Pantau',
      'Sebarkan form dan pantau jawaban real-time.',
      [
        ('1', 'Salin Tautan / QR',
            'Setiap form otomatis punya tautan dan kode QR.', false),
        ('2', 'Sebarkan ke Responden',
            'Bagikan lewat WhatsApp, email, atau media sosial.', false),
        ('3', 'Pantau Respon Masuk',
            'Lihat jawaban masuk real-time dari dashboard.', false),
        ('✓', 'Selesai!',
            'Ekspor hasil ke spreadsheet kapan saja.', true),
      ],
    ),
  ];

  static const _features = [
    ('✨', 'AI Form Builder',
        'Buat form, kuis, dan ujian cerdas otomatis dalam hitungan detik.'),
    ('⚡', 'Buat Form Cepat',
        'Editor serbaguna dengan berbagai jenis pertanyaan.'),
    ('⏱️', 'Timer Otomatis',
        'Batas waktu pengisian dengan auto-submit saat waktu habis.'),
    ('🔲', 'Kode QR & Link',
        'Setiap form otomatis mendapat kode QR & tautan unik.'),
    ('📊', 'Export Spreadsheet',
        'Jawaban terekspor rapi ke Excel, siap diolah.'),
    ('🔒', 'Akses Aman & Ujian',
        'Mode fullscreen wajib, pengacak opsi, dan data terjaga.'),
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
          'Cara Pakai',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E66D0), Color(0xFF3730A3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cara Menggunakan Form4x',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Panduan singkat membuat, membagikan, dan memantau form — langsung dari aplikasi.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (var s = 0; s < _steps.length; s++) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      '${s + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[s].$1,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        Text(
                          _steps[s].$2,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _steps[s].$3,
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final c in _steps[s].$4)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.$4
                          ? const Color(0xFF059669).withValues(alpha: 0.12)
                          : const Color(0xFF2563EB).withValues(alpha: 0.12),
                      child: Text(
                        c.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.$4
                              ? const Color(0xFF059669)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    title: Text(
                      c.$2,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(c.$3,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            Text(
              'Fitur yang Tersedia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
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
                        ),
                      ),
                    ],
                  ),
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
}
