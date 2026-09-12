import 'package:flutter/material.dart';

/// Wrapper untuk [Image.network] yang otomatis menambahkan header
/// `ngrok-skip-browser-warning` saat URL menunjuk ke host ngrok-free.dev.
///
/// Ngrok free menyuntikkan halaman interstitial HTML (bukan gambar) untuk
/// permintaan tanpa header ini, sehingga [Image.network] gagal dengan
/// "HTTP request failed, statusCode: 0". Header ini membuat worker/agent
/// (termasuk Flutter web & native) dianggap sebagai non-browser dan
/// mengembalikan konten asli.
class NgrokImage extends StatelessWidget {
  const NgrokImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.filterQuality,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final FilterQuality? filterQuality;

  static const String _skipWarningHeader = 'ngrok-skip-browser-warning';

  /// Kembalikan [ImageProvider] (NetworkImage dengan header ngrok) untuk dipakai
  /// di [DecorationImage] / BoxDecoration.image atau [Image] provider.
  static ImageProvider provider(String imageUrl, {double scale = 1.0}) {
    final isNgrok =
        Uri.tryParse(imageUrl)?.host.endsWith('ngrok-free.dev') ?? false;
    return NetworkImage(
      imageUrl,
      scale: scale,
      headers: isNgrok ? const {_skipWarningHeader: 'true'} : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNgrok =
        Uri.tryParse(imageUrl)?.host.endsWith('ngrok-free.dev') ?? false;
    final headers = isNgrok ? const {_skipWarningHeader: 'true'} : null;

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          errorBuilder ?? (context, error, stackTrace) => _buildError(context),
      filterQuality: filterQuality ?? FilterQuality.low,
      headers: headers,
    );
  }

  Widget _buildError(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      alignment: Alignment.center,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
