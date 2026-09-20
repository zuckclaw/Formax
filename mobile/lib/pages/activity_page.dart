// lib/pages/activity_page.dart
// "Aktivitas Saya" — daftar form yang pernah/sedang diisi user sebagai responden.
// Parity dengan web: statistik, filter, progress, Lanjutkan (resume), Lihat Hasil.

import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../services/api_service.dart';
import 'fillformpage.dart';
import 'join_link_page.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<MyActivityModel> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | selesai | proses | curang
  // Parity web: pencarian judul + toggle grid/table.
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isTableView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final res = await ApiService.getMySubmissions();
    if (!mounted) return;
    if (res['success'] == true && res['data'] is List) {
      final items =
          (res['data'] as List)
              .whereType<Map>()
              .map((e) => MyActivityModel.fromJson(e))
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      setState(() {
        _items = items;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Gagal memuat aktivitas';
      });
    }
  }

  List<MyActivityModel> get _filtered {
    Iterable<MyActivityModel> list = _items;
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) {
        final title = e.formTitle.toLowerCase();
        final owner = (e.ownerName ?? '').toLowerCase();
        return title.contains(_searchQuery) || owner.contains(_searchQuery);
      });
    }
    switch (_filter) {
      case 'selesai':
        return list.where((e) => e.isCompleted && !e.isCheated).toList();
      case 'proses':
        return list.where((e) => !e.isCompleted).toList();
      case 'curang':
        return list.where((e) => e.isCheated).toList();
      default:
        return list.toList();
    }
  }

  int get _totSelesai => _items.where((e) => e.isCompleted).length;
  int get _totProses => _items.where((e) => !e.isCompleted).length;
  int get _totCurang => _items.where((e) => e.isCheated).length;

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmtDuration(DateTime start, DateTime end) {
    final d = end.difference(start);
    final mins = d.inMinutes;
    if (mins < 1) return '${d.inSeconds}s';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}j' : '${h}j ${m}m';
  }

  Future<void> _openResume(MyActivityModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FillFormPage(slug: item.formSlug)),
    );
    if (mounted) _load();
  }

  Future<void> _openResult(MyActivityModel item) async {
    final res = await ApiService.getSubmissionResult(item.id);
    if (!mounted) return;
    if (res['success'] != true || res['data'] is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat hasil: ${res['message']}')),
      );
      return;
    }
    final result = ActivityResultModel.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityResultScreen(result: result, item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E66D0),
        foregroundColor: Colors.white,
        title: const Text(
          'Aktivitas Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isTableView = !_isTableView),
            icon: Icon(_isTableView
                ? Icons.grid_view_rounded
                : Icons.table_chart_outlined),
            tooltip:
                _isTableView ? 'Tampilan kartu' : 'Tampilan tabel',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildStats(),
          const SizedBox(height: 16),
          // Pencarian judul/pemilik (parity web search box).
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari judul form atau pemilik...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (v) =>
                setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          _buildFilterRow(),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            _buildEmptyState()
          else if (_isTableView)
            _buildTableView()
          else
            ..._filtered.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActivityTile(e),
              ),
            ),
          if (_items.isNotEmpty && _filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Tidak ada aktivitas dengan filter ini',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada aktivitas.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Form yang kamu isi akan muncul di sini.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinLinkPage()),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Gabung dengan Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _statCard(
          'Total',
          _items.length,
          const Color(0xFF1E66D0),
          Icons.assignment_outlined,
        ),
        const SizedBox(width: 10),
        _statCard(
          'Selesai',
          _totSelesai,
          const Color(0xFF059669),
          Icons.check_circle_outline,
        ),
        const SizedBox(width: 10),
        _statCard(
          'Proses',
          _totProses,
          const Color(0xFFD97706),
          Icons.hourglass_top,
        ),
        const SizedBox(width: 10),
        _statCard(
          'Curang',
          _totCurang,
          const Color(0xFFDC2626),
          Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    const opts = [
      ('all', 'Semua'),
      ('selesai', 'Selesai'),
      ('proses', 'Proses'),
      ('curang', 'Curang'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opts.map((o) {
          final active = _filter == o.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.$2),
              selected: active,
              onSelected: (_) => setState(() => _filter = o.$1),
              selectedColor: const Color(0xFF1E66D0),
              labelStyle: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tampilan tabel spreadsheet (parity web table view).
  Widget _buildTableView() {
    final rows = _filtered;
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Tidak ada aktivitas dengan filter ini',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    Widget headerCell(String text, {double width = 140}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    Widget bodyCell(Widget child, {double width = 140}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: child,
        ),
      );
    }

    String statusOf(MyActivityModel e) => e.isCheated
        ? 'Curang'
        : (e.isCompleted ? 'Selesai' : 'Proses');

    Color statusColorOf(MyActivityModel e) => e.isCheated
        ? const Color(0xFFDC2626)
        : (e.isCompleted
            ? const Color(0xFF059669)
            : const Color(0xFFD97706));

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  headerCell('No', width: 44),
                  headerCell('Form', width: 180),
                  headerCell('Pemilik', width: 130),
                  headerCell('Status', width: 100),
                  headerCell('Progress', width: 110),
                  headerCell('', width: 52),
                ],
              ),
              Divider(height: 1, color: cs.outlineVariant),
              for (var i = 0; i < rows.length; i++) ...[
                InkWell(
                  onTap: () => rows[i].isCompleted
                      ? _openResult(rows[i])
                      : _openResume(rows[i]),
                  child: Row(
                    children: [
                      bodyCell(Text('${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                          width: 44),
                      bodyCell(
                        Text(
                          rows[i].formTitle.isEmpty
                              ? 'Form tanpa judul'
                              : rows[i].formTitle,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        width: 180,
                      ),
                      bodyCell(
                        Text(
                          rows[i].ownerName ?? '-',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        width: 130,
                      ),
                      bodyCell(
                        Text(
                          statusOf(rows[i]),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColorOf(rows[i]),
                          ),
                        ),
                        width: 100,
                      ),
                      bodyCell(
                        Text(
                          '${rows[i].answeredCount}/${rows[i].totalQuestions}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        width: 110,
                      ),
                      bodyCell(
                        Icon(
                          rows[i].isCompleted
                              ? Icons.visibility_outlined
                              : Icons.play_arrow,
                          size: 18,
                          color: const Color(0xFF1E66D0),
                        ),
                        width: 52,
                      ),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  Divider(height: 1, color: cs.outlineVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile(MyActivityModel item) {
    final isCheated = item.isCheated;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Parity web dark: rgba bg + teks terang.
    final (String stLabel, Color stColor, Color stBg) = isCheated
        ? ('Curang', isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
            isDark ? const Color(0x2EEF4444) : const Color(0xFFFEE2E2))
        : item.isCompleted
        ? ('Selesai', isDark ? const Color(0xFF86EFAC) : const Color(0xFF059669),
            isDark ? const Color(0x2E16A34A) : const Color(0xFFD1FAE5))
        : ('Proses', isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
            isDark ? const Color(0x2ECA8A04) : const Color(0xFFFEF3C7));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formTitle.isEmpty
                            ? 'Form tanpa judul'
                            : item.formTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.ownerName != null
                            ? 'oleh ${item.ownerName}'
                            : item.formSlug,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mulai: ${_relativeTime(item.startedAt)}'
                        '${item.isCompleted ? ' • Durasi: ${_fmtDuration(item.startedAt, item.submittedAt!)}' : ''}'
                        '${item.isAutoSubmitted ? ' • ⚡ otomatis' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.isCompleted &&
                        item.allowSeeResult &&
                        !item.revealAnswers)
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.totalQuestions == 0
                          ? 0
                          : (item.answeredCount / item.totalQuestions).clamp(
                              0.0,
                              1.0,
                            ),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation(
                        isCheated
                            ? const Color(0xFFDC2626)
                            : item.isCompleted
                            ? const Color(0xFF059669)
                            : const Color(0xFF1E66D0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.answeredCount}/${item.totalQuestions}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                if (!item.isCompleted)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openResume(item),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Lanjutkan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E66D0),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openResult(item),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(
                        item.allowSeeResult ? 'Lihat Hasil' : 'Hasil tertutup',
                      ),
                      style: item.allowSeeResult
                          ? null
                          : OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Layar "Lihat Hasil" — hasil submission milik responden
// ─────────────────────────────────────────────────────────────
class _ActivityResultScreen extends StatelessWidget {
  final ActivityResultModel result;
  final MyActivityModel item;

  const _ActivityResultScreen({required this.result, required this.item});

  @override
  Widget build(BuildContext context) {
    final score = result.scorePercent;
    final Color scoreColor = score == null
        ? Colors.grey
        : (score >= 70
              ? const Color(0xFF059669)
              : (score >= 40
                    ? const Color(0xFFD97706)
                    : const Color(0xFFDC2626)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E66D0),
        foregroundColor: Colors.white,
        title: const Text(
          'Hasil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            result.formTitle.isEmpty ? 'Form tanpa judul' : result.formTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (result.isCheated)
            Builder(builder: (context) {
              final isDark =
                  Theme.of(context).brightness == Brightness.dark;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x2EEF4444)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFFFCA5A5)
                              .withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terdeteksi curang (keluar dari mode full screen).',
                        style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFDC2626),
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          // Score card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                if (score != null) ...[
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    'Nilai',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Benar $score/100 • ${result.correctCount}/${result.totalGraded} soal',
                    style: const TextStyle(fontSize: 13),
                  ),
                ] else
                  Text(
                    'Form ini tidak memiliki kunci jawaban, jadi skor tidak dihitung.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (result.submittedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Dikirim: ${_dateStr(result.submittedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Jawaban',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (result.answers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Tidak ada jawaban.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...result.answers.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final a = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF1E66D0),
                      child: Text(
                        '$i',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.label.isEmpty ? 'Pertanyaan' : a.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.userAnswer ?? '-',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (a.isCorrect != null)
                            Row(
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: a.isCorrect == true
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    a.isCorrect == true ? '✓ Benar' : '✗ Salah',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: a.isCorrect == true
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (a.isCorrect == false && a.correctAnswer != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Kunci jawaban: ${a.correctAnswer}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static String _dateStr(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays < 1) {
      final two = dt.toLocal();
      final h = two.hour.toString().padLeft(2, '0');
      final m = two.minute.toString().padLeft(2, '0');
      return 'Hari ini $h:$m';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
