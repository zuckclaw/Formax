// Builder analitik ResultPage — kartu ringkasan, distribusi skor,
// donut tipe penilaian, analitik + breakdown per soal.
// Dipindah verbatim dari `lib/pages/result_page.dart` (Tahap 5b) tanpa
// perubahan apa pun (pre-scan: nol setState di blok ini). File ini adalah
// `part` dari library yang sama sehingga akses state/helper privat
// (_scoreOf, ...) tetap sah; call-site tidak berubah.
part of '../result_page.dart';

extension _ResultAnalytics on _ResultPageState {
  Widget _buildSummaryCard(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
  ) {
    final scores = submissions
        .map((s) => _scoreOf(s, gradeMap))
        .whereType<int>()
        .toList();
    final highest = scores.isEmpty ? null : scores.reduce(max);
    final lowest = scores.isEmpty ? null : scores.reduce(min);
    final hasGrades = highest != null;

    Widget stat(String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          stat('Total Respons', '${submissions.length}'),
          if (hasGrades) ...[
            const _VDivider(),
            stat('Nilai Tertinggi', '$highest/100'),
          ],
          if (hasGrades) ...[
            const _VDivider(),
            stat('Nilai Terendah', '$lowest/100'),
          ],
        ],
      ),
    );
  }

  // ── Analitik: Distribusi Skor (buckets) ────────────────────────────────
  Widget _buildScoreDistribution(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
  ) {
    final sizes = <({String label, int min, int? max, Color color})>[
      (label: '90–100', min: 90, max: 101, color: const Color(0xFF059669)),
      (label: '80–89', min: 80, max: 90, color: const Color(0xFF16A34A)),
      (label: '70–79', min: 70, max: 80, color: const Color(0xFF84CC16)),
      (label: '60–69', min: 60, max: 70, color: const Color(0xFFD97706)),
      (label: '50–59', min: 50, max: 60, color: const Color(0xFFF59E0B)),
      (label: '0–49', min: 0, max: 50, color: const Color(0xFFDC2626)),
    ];
    final scores = submissions
        .map((s) => _scoreOf(s, gradeMap))
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return const SizedBox.shrink();
    final total = scores.length;

    return _SectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Distribusi Skor',
      child: Column(
        children: [
          for (final s in sizes)
            _BucketRow(
              label: s.label,
              width:
                  scores
                      .where((sc) => sc >= s.min && sc < (s.max ?? 101))
                      .length /
                  total,
              count: scores
                  .where((sc) => sc >= s.min && sc < (s.max ?? 101))
                  .length,
              total: total,
              color: s.color,
            ),
        ],
      ),
    );
  }

  // ── Analitik: Donut Tipe Penilaian ─────────────────────────────────────
  Widget _buildGradeDonut(Map<String, _QuestionAgg> questions) {
    if (questions.isEmpty) return const SizedBox.shrink();
    final items = questions.values.toList();
    final auto = items.where((q) => q.options.any((o) => o.isCorrect)).length;
    final manual = items.where((q) {
      final t = q.type;
      final isGradable =
          t == 'single_choice' ||
          t == 'checkbox' ||
          t == 'dropdown' ||
          t == 'multiple_choice';
      return isGradable && !q.options.any((o) => o.isCorrect);
    }).length;
    final other = items.length - auto - manual;

    final slices = <({String label, Color color, int count})>[
      (
        label: 'Otomatis (ada kunci)',
        color: const Color(0xFF1E66D0),
        count: auto,
      ),
      (
        label: 'Manual (belum ada kunci)',
        color: const Color(0xFFD97706),
        count: manual,
      ),
      (label: 'Tanpa nilai', color: const Color(0xFF9CA3AF), count: other),
    ].where((s) => s.count > 0).toList();

    if (slices.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.donut_large_rounded,
      title: 'Tipe Penilaian',
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _DonutPainter(slices),
              child: Center(
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.label,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${s.count}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

  // ── Analitik: Distribusi Jawaban per Opsi (per soal) ───────────────────
  Widget _buildQuestionAnalytics(
    List<SubmissionModel> submissions,
    Map<String, _QuestionAgg> questions,
    Map<String, String> labels,
  ) {
    if (questions.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.insights_rounded,
      title: 'Analitik Pertanyaan',
      subtitle: 'Berapa banyak responden memilih tiap opsi',
      child: Column(
        children: [
          for (final entry in questions.entries) ...[
            _buildQuestionBreakdown(
              entry.key,
              entry.value,
              submissions,
              labels[entry.key] ?? '',
            ),
            const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionBreakdown(
    String qid,
    _QuestionAgg q,
    List<SubmissionModel> submissions,
    String questionLabel,
  ) {
    final total = submissions.length;
    final counts = <String, int>{for (final o in q.options) o.label: 0};
    int answered = 0;

    for (final sub in submissions) {
      final a = sub.answersById[qid];
      if (a == null) continue;
      var selected = <String>[];
      if (a.answerOptions != null && a.answerOptions!.isNotEmpty) {
        selected = a.answerOptions!;
      } else if (a.answerText != null && a.answerText!.isNotEmpty) {
        selected = [a.answerText!];
      }
      if (selected.isEmpty) continue;
      // Cocokkan label opsi; opsi "Lainnya" memakai teks bebas bebas.
      for (final sel in selected) {
        if (counts.containsKey(sel)) {
          counts[sel] = counts[sel]! + 1;
          answered++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionLabel.isEmpty ? 'Pertanyaan' : questionLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (q.options.isEmpty || total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Belum ada opsi untuk dianalisis',
              style: TextStyle(fontSize: 12),
            ),
          )
        else
          for (final o in q.options)
            _OptionBar(
              label: o.label,
              count: counts[o.label] ?? 0,
              total: total,
              isCorrect: o.isCorrect,
            ),
        const SizedBox(height: 4),
        Text(
          'Tidak dijawab: ${total - answered} dari $total',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
