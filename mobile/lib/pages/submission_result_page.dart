// lib/pages/submission_result_page.dart
// Halaman Tinjauan Hasil & Jawaban Submission Responden (Mobile).
// Mendukung tampilan skor, filter jawaban (semua/benar/salah),
// perbandingan kunci jawaban, file preview, serta mode terang & gelap.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/activity_model.dart';
import '../theme/app_colors.dart';
import '../widgets/rich_text_view.dart';

class SubmissionResultPage extends StatefulWidget {
  final ActivityResultModel result;

  const SubmissionResultPage({super.key, required this.result});

  @override
  State<SubmissionResultPage> createState() => _SubmissionResultPageState();
}

class _SubmissionResultPageState extends State<SubmissionResultPage> {
  String _selectedFilter = 'all'; // 'all', 'correct', 'wrong', 'ungraded'

  ActivityResultModel get result => widget.result;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${local.day} ${months[local.month]} ${local.year}, ${pad(local.hour)}:${pad(local.minute)}';
  }

  bool _isImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final u = url.toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif');
  }

  bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final u = url.trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filtered answers calculation
    final allAnswers = result.answers;
    final correctCount = result.answers.where((a) => a.isCorrect == true).length;
    final wrongCount = result.answers.where((a) => a.isCorrect == false).length;
    final ungradedCount =
        result.answers.where((a) => a.isCorrect == null).length;

    final filteredAnswers = allAnswers.where((a) {
      if (_selectedFilter == 'correct') return a.isCorrect == true;
      if (_selectedFilter == 'wrong') return a.isCorrect == false;
      if (_selectedFilter == 'ungraded') return a.isCorrect == null;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBgCard : const Color(0xFF1E66D0),
        foregroundColor: isDark ? AppColors.darkTextPrimary : Colors.white,
        elevation: isDark ? 0 : 0.5,
        title: Text(
          'Hasil & Evaluasi Jawaban',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Title Section ──
          Text(
            result.formTitle.isEmpty ? 'Hasil Formulir' : result.formTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'Selesai pada ${_formatDate(result.submittedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Cheated Alert Banner ──
          if (result.isCheated) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x33EF4444)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peringatan Integritas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submission ini ditandai keluar dari mode layar penuh saat pengerjaan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Hero Score Card ──
          _buildHeroScoreCard(context, isDark),
          const SizedBox(height: 20),

          // ── Filter Chips ──
          _buildFilterChips(
            isDark: isDark,
            allCount: allAnswers.length,
            correctCount: correctCount,
            wrongCount: wrongCount,
            ungradedCount: ungradedCount,
          ),
          const SizedBox(height: 16),

          // ── Answers List Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian Jawaban Soal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${filteredAnswers.length} Soal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Answers List ──
          if (filteredAnswers.isEmpty)
            _buildEmptyFilterState(isDark)
          else
            ...filteredAnswers.map((answer) {
              // Find index in original list
              final originalIdx = allAnswers.indexOf(answer);
              return _buildAnswerCard(context, answer, originalIdx + 1, isDark);
            }),

          const SizedBox(height: 24),
          // ── Bottom Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Halaman Sebelumnya'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66D0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Score Card Builder ──
  Widget _buildHeroScoreCard(BuildContext context, bool isDark) {
    final score = result.scorePercent;

    if (score == null) {
      // Survey / Unscored Form
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorderMedium
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                size: 32,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formulir Terkirim',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Formulir ini tidak memiliki penilaian skor otomatis. Jawaban Anda telah tersimpan dengan aman.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Graded Form Score
    Color scoreColor;
    String badgeText;
    IconData badgeIcon;

    if (score == 100) {
      scoreColor = const Color(0xFF059669);
      badgeText = 'Sempurna! 🌟';
      badgeIcon = Icons.star_rounded;
    } else if (score >= 80) {
      scoreColor = const Color(0xFF10B981);
      badgeText = 'Luar Biasa! 🎉';
      badgeIcon = Icons.sentiment_very_satisfied_rounded;
    } else if (score >= 70) {
      scoreColor = const Color(0xFF2563EB);
      badgeText = 'Bagus (Lulus) 👍';
      badgeIcon = Icons.thumb_up_alt_rounded;
    } else {
      scoreColor = const Color(0xFFDC2626);
      badgeText = 'Perlu Peningkatan 📚';
      badgeIcon = Icons.menu_book_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorderMedium
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Score Ring
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 6),
                  color: scoreColor.withValues(alpha: isDark ? 0.2 : 0.08),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        'NILAI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: isDark ? 0.25 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 14, color: scoreColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Evaluasi Hasil Pengerjaan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Menjawab ${result.correctCount} dari ${result.totalGraded} soal dengan benar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          // Stat chips row
          Row(
            children: [
              _buildStatTile(
                title: 'Benar',
                value: '${result.correctCount}',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                title: 'Salah',
                value: '${result.totalGraded - result.correctCount}',
                color: const Color(0xFFEF4444),
                icon: Icons.cancel_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                title: 'Dinilai',
                value: '${result.totalGraded}',
                color: const Color(0xFF2563EB),
                icon: Icons.fact_check_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                title: 'Total Soal',
                value: '${result.answers.length}',
                color: const Color(0xFF8B5CF6),
                icon: Icons.quiz_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2E55) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.darkTextMuted
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Chips ──
  Widget _buildFilterChips({
    required bool isDark,
    required int allCount,
    required int correctCount,
    required int wrongCount,
    required int ungradedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChipItem('all', 'Semua ($allCount)', isDark),
          const SizedBox(width: 8),
          _buildFilterChipItem('correct', '✓ Benar ($correctCount)', isDark,
              badgeColor: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildFilterChipItem('wrong', '✗ Salah ($wrongCount)', isDark,
              badgeColor: const Color(0xFFEF4444)),
          if (ungradedCount > 0) ...[
            const SizedBox(width: 8),
            _buildFilterChipItem(
                'ungraded', 'Tidak Dinilai ($ungradedCount)', isDark,
                badgeColor: const Color(0xFF64748B)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChipItem(String key, String label, bool isDark,
      {Color? badgeColor}) {
    final isSelected = _selectedFilter == key;
    final primaryColor = badgeColor ?? const Color(0xFF1E66D0);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
      ),
      backgroundColor: isDark ? AppColors.darkBgCard : Colors.white,
      selectedColor: primaryColor,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? primaryColor
              : (isDark ? AppColors.darkBorderMedium : const Color(0xFFE2E8F0)),
        ),
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  // ── Empty Filter State ──
  Widget _buildEmptyFilterState(bool isDark) {
    String message;
    IconData icon;
    switch (_selectedFilter) {
      case 'correct':
        message = 'Tidak ada soal yang ditandai benar';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'wrong':
        message = 'Tidak ada soal yang ditandai salah';
        icon = Icons.cancel_outlined;
        break;
      case 'ungraded':
        message = 'Tidak ada soal yang tidak dinilai';
        icon = Icons.remove_circle_outline_rounded;
        break;
      default:
        message = 'Belum ada soal yang tersedia';
        icon = Icons.quiz_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isDark ? AppColors.darkTextMuted : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextMuted
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Answer Card Item ──
  Widget _buildAnswerCard(
    BuildContext context,
    ActivityAnswerResult answer,
    int questionNumber,
    bool isDark,
  ) {
    final isCorrect = answer.isCorrect;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isCorrect == true) {
      statusColor = const Color(0xFF10B981);
      statusText = 'Benar';
      statusIcon = Icons.check_circle_rounded;
    } else if (isCorrect == false) {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Salah';
      statusIcon = Icons.cancel_rounded;
    } else if (result.isCheated) {
      // Soal tidak dinilai karena submission ditandai curang
      statusColor = const Color(0xFFDC2626);
      statusText = 'Curang';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = const Color(0xFF64748B);
      statusText = 'Tidak Dinilai';
      statusIcon = Icons.info_outline_rounded;
    }

    final hasUserAnswer =
        answer.userAnswer != null && answer.userAnswer!.trim().isNotEmpty;
    final userAns = answer.userAnswer?.trim() ?? '';
    final isImg = _isImageUrl(userAns);
    final isHttp = _isHttpUrl(userAns);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorderMedium
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Colored Accent Line
              Container(
                width: 6,
                color: statusColor,
              ),
              // Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Soal #{num} & Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Soal #$questionNumber',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1E66D0),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 13, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Question Statement
                      if (answer.rawLabel.contains('<'))
                        RichTextView(
                          html: answer.rawLabel,
                          textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                          ),
                        )
                      else
                        Text(
                          answer.label.isEmpty
                              ? 'Pertanyaan #$questionNumber'
                              : answer.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // ── User Answer Box ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  isCorrect == true
                                      ? 'Jawaban Kamu (Benar):'
                                      : (isCorrect == false
                                          ? 'Jawaban Kamu (Salah):'
                                          : 'Jawaban Kamu:'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (!hasUserAnswer)
                              Text(
                                '(Tidak dijawab / Dikosongkan)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF94A3B8),
                                ),
                              )
                            else if (isImg) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () => _launchUrl(userAns),
                                  child: Image.network(
                                    userAns,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Text(
                                      userAns,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _launchUrl(userAns),
                                child: Text(
                                  'Lihat Gambar Penuh ↗',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF2563EB),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ] else if (isHttp) ...[
                              InkWell(
                                onTap: () => _launchUrl(userAns),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Buka Lampiran File ↗',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Text(
                                userAns,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── Correct Answer Box (If revealed) ──
                      if (answer.correctAnswer != null &&
                          answer.correctAnswer!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.key_rounded,
                                    size: 14,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kunci Jawaban yang Benar:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                answer.correctAnswer!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
