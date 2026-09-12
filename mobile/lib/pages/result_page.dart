// lib/pages/result_page.dart
// Halaman Hasil Respons — menampilkan daftar semua responden suatu form.
// Menggunakan data nyata dari API /forms/{id}/submissions + /forms/{id}
// untuk menghitung skor client-side (parity dengan web).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/form_model.dart';
import '../services/api_service.dart';
import '../utils/export_helper.dart';
import '../widgets/share_form_dialog.dart';
import 'detail_response_page.dart';

class ResultPage extends StatefulWidget {
  final String formId;
  final String formTitle;

  const ResultPage({super.key, required this.formId, required this.formTitle});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<
    ({
      List<SubmissionModel> subs,
      Map<String, Set<String>> gradeMap,
      Map<String, String> labels,
      Map<String, _QuestionAgg> questions,
      String? joinToken,
    })
  >
  _dataFuture;

  String _statusFilter = 'semua'; // semua / selesai / proses / curang

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  void _reload() {
    setState(() => _dataFuture = _fetchData());
  }

  Future<
    ({
      List<SubmissionModel> subs,
      Map<String, Set<String>> gradeMap,
      Map<String, String> labels,
      Map<String, _QuestionAgg> questions,
      String? joinToken,
    })
  >
  _fetchData() async {
    final subRes = await ApiService.getFormSubmissions(widget.formId);
    if (subRes['success'] != true) {
      throw Exception(subRes['message'] ?? 'Gagal memuat respons');
    }
    final subs = (subRes['data'] as List<dynamic>)
        .map((e) => SubmissionModel.fromJson(e as Map))
        .toList();

    // Ambil detail form: label soal, opsi (untuk kunci + analitik), tipe, dan token akses.
    final gradeMap = <String, Set<String>>{};
    final labels = <String, String>{};
    final questions = <String, _QuestionAgg>{};
    String? joinToken;
    final formRes = await ApiService.getForm(widget.formId);
    if (formRes['success'] == true && formRes['data'] is Map) {
      final formData = Map<String, dynamic>.from(formRes['data'] as Map);
      joinToken = formData['join_token']?.toString();
      final qlist = formData['questions'] as List? ?? [];
      for (final raw in qlist) {
        if (raw is! Map) continue;
        final qid = raw['id']?.toString() ?? '';
        if (qid.isEmpty) continue;
        final opts = raw['options'] as List? ?? [];
        final optionList = opts
            .whereType<Map>()
            .map(
              (o) => (
                label: _cleanText(o['label']?.toString() ?? 'Opsi'),
                isCorrect: o['is_correct'] == true,
              ),
            )
            .toList();
        final keys = optionList
            .where((o) => o.isCorrect)
            .map((o) => o.label)
            .toSet();
        gradeMap[qid] = keys;
        labels[qid] = _cleanText(raw['label']?.toString() ?? '');
        if (optionList.isNotEmpty) {
          questions[qid] = _QuestionAgg(
            type: raw['type']?.toString() ?? '',
            options: optionList,
          );
        }
      }
    }
    return (
      subs: subs,
      gradeMap: gradeMap,
      labels: labels,
      questions: questions,
      joinToken: joinToken,
    );
  }

  String _cleanText(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ── Penilaian (logika = backend/export.py) ──────────────────────────────
  bool _answerMatches(AnswerModel a, Set<String> keys) {
    final selected = (a.answerOptions != null && a.answerOptions!.isNotEmpty)
        ? a.answerOptions!.toSet()
        : (a.answerText != null && a.answerText!.isNotEmpty)
        ? {a.answerText!}
        : <String>{};
    return selected.length == keys.length && selected.containsAll(keys);
  }

  int? _scoreOf(SubmissionModel sub, Map<String, Set<String>> gradeMap) {
    final graded = gradeMap.entries.where((e) => e.value.isNotEmpty).toList();
    if (graded.isEmpty) return null;
    var correct = 0;
    for (final e in graded) {
      final a = sub.answersById[e.key];
      if (a == null) continue;
      if (_answerMatches(a, e.value)) correct++;
    }
    return (correct / graded.length * 100).round();
  }

  Future<void> _openShareDialog() async {
    try {
      final qrRes = await ApiService.generateQrCode(widget.formId);
      if (qrRes['success'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              qrRes['message']?.toString() ?? 'Gagal memuat link & QR code',
            ),
          ),
        );
        return;
      }

      final data = qrRes['data'];
      if (data is! Map) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link dan QR code tidak tersedia.')),
        );
        return;
      }

      var shareLink = (data['share_link'] ?? '').toString();
      final qrUrl = (data['qr_code_url'] ?? '').toString();
      if (shareLink.isNotEmpty) {
        shareLink = ApiService.publicFormLink(shareLink);
      }

      if (shareLink.isEmpty || qrUrl.isEmpty) {
        final detailRes = await ApiService.getForm(widget.formId);
        final formData = detailRes['data'];
        if (formData is Map) {
          final slug = (formData['slug'] ?? '').toString();
          if (slug.isNotEmpty) {
            shareLink = ApiService.publicFormLink(slug);
          }
        }
      }

      if (!mounted) return;
      if (shareLink.isEmpty || qrUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link publik belum tersedia untuk form ini.'),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => ShareFormDialog(link: shareLink, qrUrl: qrUrl),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka share dialog: $e')));
    }
  }

  Future<void> _copyJoinToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token berhasil disalin ke clipboard')),
    );
  }

  Future<void> _regenerateJoinToken() async {
    final res = await ApiService.regenerateJoinToken(widget.formId);
    if (!mounted) return;
    if (res['success'] == true) {
      final newToken = (res['data'] as Map?)?['join_token']?.toString();
      if (newToken != null && newToken.isNotEmpty) {
        setState(() => _dataFuture = _fetchData());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token berhasil dibuat ulang')),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ?? 'Gagal membuat ulang token',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.formTitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Hasil Respons',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Lihat Link & QR Code',
            onPressed: _openShareDialog,
          ),
          IconButton(
            icon: const Icon(
              Icons.table_chart_outlined,
              color: Color(0xFF059669),
            ),
            tooltip: 'Export ke Spreadsheet',
            onPressed: () => exportFormSubmissionsWithShare(
              context,
              widget.formId,
              '${widget.formId}-hasil.xlsx',
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: _reload,
          ),
        ],
      ),
      body:
          FutureBuilder<
            ({
              List<SubmissionModel> subs,
              Map<String, Set<String>> gradeMap,
              Map<String, String> labels,
              Map<String, _QuestionAgg> questions,
              String? joinToken,
            })
          >(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              final data = snapshot.data!;
              final submissions = data.subs
                  .where((s) => _passFilter(s))
                  .toList();
              return _buildContent(
                submissions,
                data.gradeMap,
                data.labels,
                data.questions,
                data.joinToken,
              );
            },
          ),
    );
  }

  bool _passFilter(SubmissionModel s) {
    switch (_statusFilter) {
      case 'selesai':
        return s.submittedAt != null;
      case 'proses':
        return s.submittedAt == null;
      case 'curang':
        return s.isCheated;
      default:
        return true;
    }
  }

  Widget _buildContent(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
    Map<String, _QuestionAgg> questions,
    String? joinToken,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((joinToken ?? '').isNotEmpty) ...[
            _buildJoinTokenCard(joinToken!),
            const SizedBox(height: 20),
          ],
          _buildSummaryCard(submissions, gradeMap),
          const SizedBox(height: 20),
          if (submissions.isNotEmpty) ...[
            _buildScoreDistribution(submissions, gradeMap),
            const SizedBox(height: 20),
            _buildGradeDonut(questions),
            const SizedBox(height: 20),
            _buildQuestionAnalytics(submissions, questions, labels),
            const SizedBox(height: 20),
          ],
          _buildFilterRow(),
          const SizedBox(height: 20),
          Text(
            'Siapa yang Mengisi Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (submissions.isEmpty)
            _buildEmptyState()
          else
            _buildRespondentList(submissions, gradeMap, labels),
        ],
      ),
    );
  }

  Widget _buildJoinTokenCard(String token) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security,
                  size: 18,
                  color: Color(0xFF4338CA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Token akses form',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF312E81),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gunakan token untuk membuka akses form',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menu token',
                icon: const Icon(Icons.more_vert, color: Color(0xFF312E81)),
                onSelected: (value) {
                  if (value == 'copy') {
                    _copyJoinToken(token);
                  } else if (value == 'regen') {
                    _regenerateJoinToken();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'copy', child: Text('Salin token')),
                  PopupMenuItem(
                    value: 'regen',
                    child: Text('Generate ulang token'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8C5FF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    token,
                    style: const TextStyle(
                      letterSpacing: 1.2,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _copyJoinToken(token),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC7D2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.copy_all_rounded,
                      size: 18,
                      color: Color(0xFF312E81),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildFilterRow() {
    Widget chip(String label, String value) {
      final selected = _statusFilter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        selectedColor: const Color(0xFF059669),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: selected
              ? const Color(0xFF059669)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        onSelected: (_) => setState(() => _statusFilter = value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Semua Status', 'semua'),
        chip('Selesai', 'selesai'),
        chip('Proses', 'proses'),
        chip('Curang', 'curang'),
      ],
    );
  }

  Widget _buildRespondentList(
    List<SubmissionModel> submissions,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: submissions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final sub = submissions[index];
          return _buildRespondentTile(sub, gradeMap, labels);
        },
      ),
    );
  }

  Widget _buildRespondentTile(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    final initial = sub.respondentName.isNotEmpty
        ? sub.respondentName[0].toUpperCase()
        : '?';
    final timeStr = sub.submittedAt != null
        ? _formatTime(sub.submittedAt!)
        : 'Belum dikirim';
    final score = _scoreOf(sub, gradeMap);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailResponsePage(
              name: sub.respondentName,
              email: sub.respondentEmail,
              time: timeStr,
              isAuto: sub.isAutoSubmitted,
              isCheated: sub.isCheated,
              scoreText: score != null ? '$score/100' : null,
              formTitle: widget.formTitle,
              answers: _buildAnswerDetails(sub, gradeMap, labels),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1E40AF),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.respondentName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.respondentEmail == '-' ? 'Anonim' : sub.respondentEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.isAutoSubmitted
                        ? '$timeStr • dikirim otomatis'
                        : timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusPill(sub),
            const SizedBox(width: 8),
            if (score != null)
              Text(
                '$score/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: score >= 70
                      ? const Color(0xFF059669)
                      : (score >= 40
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626)),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(SubmissionModel sub) {
    final (String label, Color color, Color bg) = sub.isCheated
        ? ('Curang', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
        : sub.submittedAt != null
        ? ('Selesai', const Color(0xFF059669), const Color(0xFFD1FAE5))
        : ('Proses', const Color(0xFFD97706), const Color(0xFFFEF3C7));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildAnswerDetails(
    SubmissionModel sub,
    Map<String, Set<String>> gradeMap,
    Map<String, String> labels,
  ) {
    return sub.answers.map((a) {
      final keys = gradeMap[a.questionId];
      final graded = keys != null && keys.isNotEmpty;
      bool? isCorrect;
      if (graded) isCorrect = _answerMatches(a, keys);
      return {
        'question': (labels[a.questionId]?.isNotEmpty ?? false)
            ? labels[a.questionId]
            : a.questionLabel,
        'answer': _cleanText(a.display),
        'isCorrect': isCorrect,
        'correctAnswer': (graded && keys.isNotEmpty)
            ? _cleanText(keys.join(', '))
            : null,
        'fileUrl': a.fileUrl,
      };
    }).toList();
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            _statusFilter == 'semua'
                ? 'Belum ada respons'
                : 'Tidak ada respons dengan status ini',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            'Bagikan link form untuk mulai menerima jawaban.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Tidak dapat memuat respons',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _reload, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return '${dt.day}/${dt.month}/${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

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
