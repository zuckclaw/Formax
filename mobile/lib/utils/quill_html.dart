import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import '../services/api_service.dart';

/// Self-contained bridge between HTML (used by the web app / backend, e.g.
/// Quill's `<p>`, `<strong>`, `<em>`...) and a Quill [Document].
///
/// HTML -> Delta is delegated to the official `flutter_quill_delta_from_html`
/// package (transitive dep of flutter_quill 11). Delta -> HTML is a small
/// local writer so the mobile editor stays compatible with the HTML stored by
/// the web builder.
class QuillHtml {
  const QuillHtml._();

  /// Build a Quill [Document] from an HTML string (may be plain text).
  /// Falls back to a single plaintext line when parsing fails.
  static Document documentFromHtml(String? html) {
    if (html == null || html.trim().isEmpty) return Document();
    try {
      final delta = HtmlToDelta().convert(html);
      return Document.fromJson(delta.toJson());
    } catch (_) {
      return Document()..insert(0, html);
    }
  }

  /// Serialize a Quill [Document] back to an HTML string (round-trips with web).
  static String documentToHtml(Document doc) => deltaToHtml(doc.toDelta());

  /// Convert a Quill [Delta] to an HTML string.
  static String deltaToHtml(dynamic delta) {
    final out = StringBuffer();
    final inline =
        StringBuffer(); // accumulated inline html for the current line
    String? blockTag; // 'h1' | 'h2' | 'h3' | 'blockquote' | null (p)
    String? listTag; // 'ul' | 'ol' | null
    String? blockAlign; // block-level text-align for the current line
    double? blockLineHeight; // block-level line-height for the current line
    String? listAlign; // alignment captured for the open list group
    final listItems = <String>[];

    /// Inline (text-op) CSS. Preserves all inline formatting so that font
    /// size, font family, background colour and line spacing round-trip.
    String inlineStyle(Map<String, dynamic> a) {
      final s = <String>[];
      if (a['bold'] == true) s.add('font-weight: bold;');
      if (a['italic'] == true) s.add('font-style: italic;');
      if (a['underline'] == true) s.add('text-decoration: underline;');
      if (a['strike'] == true) s.add('text-decoration: line-through;');
      if (a['color'] != null) {
        s.add('color: ${normalizeHexColor(a['color']?.toString())};');
      }
      if (a['background'] != null) {
        s.add(
          'background-color: ${normalizeHexColor(a['background']?.toString())};',
        );
      }
      final sizePx = _quillSizeToPx(a['size']);
      if (sizePx != null) s.add('font-size: $sizePx;');
      if (a['font'] != null) s.add('font-family: ${a['font']};');
      final lh = a['line-height'];
      if (lh != null) s.add('line-height: $lh;');
      if (a['code'] == true) {
        s.add('font-family: monospace; background-color: rgba(148, 163, 184, 0.15); padding: 2px 4px; border-radius: 4px;');
      }
      return s.isEmpty ? '' : s.join(' ');
    }

    String blockStyle() {
      final s = <String>[];
      if (blockAlign != null) s.add('text-align: $blockAlign;');
      if (blockLineHeight != null) s.add('line-height: $blockLineHeight;');
      return s.isEmpty ? '' : ' style="${s.join(' ')}"';
    }

    void flushList() {
      if (listTag != null && listItems.isNotEmpty) {
        final align = listAlign != null
            ? ' style="text-align: $listAlign;"'
            : '';
        out.write('<$listTag$align>');
        for (final it in listItems) {
          out.write('<li>$it</li>');
        }
        out.write('</$listTag>');
      }
      listItems.clear();
      listTag = null;
      listAlign = null;
    }

    // flutter_quill does not export the Delta type, so this public bridge
    // keeps a dynamic input for compatibility with Document.toDelta().
    // ignore: avoid_dynamic_calls
    for (final rawOp in delta.toJson()) {
      if (rawOp is! Map) continue;
      final op = Map<String, dynamic>.from(rawOp);
      final data = op['insert'];
      if (data == null) continue;
      final attrs = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (data == '\n') {
        blockAlign = attrs['align'] as String?;
        blockLineHeight = (attrs['line-height'] as num?)?.toDouble();
        final block = attrs['block'] as String?;
        final rawList = block == 'ul' || block == 'ol'
            ? block
            : (attrs['list'] as String?);

        if (rawList == 'ul' ||
            rawList == 'ol' ||
            rawList == 'bullet' ||
            rawList == 'ordered') {
          final group = (rawList == 'ol' || rawList == 'ordered') ? 'ol' : 'ul';
          if (listTag != group) {
            flushList();
            listTag = group;
            listAlign = blockAlign;
          }
          if (inline.isNotEmpty) {
            listItems.add(inline.toString());
            inline.clear();
          }
          continue;
        }

        flushList();
        final rawHeader = attrs['header'];
        if (block == 'blockquote' || attrs['blockquote'] == true) {
          blockTag = 'blockquote';
        } else if (rawHeader is int) {
          blockTag = 'h$rawHeader';
        } else if (block != null && block.startsWith('header.')) {
          blockTag = 'h${block.split('.').last}';
        } else if (block == 'code-block' || attrs['code-block'] == true) {
          blockTag = 'pre';
        } else {
          blockTag = null;
        }

        if (inline.isNotEmpty ||
            blockTag == 'blockquote' ||
            (blockTag != null && blockTag.startsWith('h'))) {
          final tag = blockTag ?? 'p';
          out.write('<$tag${blockStyle()}>$inline</$tag>');
          inline.clear();
        }
        blockTag = null;
        blockAlign = null;
        blockLineHeight = null;
        continue;
      }

      String escAttr(String s) => s
          .replaceAll('&', '&amp;')
          .replaceAll('"', '&quot;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      if (data is Map) {
        if (data.containsKey('image')) {
          final imgSrc = data['image']?.toString() ?? '';
          if (imgSrc.isNotEmpty) {
            final safeSrc = escAttr(imgSrc);
            final style = inlineStyle(attrs);
            final width = attrs['width']?.toString();
            final widthAttr = (width != null && width.isNotEmpty)
                ? ' width="${escAttr(width)}"'
                : '';
            final styleAttr = style.isNotEmpty
                ? ' style="${escAttr(style)}"'
                : ' style="max-width: 100%; height: auto; border-radius: 8px; margin: 4px 0;"';
            inline.write('<img src="$safeSrc"$widthAttr$styleAttr />');
          }
          continue;
        }

        if (data.containsKey('video')) {
          final videoUrl = data['video']?.toString() ?? '';
          if (videoUrl.isNotEmpty) {
            final safeUrl = escAttr(videoUrl);
            inline.write(
              '<div class="video-embed" data-video="$safeUrl" data-embed="$safeUrl">'
              '<a href="$safeUrl" target="_blank" rel="noopener noreferrer">&#9654; Video: $safeUrl</a>'
              '</div>',
            );
          }
          continue;
        }

        if (data.containsKey('audio')) {
          final audioUrl = data['audio']?.toString() ?? '';
          if (audioUrl.isNotEmpty) {
            final safeUrl = escAttr(audioUrl);
            inline.write(
              '<audio controls src="$safeUrl" style="width:100%;margin:8px 0;border-radius:8px;"></audio>',
            );
          }
          continue;
        }

        if (data.containsKey('formula')) {
          final formula = data['formula']?.toString() ?? '';
          if (formula.isNotEmpty) {
            final safeFormula = escAttr(formula);
            inline.write('<span class="ql-formula" data-value="$safeFormula">$safeFormula</span>');
          }
          continue;
        }
      }

      var text = _escape(data.toString());
      if (attrs['script'] == 'sub') {
        text = '<sub>$text</sub>';
      } else if (attrs['script'] == 'super') {
        text = '<sup>$text</sup>';
      }

      final link = attrs['link'] as String?;
      final style = inlineStyle(attrs);

      // List-item markers (e.g. "1." from ordered lists) come through as
      // attributes with no useful styling for raw HTML — ignore them.
      if (attrs.containsKey('list')) continue;

      if (link != null) {
        final safeLink = escAttr(link);
        // Blokir javascript: / data: URL untuk cegah XSS
        final lower = safeLink.toLowerCase().trim();
        if (lower.startsWith('javascript:') || lower.startsWith('data:')) {
          inline.write(text);
        } else {
          inline.write('<a href="$safeLink">$text</a>');
        }
      } else if (style.isNotEmpty) {
        final safeStyle = escAttr(style);
        inline.write('<span style="$safeStyle">$text</span>');
      } else {
        inline.write(text);
      }
    }

    flushList();
    if (inline.isNotEmpty) {
      if (blockTag == null) {
        out.write('<p${blockStyle()}>$inline</p>');
      } else {
        out.write('<$blockTag${blockStyle()}>$inline</$blockTag>');
      }
      inline.clear();
    }
    final result = out.toString();
    return result.isEmpty ? '<p><br></p>' : result;
  }

  /// Map a Quill font [size] attribute to a CSS `font-size` value that the
  /// reverse HTML parser understands (so it round-trips back to `size`).
  ///
  /// Uses explicit `px` (not `em`) so every renderer (flutter_html, browser,
  /// Quill editor) sizes text consistently without `em` double-scaling.
  static String? _quillSizeToPx(dynamic size) {
    if (size == null) return null;
    final s = size.toString();
    switch (s) {
      case 'small':
        return '12px';
      case 'large':
        return '18px';
      case 'huge':
        return '24px';
      case 'normal':
        return null;
      default:
        final n = double.tryParse(s);
        return n == null ? null : '${n}px';
    }
  }

  /// Normalizes a CSS hex color for rendering.
  ///
  /// flutter_quill stores colors as **8-digit ARGB** (`#AARRGGBB`). Browsers
  /// parse 8-digit hex as CSS Color 4 (`#RRGGBBAA`) and Flutter's flutter_html
  /// drops it entirely, so a picked color can render wrong (or pink). When the
  /// alpha is `ff` (the only case the color picker produces) we emit the
  /// equivalent 6-digit `#RRGGBB`; otherwise fall back to `rgba(...)` which
  /// both renderers understand.
  static String normalizeHexColor(String? hex) {
    if (hex == null) return '';
    var h = hex.trim();
    if (!h.startsWith('#')) return h;
    final digits = h.substring(1);
    if (digits.length == 8) {
      final a = digits.substring(0, 2);
      final r = digits.substring(2, 4);
      final g = digits.substring(4, 6);
      final b = digits.substring(6, 8);
      if (a.toLowerCase() == 'ff') {
        return '#$r$g$b'.toUpperCase();
      }
      final alpha = (int.parse(a, radix: 16) / 255).toStringAsFixed(3);
      return 'rgba(${int.parse(r, radix: 16)}, ${int.parse(g, radix: 16)}, '
          '${int.parse(b, radix: 16)}, $alpha)';
    }
    return h;
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  /// Strip HTML tags untuk field yang harus plain text (mis. title template).
  /// "<p>hhhh\n</p>" -> "hhhh"
  static String htmlToPlainText(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    // Gunakan documentToPlain via delta parsing agar lebih akurat
    try {
      final doc = documentFromHtml(html);
      final plain = doc.toPlainText().trim();
      // toPlainText biasanya ada trailing \n
      return plain.replaceAll(RegExp(r'\n+'), ' ').trim();
    } catch (_) {
      // fallback regex strip
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// Normalizes every 8-digit `#AARRGGBB` color inside an HTML string to
  /// 6-digit `#RRGGBB` / `rgba(...)` so old data (written before the writer
  /// fix) renders correctly in browsers and flutter_html.
  static String normalizeHtmlColors(String html) {
    return html.replaceAllMapped(
      RegExp(r'#([0-9A-Fa-f]{8})\b'),
      (m) => normalizeHexColor('#${m[1]}'),
    );
  }

  /// Alias untuk kasus title — jaga agar tidak kosong
  static String titleToPlain(
    String? html, {
    String fallback = 'Form Tanpa Judul',
  }) {
    final plain = htmlToPlainText(html);
    return plain.isEmpty ? fallback : plain;
  }

  /// Resolves relative image URLs (e.g. `/static/uploads/...`) into absolute
  /// URLs pointing to the backend, preserving absolute and data URLs.
  static String resolveImageUrl(String? url) {
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

  /// Normalizes an HTML string for display in Flutter:
  /// 1. Converts 8-digit ARGB colors to 6-digit hex
  /// 2. Resolves relative image sources (`src="/static/..."`) to backend URLs
  static String normalizeHtmlForDisplay(String? html) {
    if (html == null || html.trim().isEmpty) return '';
    var result = normalizeHtmlColors(html);
    result = result.replaceAllMapped(
      RegExp(r'''<img\s+([^>]*?)src=["'](/[^"']+)["']''', caseSensitive: false),
      (m) {
        final prefix = m[1] ?? '';
        final path = m[2] ?? '';
        final resolved = resolveImageUrl(path);
        return '<img ${prefix}src="$resolved"';
      },
    );
    return result;
  }
}
