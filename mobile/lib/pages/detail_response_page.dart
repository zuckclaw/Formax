// lib/pages/detail_response_page.dart
// Halaman Detail Jawaban Individu — info responden, skor, status curang,
// dan per soal: jawaban + penilaian ben ar/salah + kunci jawaban (parity web).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class DetailResponsePage extends StatelessWidget {
  final String name;
  final String email;
  final String time;
  final bool isAuto;
  final bool isCheated;
  final String? scoreText;
  final String formTitle;

  /// ID submission (untuk hapus respons). Kosong = tombol hapus disembunyikan.
  final String submissionId;

  /// List jawaban: [{'question','answer','isCorrect','correctAnswer','fileUrl'}]
  final List<Map<String, dynamic>> answers;

  const DetailResponsePage({
    super.key,
    required this.name,
    required this.email,
    required this.time,
    required this.isAuto,
    this.isCheated = false,
    this.scoreText,
    required this.formTitle,
    this.submissionId = '',
    this.answers = const [],
  });

  String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _fileNameFromUrl(String url) {
    final segment = url.split('/').last;
    try {
      var name = Uri.decodeComponent(segment);
      if (name.length > 28) name = '${name.substring(0, 25)}...';
      return name.isEmpty ? url : name;
    } catch (_) {
      return segment.isEmpty ? url : segment;
    }
  }

  Future<void> _openFile(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link file tidak valid'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _capitalizeWords(name);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detail Respons',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          // Hapus respons individu (parity web "Hapus Respons").
          if (submissionId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              tooltip: 'Hapus respons',
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context, displayName),
            const SizedBox(height: 24),
            Text(
              'JAWABAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (answers.isEmpty)
              _buildEmptyAnswers(context)
            else
              ...answers.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAnswerCard(
                    context,
                    entry.key + 1,
                    entry.value['question'] as String? ?? '',
                    entry.value['answer'] as String? ?? '',
                    entry.value['isCorrect'] as bool?,
                    entry.value['correctAnswer'] as String?,
                    entry.value['fileUrl'] as String?,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Konfirmasi + eksekusi hapus respons (parity web confirmDeleteSubmission).
  /// Berhasil → pop(true) agar daftar me-reload; responden bisa mengerjakan ulang.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text('Hapus Respons?'),
          ],
        ),
        content: Text(
          'Jawaban $name akan dihapus permanen dan tidak bisa dikembalikan. Responden dapat mengerjakan ulang form ini.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final res = await ApiService.deleteSubmission(submissionId);
    if (!context.mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respons berhasil dihapus')),
      );
      Navigator.pop(context, true);
    } else {
      final m = Map<String, dynamic>.from(res);
      if (ApiService.isAuthInvalidResult(m) ||
          ApiService.isConnectionFailureResult(m)) {
        await ApiService.forceLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res['message']?.toString() ?? 'Gagal menghapus respons'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoCard(BuildContext context, String displayName) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1E40AF),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
              ),
              const SizedBox(width: 14),
              Builder(builder: (context) => _buildMethodChip(context)),
            ],
          ),
          if (scoreText != null) ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x2E16A34A)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Text(
                      scoreText!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Nilai',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFF047857)),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (isCheated) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x2EEF4444)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
                          : const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Responden ini terdeteksi curang karena keluar dari mode full screen saat mengisi form.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF991B1B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodChip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDark ? const Color(0xFF3B82F6) : const Color(0xFFC7D2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.smart_toy_outlined : Icons.person_outline,
            size: 13,
            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 4),
          Text(
            isAuto ? 'Otomatis' : 'Manual',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
    BuildContext context,
    int number,
    String question,
    String answer,
    bool? isCorrect,
    String? correctAnswer,
    String? fileUrl,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: colorScheme.brightness == Brightness.dark
                        ? const Color(0xFF1E3A5F)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.brightness == Brightness.dark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isCorrect != null)
                  _buildCorrectBadge(context, isCorrect),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Kotak jawaban: teks onSurface → bg harus adaptif tema.
              color: colorScheme.brightness == Brightness.dark
                  ? const Color(0xFF2A2A4A)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (answer.isNotEmpty &&
                    !(fileUrl != null &&
                        fileUrl.isNotEmpty &&
                        answer == fileUrl))
                  Text(
                    answer,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                if (correctAnswer != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kunci Jawaban: $correctAnswer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF047857),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (fileUrl != null && fileUrl.isNotEmpty) ...[
                  if (answer.isNotEmpty && answer != fileUrl)
                    const SizedBox(height: 8)
                  else
                    const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _openFile(context, fileUrl),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.brightness == Brightness.dark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: colorScheme.brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _fileNameFromUrl(fileUrl),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: colorScheme.brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF1D4ED8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectBadge(BuildContext context, bool isCorrect) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCorrect
            ? (isDark ? const Color(0x2E16A34A) : const Color(0xFFD1FAE5))
            : (isDark ? const Color(0x2EEF4444) : const Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect
              ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF86EFAC))
              : (isDark
                  ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
                  : const Color(0xFFFCA5A5)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: isCorrect
                ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF059669))
                : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
          ),
          const SizedBox(width: 3),
          Text(
            isCorrect ? 'Benar' : 'Salah',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCorrect
                  ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF059669))
                  : (isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnswers(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.question_answer_outlined,
            size: 40,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada jawaban tersimpan',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
