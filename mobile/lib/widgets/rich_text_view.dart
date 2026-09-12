import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../utils/quill_html.dart';

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
        data: QuillHtml.normalizeHtmlColors(content),
        style: {
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
          'img': Style(
            width: Width(100, Unit.percent),
            height: Height.auto(),
            margin: Margins.symmetric(vertical: 4),
          ),
        },
      ),
    );
  }
}
