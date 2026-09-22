import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/quill_html.dart';
import 'code_block.dart';
import 'inline_video.dart';
import 'math_tex.dart';
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
    final defaultColor = isDark ? const Color(0xFFEEF2FF) : Colors.black87;

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
                            ? const Color(0xFF2D2D4A)
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
          // MP4 langsung → player inline (parity web <video>);
          // YouTube/Vimeo/Drive → kartu buka eksternal.
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
              if (InlineVideoPlayer.isDirectVideo(videoUrl)) {
                return InlineVideoPlayer(url: videoUrl);
              }
              return ExternalVideoCard(url: videoUrl);
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
                  color: isDark ? const Color(0xFF23233F) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.audiotrack,
                      color: Color(0xFF2563EB),
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
                          color: Color(0xFF2563EB),
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

          // ── 4. Custom Display Math Formula Renderer (KaTeX asli) ────────
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
                  color: isDark ? const Color(0xFF23233F) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
                  ),
                ),
                // Render KaTeX asli (parity web math-display-block).
                // Scroll horizontal agar matriks/integral lebar tidak overflow.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: MathTex.display(latex, isDark: isDark, fontSize: 16),
                ),
              );
            },
          ),

          // ── 5. Inline Math Formula Renderer (KaTeX asli) ───────────────
          TagExtension(
            tagsToExtend: {'ql-formula'},
            builder: (ctx) {
              final latex = ctx.attributes['data-value'] ?? ctx.element?.text ?? '';
              if (latex.trim().isEmpty) return const SizedBox.shrink();
              // Render KaTeX asli (parity web span.ql-formula).
              return MathTex.inline(latex, isDark: isDark, fontSize: 14);
            },
          ),

          // ── 6. Code Block dengan syntax highlighting (parity web hljs) ──
          TagExtension(
            tagsToExtend: {'pre'},
            builder: (ctx) {
              final code = ctx.element?.text.trim() ?? '';
              if (code.isEmpty) return const SizedBox.shrink();
              String? lang = ctx.attributes['class'];
              lang ??= ctx.element?.attributes['class'];
              final m = lang != null
                  ? RegExp(r'language-([\w+#]+)').firstMatch(lang)
                  : null;
              return CodeBlock(
                code: code,
                language: m?.group(1),
              );
            },
          ),
        ],
        style: {
          '.ql-formula': Style(
            fontFamily: 'monospace',
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
            backgroundColor: isDark ? const Color(0xFF2D2D4A) : const Color(0xFFE2E8F0),
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
            backgroundColor: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF1F5F9),
            padding: HtmlPaddings.all(8),
            fontFamily: 'monospace',
          ),
          'code': Style(
            backgroundColor: isDark ? const Color(0xFF23233F) : const Color(0xFFE2E8F0),
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            fontFamily: 'monospace',
          ),
        },
      ),
    );
  }
}
