// Widget + painter murni ResultPage — divider, agregasi, kartu section,
// baris bucket/opsi, painter donut.
// Dipindah verbatim dari `lib/pages/result_page.dart` (Tahap 5a) tanpa
// perubahan apa pun. File ini adalah `part` dari library yang sama sehingga
// nama privat (_VDivider, _QuestionAgg, ...) tetap sah tanpa rename.
part of '../result_page.dart';

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Ringkasan agregasi per soal: tipe soal + daftar opsi (label + is_correct).
class _QuestionAgg {
  final String type;
  final List<({String label, bool isCorrect})> options;

  const _QuestionAgg({required this.type, required this.options});
}

/// Kartu section analitik dengan ikon + judul + subtitle opsional.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E66D0)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Satu baris bucket distribusi skor (label + bar + jumlah).
class _BucketRow extends StatelessWidget {
  final String label;
  final double width; // 0..1
  final int count;
  final int total;
  final Color color;

  const _BucketRow({
    required this.label,
    required this.width,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  FractionallySizedBox(
                    widthFactor: width.clamp(0.0, 1.0),
                    child: Container(height: 16, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              '$count/$total',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris opsi pada analitik pertanyaan.
class _OptionBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final bool isCorrect;

  const _OptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    final color = isCorrect ? const Color(0xFF059669) : const Color(0xFF1E66D0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            child: Icon(
              isCorrect ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: color,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(height: 8, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count${total > 0 ? ' (${(pct * 100).round()}%)' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCorrect ? const Color(0xFF059669) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter donut untuk Tipe Penilaian.
class _DonutPainter extends CustomPainter {
  final List<({String label, Color color, int count})> slices;

  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;

    var start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * (s.count / total);
      stroke.color = s.color;
      canvas.drawArc(rect, start, sweep, false, stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}
