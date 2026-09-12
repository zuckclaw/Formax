// lib/pages/historypage.dart
// Halaman History — menampilkan daftar form yang sudah dipublikasikan
// beserta jumlah responden, menggunakan data nyata dari API.

import 'package:flutter/material.dart';
import '../models/form_model.dart';
import '../services/api_service.dart';
import '../utils/export_helper.dart';
import 'formmakerpage.dart';
import 'result_page.dart';

class HistoryPage extends StatefulWidget {
  /// Jika diisi, akan di-highlight form dengan ID tersebut (dari Dashboard).
  final String? highlightFormId;

  const HistoryPage({super.key, this.highlightFormId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<FormModel>> _formsFuture;

  @override
  void initState() {
    super.initState();
    _formsFuture = _fetchForms();
  }

  Future<List<FormModel>> _fetchForms() async {
    final res = await ApiService.getMyForms();
    if (res['success'] == true) {
      final rawList = res['data'] as List<dynamic>;
      final forms = rawList.map((e) => FormModel.fromJson(e as Map)).toList();
      forms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return forms;
    }
    throw Exception(res['message'] ?? 'Gagal memuat data');
  }

  void _refresh() {
    setState(() => _formsFuture = _fetchForms());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<FormModel>>(
        future: _formsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          final forms = snapshot.data ?? [];
          if (forms.isEmpty) {
            return _buildEmptyState();
          }
          return _buildList(forms);
        },
      ),
    );
  }

  Widget _buildList(List<FormModel> forms) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lihat hasil jawaban formulir yang sudah dipublikasikan.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        ...forms.map(
          (form) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildHistoryCard(form),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(FormModel form) {
    final isHighlighted = form.id == widget.highlightFormId;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFB4C5D4)
              : Theme.of(context).colorScheme.outlineVariant,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail area
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: Colors.white38,
                  ),
                ),
                if (isHighlighted)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Chip(
                      label: Text(
                        'Baru!',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: Color(0xFF059669),
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          // Content area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  form.plainTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${form.totalSubmissions} responden',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(form.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Export button
                    OutlinedButton.icon(
                      onPressed: () => exportFormSubmissionsWithShare(
                        context,
                        form.id,
                        '${form.slug.isEmpty ? form.id : form.slug}-hasil.xlsx',
                      ),
                      icon: const Icon(Icons.table_chart_outlined, size: 14),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Lihat Hasil button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultPage(
                                formId: form.id,
                                formTitle: form.plainTitle,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Lihat Hasil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit form (parity web: menu titik tiga → Edit di Riwayat Form)
                    IconButton(
                      onPressed: () => _editForm(form),
                      tooltip: 'Edit form',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    // Hapus form (konfirmasi — parity web)
                    IconButton(
                      onPressed: () => _confirmDeleteForm(form),
                      tooltip: 'Hapus form',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editForm(FormModel form) async {
    final res = await ApiService.getForm(form.id);
    if (!mounted) return;
    if (res['success'] != true || res['data'] is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat form: ${res['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final formJson = Map<String, dynamic>.from(res['data'] as Map);
    await Navigator.push<FormMakerResult>(
      context,
      MaterialPageRoute(builder: (_) => FormMakerPage(initialDraft: formJson)),
    );
    if (!mounted) return;
    _refresh();
  }

  Future<void> _confirmDeleteForm(FormModel form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 10),
            Text('Hapus Form'),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus form "${form.plainTitle}"? '
          'Semua respons yang masuk ikut terhapus dan tindakan ini tidak bisa dibatalkan.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await ApiService.deleteForm(form.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form berhasil dihapus')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: ${res['message']}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Icon(
            Icons.history_toggle_off,
            size: 72,
            color: colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada formulir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Center(
          child: Text(
            'Publikasikan formulir dari tab Template\nuntuk melihatnya di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Tidak dapat memuat data',
            style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
