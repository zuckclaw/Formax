import 'dart:convert';

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
  ///
  /// Rumus KaTeX web (`<span class="ql-formula" data-value="...">` dan
  /// `<div class="math-display-block" data-latex="...">`) plus media
  /// (`<div class="video-embed" data-video>` dan `<audio src>`)
  /// dipertahankan sebagai embed — TANPA ini HtmlToDelta membuang div
  /// video beserta atributnya, menghancurkan audio menjadi teks sampah,
  /// dan mengosongkan span rumus (HILANG saat dibuka & disimpan di mobile).
  static Document documentFromHtml(String? html) {
    if (html == null || html.trim().isEmpty) return Document();
    try {
      final segments = splitMathSegments(html);
      if (!segments.any((s) => s.isMath || s.isMedia)) {
        final delta = HtmlToDelta().convert(html);
        return Document.fromJson(delta.toJson());
      }
      final ops = <Map<String, dynamic>>[];
      for (final seg in segments) {
        if (seg.isMedia) {
          if (seg.latex.isEmpty) continue;
          ops.add({
            'insert': {seg.mediaType: seg.latex},
          });
          ops.add({'insert': '\n'});
        } else if (seg.isMath) {
          if (seg.latex.isEmpty) continue;
          if (seg.isDisplay) {
            ops.add({
              'insert': {'displayMath': seg.latex},
            });
            ops.add({'insert': '\n'});
          } else {
            ops.add({
              'insert': {'formula': seg.latex},
            });
          }
        } else if (seg.text.isNotEmpty) {
          try {
            final d = HtmlToDelta().convert(seg.text);
            for (final op in d.toJson()) {
              ops.add(Map<String, dynamic>.from(op as Map));
            }
          } catch (_) {
            ops.add({'insert': seg.text});
          }
        }
      }
      // Delta harus diakhiri newline.
      final hasTrailingNewline = ops.isNotEmpty &&
          ops.last['insert'] is String &&
          (ops.last['insert'] as String).endsWith('\n');
      if (!hasTrailingNewline) ops.add({'insert': '\n'});
      return Document.fromJson(ops);
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
    //
    // NORMALISASI NEWLINE (fix blok bocor antar baris): op teks yang
    // mengandung '\n' dipecah menjadi unit teks/newline agar format blok
    // (h1/h3/list/blockquote) tidak menelan baris tetangga. Tanpa ini
    // "<b>A</b><p>B</p><h3>C</h3>" tersimpan sebagai satu <h3> raksasa
    // dan struktur form rusak setiap kali disimpan dari mobile.
    final units = <Map<String, dynamic>>[];
    // ignore: avoid_dynamic_calls
    for (final rawOp in delta.toJson()) {
      if (rawOp is! Map) continue;
      final op = Map<String, dynamic>.from(rawOp);
      final data = op['insert'];
      if (data == null) continue;
      final attrs = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};
      if (data is String && data != '\n' && data.contains('\n')) {
        final parts = data.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            units.add({
              'insert': parts[i],
              if (attrs.isNotEmpty) 'attributes': Map.of(attrs),
            });
          }
          if (i < parts.length - 1) {
            units.add({
              'insert': '\n',
              if (attrs.isNotEmpty) 'attributes': Map.of(attrs),
            });
          }
        }
        continue;
      }
      units.add(op);
    }
    for (final op in units) {
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
        // Embed asli editor (formula/displayMath/video/audio) disimpan
        // sebagai {'custom': '{"type":"data"}'}. Decode DULU — tanpa ini
        // rumus/video/audio terserial sebagai teks mentah "{custom: ...}"
        // ke database dan musnah dari form publish (ROOT CAUSE utama).
        var embed = Map<String, dynamic>.from(data);
        if (embed.length == 1 && embed.containsKey('custom')) {
          final decoded =
              _decodeCustomEmbed(embed['custom']?.toString() ?? '');
          if (decoded != null) {
            embed = decoded;
          } else {
            // Tak bisa di-decode: tampilkan mentah ter-escape
            // (fail-visible, jangan crash, jangan buang diam-diam).
            inline.write(_escape(embed['custom'].toString()));
            continue;
          }
        }
        if (embed.containsKey('image')) {
          final imgSrc = embed['image']?.toString() ?? '';
          if (imgSrc.isNotEmpty) {
            final safeSrc = escAttr(imgSrc);
            final style = inlineStyle(attrs);
            final width = attrs['width']?.toString();
            final widthAttr = (width != null && width.isNotEmpty)
                ? ' width="${escAttr(width)}"'
                : '';
            // Lebar ikut ditulis ke style (format web quill-image-resize)
            // agar pulang-pergi via HtmlToDelta tidak hilang.
            var styleVal = style;
            if (width != null && width.isNotEmpty) {
              styleVal = '${styleVal}width: $width;'.trim();
            }
            final styleAttr = styleVal.isNotEmpty
                ? ' style="${escAttr(styleVal)}"'
                : ' style="max-width: 100%; height: auto; border-radius: 8px; margin: 4px 0;"';
            inline.write('<img src="$safeSrc"$widthAttr$styleAttr />');
          }
          continue;
        }

        if (embed.containsKey('video')) {
          final videoUrl = embed['video']?.toString() ?? '';
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

        if (embed.containsKey('audio')) {
          final audioUrl = embed['audio']?.toString() ?? '';
          if (audioUrl.isNotEmpty) {
            final safeUrl = escAttr(audioUrl);
            inline.write(
              '<audio controls src="$safeUrl" style="width:100%;margin:8px 0;border-radius:8px;"></audio>',
            );
          }
          continue;
        }

        if (embed.containsKey('formula')) {
          final formula = embed['formula']?.toString() ?? '';
          if (formula.isNotEmpty) {
            final safeFormula = escAttr(formula);
            final isDisplay = attrs['display'] == true || attrs['block'] == 'displayMath';
            if (isDisplay) {
              inline.write('<div class="math-display-block" data-latex="$safeFormula">$safeFormula</div>');
            } else {
              inline.write('<span class="ql-formula" data-value="$safeFormula">$safeFormula</span>');
            }
          }
          continue;
        }

        if (embed.containsKey('displayMath')) {
          final formula = embed['displayMath']?.toString() ?? '';
          if (formula.isNotEmpty) {
            final safeFormula = escAttr(formula);
            inline.write('<div class="math-display-block" data-latex="$safeFormula">$safeFormula</div>');
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

  /// Decode embed kustom editor '{"type":"data"}' menjadi {type: data}.
  /// Return null bila bukan JSON embed valid.
  static Map<String, dynamic>? _decodeCustomEmbed(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map || parsed.length != 1) return null;
      final type = parsed.keys.first.toString();
      final data = parsed.values.first;
      if (type.isEmpty || data == null) return null;
      return {type: data is String ? data : data.toString()};
    } catch (_) {
      return null;
    }
  }

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
  /// 3. Normalizes video-embed divs to dedicated `<video-embed>` tags for flutter_html
  /// 4. Normalizes rumus web (ql-formula / math-display-block, termasuk isi
  ///    render KaTeX bersarang) menjadi tag bersih `<ql-formula>` /
  ///    `<math-display>` agar TIDAK hilang/berantakan di flutter_html
  /// 5. Memperkaya delimiter LaTeX mentah `\(...\)` / `\[...\]` (parity web
  ///    mathRender.js) menjadi tag rumus agar ikut ter-render sebagai KaTeX
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
    result = result.replaceAllMapped(
      RegExp(
        r'''<div\s+([^>]*?class=["'][^"']*video-embed[^"']*["'][^>]*)>(.*?)</div>''',
        caseSensitive: false,
        dotAll: true,
      ),
      (m) => '<video-embed ${m[1]}>${m[2]}</video-embed>',
    );
    result = normalizeMathTags(result);
    result = enrichMathDelimiters(result);
    return result;
  }

  // ── Custom-block segment splitter (balanced-tag) ─────────────────────
  // Menangani: span.ql-formula, div.math-display-block (KaTeX),
  // div.video-embed (video), dan <audio> — semuanya tahan inner HTML
  // bersarang. TANPA ini HtmlToDelta membuang div.video-embed beserta
  // atributnya dan menghancurkan <audio> menjadi teks link sampah,
  // sehingga video/audio MUSNAH setiap form dibuka & disimpan di mobile.

  /// Satu potongan hasil [splitMathSegments]: teks biasa, rumus web, atau
  /// media (video/audio). [isDisplay]=true → math-display-block (blok).
  static List<MathSegment> splitMathSegments(String html) {
    final out = <MathSegment>[];
    final openTag =
        RegExp(r'<(span|div|audio)\b[^>]*>', caseSensitive: false);
    var cursor = 0;
    for (final m in openTag.allMatches(html)) {
      final tag = m.group(0)!;
      final tagName = m.group(1)!.toLowerCase();
      final lower = tag.toLowerCase();
      final isFormulaSpan =
          tagName == 'span' && lower.contains('ql-formula');
      final isDisplayDiv =
          tagName == 'div' && lower.contains('math-display-block');
      final isVideoDiv =
          tagName == 'div' && lower.contains('video-embed');
      final isAudio = tagName == 'audio';
      if (!isFormulaSpan && !isDisplayDiv && !isVideoDiv && !isAudio) {
        continue;
      }
      String? rawValue;
      var isDisplay = false;
      var mediaType = '';
      if (isFormulaSpan) {
        rawValue = _attrValue(tag, 'data-value');
      } else if (isDisplayDiv) {
        rawValue = _attrValue(tag, 'data-latex');
        isDisplay = true;
      } else if (isVideoDiv) {
        rawValue =
            _attrValue(tag, 'data-video') ?? _attrValue(tag, 'data-embed');
        mediaType = 'video';
      } else {
        rawValue = _attrValue(tag, 'src') ??
            _attrValue(tag, 'data-original-src');
        mediaType = 'audio';
      }
      if (rawValue == null) continue;
      // Tag self-closing (<audio ... />) langsung jadi segmen utuh.
      final selfClosed = tag.trimRight().endsWith('/>');
      int segEnd;
      if (selfClosed) {
        segEnd = m.end;
      } else {
        final closeStart = _findMatchingClose(html, m.end, tagName);
        if (closeStart < 0) continue;
        final closeTag = RegExp('</$tagName\\s*>', caseSensitive: false)
            .matchAsPrefix(html, closeStart);
        if (closeTag == null) continue;
        segEnd = closeTag.end;
      }
      if (m.start > cursor) {
        out.add(MathSegment.text(html.substring(cursor, m.start)));
      }
      if (mediaType.isNotEmpty) {
        final url = unescapeAttr(rawValue).trim();
        if (url.isNotEmpty) out.add(MathSegment.media(mediaType, url));
      } else {
        out.add(MathSegment.math(
          unescapeAttr(rawValue),
          isDisplay: isDisplay,
        ));
      }
      cursor = segEnd;
    }
    if (cursor == 0) return [MathSegment.text(html)];
    if (cursor < html.length) out.add(MathSegment.text(html.substring(cursor)));
    return out;
  }

  /// Ubah tag rumus web menjadi tag bersih untuk flutter_html.
  /// Segmen media ditulis ulang sebagai tag bersih (bukan dibuang).
  static String normalizeMathTags(String html) {
    final segments = splitMathSegments(html);
    if (!segments.any((s) => s.isMath || s.isMedia)) return html;
    final buf = StringBuffer();
    for (final seg in segments) {
      if (seg.isMedia) {
        if (seg.latex.isEmpty) continue;
        final safe = escapeAttr(seg.latex);
        if (seg.mediaType == 'video') {
          // Langsung tag <video-embed> agar TagExtension fill langsung jalan.
          buf.write('<video-embed data-video="$safe" data-embed="$safe">'
              '<a href="$safe">Video</a></video-embed>');
        } else {
          buf.write(
              '<audio controls src="$safe" style="width:100%;"></audio>');
        }
      } else if (!seg.isMath) {
        buf.write(seg.text);
      } else if (seg.latex.isEmpty) {
        continue; // span/div kosong (data "undefined" warisan) → buang
      } else if (seg.isDisplay) {
        buf.write('<math-display data-latex="${escapeAttr(seg.latex)}"></math-display>');
      } else {
        buf.write('<ql-formula data-value="${escapeAttr(seg.latex)}"></ql-formula>');
      }
    }
    return buf.toString();
  }

  /// Perkaya delimiter LaTeX mentah (parity web mathRender.js):
  /// `\(...\)` → inline, `\[...\]` → display. Hanya di chunk teks
  /// (bukan di dalam tag / <pre> / <code>). Rumus multi-baris
  /// (`\\` / `\begin{`) di dalam `\(...\)` dipromosikan jadi display.
  static String enrichMathDelimiters(String html) {
    if (!html.contains(r'\')) return html;
    // Catatan Dart: String.split MEMBUANG separator (tidak seperti JS),
    // jadi jalan manual lewat allMatches agar tag ikut tersalin verbatim.
    final tagRe = RegExp(r'<[^>]+>');
    final buf = StringBuffer();
    var last = 0;
    var insidePre = 0;
    var insideCode = 0;
    var changed = false;

    void pushChunk(String chunk) {
      if (chunk.isEmpty) return;
      if (insidePre > 0 || insideCode > 0) {
        buf.write(chunk);
        return;
      }
      final enriched = _enrichTextDelimiters(chunk);
      if (enriched != null) {
        buf.write(enriched);
        changed = true;
      } else {
        buf.write(chunk);
      }
    }

    for (final m in tagRe.allMatches(html)) {
      if (m.start > last) pushChunk(html.substring(last, m.start));
      final tag = m.group(0)!;
      buf.write(tag); // tag selalu disalin apa adanya
      final lower = tag.toLowerCase();
      if (RegExp(r'^<pre(\s|>)').hasMatch(lower)) {
        insidePre++;
      } else if (RegExp(r'^</pre\s*>').hasMatch(lower)) {
        insidePre = insidePre > 0 ? insidePre - 1 : 0;
      } else if (RegExp(r'^<code(\s|>)').hasMatch(lower)) {
        insideCode++;
      } else if (RegExp(r'^</code\s*>').hasMatch(lower)) {
        insideCode = insideCode > 0 ? insideCode - 1 : 0;
      }
      last = m.end;
    }
    if (last < html.length) pushChunk(html.substring(last));
    return changed ? buf.toString() : html;
  }

  /// Bungkus delimiter dalam satu chunk teks. Return null bila tidak ada.
  static String? _enrichTextDelimiters(String text) {
    // Normalisasi delimiter ganda \\( → \( (parity web), hati-hati agar
    // \\frac yang valid tidak tersentuh: hanya sebelum ( ) [ ].
    var src = text.replaceAllMapped(
      RegExp(r'\\\\([()\[\]])'),
      (m) => '\\${m.group(1)}',
    );
    if (!src.contains(r'\(') && !src.contains(r'\[')) return null;
    final out = StringBuffer();
    var last = 0;
    var found = false;

    void pushDisplay(String latex) {
      out.write('<math-display data-latex="${escapeAttr(latex)}"></math-display>');
      found = true;
    }

    void pushInline(String latex) {
      out.write('<ql-formula data-value="${escapeAttr(latex)}"></ql-formula>');
      found = true;
    }

    // Kumpulkan span display dulu untuk mengecualikan inline di dalamnya.
    final displayRe = RegExp(r'\\\[([\s\S]+?)\\\]');
    final displaySpans = <List<int>>[];
    for (final m in displayRe.allMatches(src)) {
      final inner = _cleanMathText(m.group(1) ?? '');
      if (inner.isEmpty) continue;
      displaySpans.add([m.start, m.end]);
    }
    bool insideDisplay(int idx) =>
        displaySpans.any((s) => idx >= s[0] && idx < s[1]);

    // Bangun event terurut posisi (display + inline campur).
    final events = <Map<String, dynamic>>[];
    for (final m in displayRe.allMatches(src)) {
      final inner = _cleanMathText(m.group(1) ?? '');
      if (inner.isEmpty) continue;
      events.add({'s': m.start, 'e': m.end, 'd': true, 't': inner});
    }
    final inlineRe = RegExp(r'\\\((.+?)\\\)');
    for (final m in inlineRe.allMatches(src)) {
      if (insideDisplay(m.start)) continue;
      var inner = _cleanMathText(m.group(1) ?? '');
      if (inner.isEmpty) continue;
      // Multi-baris di dalam \(...\) → jadikan display (parity web).
      final multi = inner.contains(r'\\') || inner.contains(r'\begin{');
      events.add({'s': m.start, 'e': m.end, 'd': multi, 't': inner});
    }
    events.sort((a, b) => (a['s'] as int).compareTo(b['s'] as int));
    for (final e in events) {
      final s = e['s'] as int;
      final en = e['e'] as int;
      if (s > last) out.write(_escape(src.substring(last, s)));
      if (e['d'] as bool) {
        pushDisplay(e['t'] as String);
      } else {
        pushInline(e['t'] as String);
      }
      last = en;
    }
    if (!found) return null;
    if (last < src.length) out.write(_escape(src.substring(last)));
    return out.toString();
  }

  /// Bersihkan <br> / entitas di dalam rumus (parity web cleanMathEntities).
  static String _cleanMathText(String latex) {
    var s = latex.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ');
    s = s.replaceAll(RegExp(r'&amp;', caseSensitive: false), '&');
    s = s.replaceAll(RegExp(r'&lt;', caseSensitive: false), '<');
    s = s.replaceAll(RegExp(r'&gt;', caseSensitive: false), '>');
    s = s.replaceAll(RegExp(r'&quot;', caseSensitive: false), '"');
    return s.trim();
  }

  /// Ambil nilai atribut HTML (mendukung kutip ganda & tunggal).
  static String? _attrValue(String tag, String name) {
    final m = RegExp(
      '$name\\s*=\\s*"([^"]*)"|$name\\s*=\\s*\'([^\']*)\'',
      caseSensitive: false,
    ).firstMatch(tag);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }

  /// Cari index tag tutup yang seimbang untuk [tagName] mulai dari [from].
  /// Menghitung nested `<tagName ...>` / `</tagName>` agar inner HTML KaTeX
  /// (banyak span/div bersarang) tidak memutus segmen terlalu dini.
  static int _findMatchingClose(String html, int from, String tagName) {
    final token = RegExp('</?$tagName\\b[^>]*>', caseSensitive: false);
    var depth = 1;
    for (final m in token.allMatches(html, from)) {
      final t = m.group(0)!;
      if (t.startsWith('</')) {
        depth--;
        if (depth == 0) return m.start;
      } else if (!t.endsWith('/>')) {
        depth++;
      }
    }
    return -1;
  }

  /// Escape teks untuk atribut HTML (kebalikan [unescapeAttr]).
  static String escapeAttr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Kembalikan escape atribut ke latex asli.
  static String unescapeAttr(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// Satu potongan hasil [QuillHtml.splitMathSegments]: teks biasa
/// ([isMath]=false, isi di [text]), rumus web ([isMath]=true,
/// latex di [latex], [isDisplay]=true untuk math-display-block),
/// atau media ([isMedia]=true, [mediaType]='video'/'audio', url di [latex]).
class MathSegment {
  final bool isMath;
  final bool isDisplay;
  final String latex;
  final String text;

  /// Non-kosong ('video'/'audio') bila segmen adalah media.
  final String mediaType;

  bool get isMedia => mediaType.isNotEmpty;

  const MathSegment.text(this.text)
      : isMath = false,
        isDisplay = false,
        latex = '',
        mediaType = '';

  const MathSegment.math(this.latex, {this.isDisplay = false})
      : isMath = true,
        text = '',
        mediaType = '';

  const MathSegment.media(this.mediaType, this.latex)
      : isMath = false,
        isDisplay = false,
        text = '';
}
