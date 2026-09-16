import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/quill_html.dart';
import 'ngrok_image.dart';

/// Renders an HTML string produced by [RichTextField] / the web builder.
///
/// Used in previews and the fill page so respondents see formatted text
/// instead of raw `<p>` / `<strong>` markup.
class RichTextView extends StatelessWidget {
  final String? html;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const RichTextView({
    super.key,
    required this.html,
    this.textStyle,
    this.padding,
  });

  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final content = html?.trim() ?? '';
    if (content.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? const Color(0xFFF8FAFC) : Colors.black87;

    final ts = textStyle;
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Html(
        data: QuillHtml.normalizeHtmlForDisplay(content),
        extensions: [
          // ── 1. Custom Image Renderer ─────────────────────────
          TagExtension(
            tagsToExtend: {'img'},
            builder: (ctx) {
              final rawSrc = ctx.attributes['src'] ?? '';
              if (rawSrc.isEmpty) return const SizedBox.shrink();
              final src = QuillHtml.resolveImageUrl(rawSrc);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 360),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: NgrokImage(
                      src,
                      fit: BoxFit.contain,
                      enablePreview: true,
                    ),
                  ),
                ),
              );
            },
          ),

          // ── 2. Custom Video Embed Renderer ───────────────────
          TagExtension(
            tagsToExtend: {'video-embed'},
            builder: (ctx) {
              final videoUrl =
                  ctx.attributes['data-video'] ??
                  ctx.attributes['data-embed'] ??
                  '';
              if (videoUrl.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: InkWell(
                  onTap: () async {
                    if (videoUrl.isNotEmpty) {
                      final uri = Uri.tryParse(videoUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video Tersemat',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E40AF),
                              ),
                            ),
                            Text(
                              videoUrl,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── 3. Custom Audio Player Indicator ─────────────────
          TagExtension(
            tagsToExtend: {'audio'},
            builder: (ctx) {
              final audioSrc =
                  QuillHtml.resolveImageUrl(ctx.attributes['src'] ?? '');
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.audiotrack,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        audioSrc.isNotEmpty
                            ? audioSrc.split('/').last
                            : 'Berkas Audio',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (audioSrc.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                        tooltip: 'Buka Audio',
                        onPressed: () async {
                          final uri = Uri.tryParse(audioSrc);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                  ],
                ),
              );
            },
          ),

          // ── 4. Custom Display Math Formula Renderer ────────
          TagExtension(
            tagsToExtend: {'math-display'},
            builder: (ctx) {
              final latex = ctx.attributes['data-latex'] ?? ctx.element?.text ?? '';
              if (latex.trim().isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '𝑓𝑥',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        latex.trim(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        style: {
          '.ql-formula': Style(
            fontFamily: 'monospace',
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
          ),
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: ts?.fontSize != null
                ? FontSize(ts!.fontSize!)
                : FontSize.medium,
            fontWeight: ts?.fontWeight ?? FontWeight.normal,
            fontStyle: ts?.fontStyle,
            color: ts?.color ?? defaultColor,
            lineHeight: ts?.height != null
                ? LineHeight(ts!.height!)
                : LineHeight(1.2),
            fontFamily: ts?.fontFamily,
            letterSpacing: ts?.letterSpacing,
            textDecoration: ts?.decoration,
            textDecorationColor: ts?.decorationColor,
          ),
          'p': Style(margin: Margins.only(bottom: 4)),
          'a': Style(color: const Color(0xFF818CF8)),
          'blockquote': Style(
            margin: Margins.symmetric(vertical: 4),
            padding: HtmlPaddings.only(left: 12),
            border: const Border(
              left: BorderSide(
                color: Color(0xFF6366F1),
                width: 3,
              ),
            ),
            fontStyle: FontStyle.italic,
          ),
          'pre': Style(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            padding: HtmlPaddings.all(8),
            fontFamily: 'monospace',
          ),
          'code': Style(
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            fontFamily: 'monospace',
          ),
        },
      ),
    );
  }
}
