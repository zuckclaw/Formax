// Lembar impor soal dari DOCX (parity web FormBuilderPage import modal).
// Alur: unduh template → pilih file .docx → pratinjau hasil parse →
// pilih soal → konfirmasi impor → parent me-reload editor dari server.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../services/api_service.dart';

class DocxImportSheet extends StatefulWidget {
  final String formId;

  /// Dipanggil setelah impor sukses; parent me-reload editor dari server.
  final Future<void> Function() onImported;

  const DocxImportSheet({
    super.key,
    required this.formId,
    required this.onImported,
  });

  @override
  State<DocxImportSheet> createState() => _DocxImportSheetState();
}

class _DocxImportSheetState extends State<DocxImportSheet> {
  bool _busy = false;
  String? _fileName;
  String? _error;
  List<Map<String, dynamic>> _questions = [];
  final Set<int> _selected = {};
  bool _confirming = false;

  Future<void> _downloadTemplate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ApiService.downloadDocxTemplate();
      if (!mounted) return;
      if (res['success'] != true || res['bytes'] == null) {
        final m = Map<String, dynamic>.from(res as Map);
        if (ApiService.isAuthInvalidResult(m) ||
            ApiService.isConnectionFailureResult(m)) {
          await ApiService.forceLogout();
          return;
        }
        setState(() {
          _error = res['message']?.toString() ?? 'Gagal mengunduh template';
          _busy = false;
        });
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/template-import-soal.docx');
      await file.writeAsBytes(res['bytes'] as List<int>);
      setState(() => _busy = false);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: 'template-import-soal.docx')],
          text: 'Template import soal Form4x',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mengunduh template: $e';
        _busy = false;
      });
    }
  }

  Future<void> _pickAndPreview() async {
    setState(() {
      _error = null;
      _questions = [];
      _selected.clear();
    });
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal membuka pemilih file: $e');
      return;
    }
    if (picked == null) return;
    final f = picked;
    final path = f.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'File tidak dapat dibaca di perangkat ini');
      return;
    }
    setState(() {
      _busy = true;
      _fileName = f.name;
    });
    final res = await ApiService.previewDocxImport(
      widget.formId,
      path,
      fileName: f.name,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      final m = Map<String, dynamic>.from(res as Map);
      if (ApiService.isAuthInvalidResult(m) ||
          ApiService.isConnectionFailureResult(m)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Gagal memproses file DOCX';
        _busy = false;
      });
      return;
    }
    final data = res['data'];
    final list = data is Map
        ? (data['questions'] as List? ?? [])
        : <dynamic>[];
    setState(() {
      _busy = false;
      _questions = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _selected.addAll(
        Iterable<int>.generate(_questions.length),
      );
    });
  }

  Future<void> _confirmImport() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Pilih minimal satu soal untuk diimpor');
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
    });
    final questions = <Map<String, dynamic>>[];
    for (final i in _selected.toList()..sort()) {
      final q = _questions[i];
      final opts = (q['options'] as List? ?? [])
          .whereType<Map>()
          .map((o) => Map<String, dynamic>.from(o))
          .toList();
      questions.add({
        'label': (q['label'] ?? '').toString(),
        'is_required': false,
        'options': [
          for (var k = 0; k < opts.length; k++)
            {
              'label': (opts[k]['label'] ?? '').toString(),
              'value': (opts[k]['value'] ?? opts[k]['label'] ?? '').toString(),
              'order_index': opts[k]['order_index'] is int
                  ? opts[k]['order_index']
                  : k,
              'is_correct': opts[k]['is_correct'] == true,
            },
        ],
      });
    }
    final res = await ApiService.confirmDocxImport(widget.formId, questions);
    if (!mounted) return;
    if (res['success'] != true) {
      final m = Map<String, dynamic>.from(res as Map);
      if (ApiService.isAuthInvalidResult(m) ||
          ApiService.isConnectionFailureResult(m)) {
        await ApiService.forceLogout();
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Gagal mengimpor soal';
        _confirming = false;
      });
      return;
    }
    setState(() => _confirming = false);
    await widget.onImported();
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (res['data'] is Map && (res['data'] as Map)['message'] != null)
              ? (res['data'] as Map)['message'].toString()
              : '${questions.length} soal berhasil diimpor',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Impor Soal dari Word',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Template'),
                ),
              ],
            ),
            Text(
              'Format: soal "1." dan opsi "A." — unduh template bila ragu.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_busy || _confirming) ? null : _pickAndPreview,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_fileName == null
                    ? 'Pilih file .docx'
                    : 'Ganti file ($_fileName)'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!_busy && _questions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${_selected.length} dari ${_questions.length} soal dipilih',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length == _questions.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(
                          Iterable<int>.generate(_questions.length),
                        );
                      }
                    }),
                    child: Text(_selected.length == _questions.length
                        ? 'Batal semua'
                        : 'Pilih semua'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _questions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final q = _questions[i];
                    final opts = (q['options'] as List? ?? []).length;
                    final errs = (q['errors'] as List? ?? [])
                        .map((e) => e.toString())
                        .toList();
                    final labelHtml = (q['label'] ?? '').toString();
                    
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _selected.contains(i),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      }),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${q['number'] ?? (i + 1)}.',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.65,
                            child: Html(
                              data: labelHtml,
                              style: {
                                'body': Style(
                                  fontSize: FontSize(13),
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                ),
                                'p': Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                  fontSize: FontSize(13),
                                ),
                                'code': Style(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  padding: HtmlPaddings.symmetric(horizontal: 4),
                                  fontSize: FontSize(12),
                                  fontFamily: 'monospace',
                                ),
                                'pre': Style(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  padding: HtmlPaddings.all(8),
                                  margin: Margins.symmetric(vertical: 4),
                                  fontSize: FontSize(12),
                                  fontFamily: 'monospace',
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                ),
                                'img': Style(
                                  width: Width(100, Unit.percent),
                                  height: Height.auto(),
                                  margin: Margins.symmetric(vertical: 4),
                                ),
                                'div': Style(
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                ),
                              },
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        errs.isNotEmpty
                            ? errs.join('; ')
                            : '$opts opsi',
                        style: TextStyle(
                          fontSize: 11,
                          color: errs.isNotEmpty
                              ? const Color(0xFFD97706)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_confirming || _selected.isEmpty)
                      ? null
                      : _confirmImport,
                  icon: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download_done_outlined),
                  label: Text(_confirming
                      ? 'Mengimpor...'
                      : 'Impor ${_selected.length} soal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
