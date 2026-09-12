import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'ngrok_image.dart';

class ShareFormDialog extends StatefulWidget {
  final String link;
  final String qrUrl;
  final String? fileName;

  const ShareFormDialog({
    super.key,
    required this.link,
    required this.qrUrl,
    this.fileName,
  });

  @override
  State<ShareFormDialog> createState() => _ShareFormDialogState();
}

class _ShareFormDialogState extends State<ShareFormDialog> {
  int _selectedTab = 0;
  late final TextEditingController _linkController;
  bool _downloadingQr = false;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController(text: widget.link);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShareFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) {
      _linkController.text = widget.link;
    }
  }

  Future<void> _downloadQr() async {
    setState(() => _downloadingQr = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName ?? 'qrcode-form.png'}');
      final res = await http.get(Uri.parse(widget.qrUrl));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('Respons kosong (${res.statusCode})');
      }
      await file.writeAsBytes(res.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'QR Code Form'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh QR: $e')));
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kirim formulir',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kirim melalui',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _tabIcon(context, Icons.link, 0),
                const SizedBox(width: 4),
                _tabIcon(context, Icons.qr_code, 1),
              ],
            ),
            const Divider(height: 24),
            if (_selectedTab == 0) _buildLinkTab() else _buildQrTab(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabIcon(BuildContext context, IconData icon, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF0F52BA), width: 3),
                )
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? const Color(0xFF0F52BA)
              : colorScheme.onSurfaceVariant,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildLinkTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _linkController,
          readOnly: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB)),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.link));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Tautan disalin!')));
            },
            child: const Text(
              'Salin',
              style: TextStyle(
                color: Color(0xFF0F52BA),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: NgrokImage(
              widget.qrUrl,
              height: 180,
              width: 180,
              errorBuilder: (context, error, stackTrace) => SizedBox(
                height: 180,
                width: 180,
                child: Center(
                  child: Icon(
                    Icons.qr_code,
                    size: 80,
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _downloadingQr ? null : _downloadQr,
                icon: _downloadingQr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
                label: const Text('Unduh QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
