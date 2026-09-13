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

// Part: widget + painter murni — Tahap 5a.
// Sama-sama satu library, nama privat tetap sah tanpa rename.
part 'result/widgets_part.dart';

// Part: builder analitik — Tahap 5b.
// Sama-sama satu library, call-site tidak berubah.
part 'result/analytics_part.dart';

// Part: daftar, filter & status — Tahap 5c.
// Sama-sama satu library, call-site tidak berubah.
part 'result/list_part.dart';

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

  // Helper filter untuk extension list (result/list_part.dart):
  // setState HANYA di member State. Isi = pindahan verbatim callback chip.
  void _applyStatusFilter(String value) {
    setState(() => _statusFilter = value);
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

  // NOTE (Tahap 5c): _buildJoinTokenCard pindah ke result/list_part.dart
  // (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 5b): _buildSummaryCard & _buildScoreDistribution pindah ke
  // result/analytics_part.dart (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 5b): _buildGradeDonut, _buildQuestionAnalytics,
  // _buildQuestionBreakdown pindah ke result/analytics_part.dart
  // (verbatim, tanpa perubahan apa pun).

  // NOTE (Tahap 5c): _buildFilterRow, _buildRespondentList,
  // _buildRespondentTile, _buildStatusPill, _buildAnswerDetails,
  // _buildEmptyState, _buildErrorState, _formatTime pindah ke
  // result/list_part.dart; setState chip didelegasikan ke _applyStatusFilter
  // (urutan + isi statement identik). Tanpa perubahan logika/call-site.
}

// NOTE (Tahap 5a): _VDivider, _QuestionAgg, _SectionCard, _BucketRow,
// _OptionBar, _DonutPainter pindah ke result/widgets_part.dart
// (verbatim, tanpa perubahan apa pun).
