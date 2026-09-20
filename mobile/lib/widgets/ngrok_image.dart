import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Robust image viewer for Form4x mobile app that automatically:
/// 1. Resolves relative backend paths (`/static/uploads/...`) to absolute URLs
/// 2. Injects `ngrok-skip-browser-warning: true` header for ngrok tunnels
/// 3. Supports Base64 data URLs (`data:image/...`)
/// 4. Supports local files (`/path/to/file` or `file://...`)
/// 5. Supports interactive full-screen preview with pinch-to-zoom when [enablePreview] is true
class NgrokImage extends StatelessWidget {
  const NgrokImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.filterQuality,
    this.enablePreview = false,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final FilterQuality? filterQuality;
  final bool enablePreview;

  static const String _skipWarningHeader = 'ngrok-skip-browser-warning';

  /// Resolves relative URLs (e.g. `/static/uploads/...`) to backend URLs.
  static String resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final s = url.trim();
    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('data:') ||
        s.startsWith('blob:') ||
        s.startsWith('file:')) {
      return s;
    }
    final base = ApiService.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = s.startsWith('/') ? s : '/$s';
    return '$base$cleanPath';
  }

  /// Returns an [ImageProvider] that handles relative paths, data URLs,
  /// local files, and ngrok network images.
  static ImageProvider provider(String rawUrl, {double scale = 1.0}) {
    final clean = resolveUrl(rawUrl);
    if (clean.startsWith('data:image')) {
      try {
        final commaIdx = clean.indexOf(',');
        final b64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        return MemoryImage(base64Decode(b64), scale: scale);
      } catch (_) {}
    }
    if (!kIsWeb) {
      if (clean.startsWith('file://')) {
        return FileImage(File(clean.replaceFirst('file://', '')), scale: scale);
      }
      if (!clean.startsWith('http') && File(clean).existsSync()) {
        return FileImage(File(clean), scale: scale);
      }
    }
    final host = Uri.tryParse(clean)?.host.toLowerCase() ?? '';
    final isNgrok = host.contains('ngrok');
    return NetworkImage(
      clean,
      scale: scale,
      headers: isNgrok ? const {_skipWarningHeader: 'true'} : null,
    );
  }

  void _showFullScreen(BuildContext context, String resolvedUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NgrokImage(resolvedUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clean = resolveUrl(imageUrl);
    if (clean.isEmpty) {
      return _buildError(context);
    }

    Widget content;

    // 1. Data URL (Base64)
    if (clean.startsWith('data:image')) {
      try {
        final commaIdx = clean.indexOf(',');
        final b64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        content = Image.memory(
          base64Decode(b64),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder ?? (ctx, err, st) => _buildError(ctx),
          filterQuality: filterQuality ?? FilterQuality.low,
        );
      } catch (_) {
        content = _buildError(context);
      }
    }
    // 2. Local File
    else if (!kIsWeb &&
        (clean.startsWith('file://') ||
            (!clean.startsWith('http') && File(clean).existsSync()))) {
      final filePath = clean.startsWith('file://')
          ? clean.replaceFirst('file://', '')
          : clean;
      content = Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (ctx, err, st) => _buildError(ctx),
        filterQuality: filterQuality ?? FilterQuality.low,
      );
    }
    // 3. Network URL (HTTP / HTTPS / Ngrok)
    else {
      final host = Uri.tryParse(clean)?.host.toLowerCase() ?? '';
      final isNgrok = host.contains('ngrok');
      final headers = isNgrok ? const {_skipWarningHeader: 'true'} : null;

      content = Image.network(
        clean,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (ctx, err, st) => _buildError(ctx),
        filterQuality: filterQuality ?? FilterQuality.low,
        headers: headers,
      );
    }

    if (enablePreview) {
      return GestureDetector(
        onTap: () => _showFullScreen(context, clean),
        child: content,
      );
    }

    return content;
  }

  Widget _buildError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: isDark ? const Color(0xFF23233F) : const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: isDark ? const Color(0xFF94A3B8) : Colors.black38,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Gambar gagal dimuat',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
