import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/utils/quill_html.dart';

void main() {
  test('HtmlToDelta parses common formatting', () {
    const html = '<p>Hello <strong>bold</strong> and <em>italic</em></p>'
        '<ul><li>one</li><li>two</li></ul>'
        '<h1>Title</h1>';
    final converter = HtmlToDelta();
    final delta = converter.convert(html);
    final doc = Document.fromJson(delta.toJson());
    expect(doc.toPlainText(), contains('Hello'));
    expect(doc.toPlainText(), contains('bold'));
    expect(doc.toPlainText(), contains('Title'));
  });

  test('QuillHtml.documentFromHtml round-trips with web html', () {
    const html = '<p>Hi <strong>there</strong></p>';
    final doc = QuillHtml.documentFromHtml(html);
    expect(doc.toPlainText(), contains('there'));
  });

  test('QuillHtml.documentToHtml produces html', () {
    // Build a delta with a bold span directly (Document.insert requires a
    // positional index, so we compose the delta via JSON instead).
    final deltaJson = [
      {'insert': 'Hello '},
      {'insert': 'world', 'attributes': {'bold': true}},
      {'insert': '\n'},
    ];
    final doc = Document.fromJson(deltaJson);
    final html = QuillHtml.documentToHtml(doc);
    expect(html, contains('Hello'));
    expect(html, contains('world'));
    expect(html.toLowerCase(), contains('bold'));
  });

  Set<dynamic> attrKeys(dynamic rt) {
    return rt
        .where((op) => op['insert'] is String && op['attributes'] is Map)
        .expand((op) => (op['attributes'] as Map).keys)
        .toSet();
  }

  test('all text-editor formatting survives the full HTML round-trip', () {
    // A single paragraph formatted with every inline attribute supported by
    // the text editor, plus block-level center alignment on its newline.
    final deltaJson = [
      {
        'insert': 'Hello ',
        'attributes': {
          'bold': true,
          'italic': true,
          'underline': true,
          'strike': true,
          'color': '#ff0000',
          'background': '#ffff00',
          'size': 'large',
          'font': 'Arial',
          'line-height': 1.5,
        }
      },
      {'insert': 'world'},
      {'insert': '\n', 'attributes': {'align': 'center'}},
    ];
    final html = QuillHtml.documentToHtml(Document.fromJson(deltaJson));
    // Ukuran ditulis sebagai px agar konsisten lintas renderer (bukan em).
    expect(html, contains('font-size: 18px'));
    // Warna tetap 6-digit #rrggbb.
    expect(html, contains('color: #ff0000'));
    expect(html, contains('background-color: #ffff00'));
    // Restore the HTML into a fresh Quill document, exactly like the editor
    // does when a saved form/template is reopened.
    final restored = QuillHtml.documentFromHtml(html).toDelta().toJson();
    final attrs = attrKeys(restored);

    for (final key in [
      'bold', 'italic', 'underline', 'strike', 'color', 'background',
      'size', 'font', 'line-height', 'align',
    ]) {
      expect(attrs.contains(key), isTrue, reason: 'missing $key in $restored');
    }
    // The report example: bold, italic, red, centered, larger font size.
    expect(restored.join(), contains('bold'));
    expect(restored.join(), contains('italic'));
    expect(restored.join(), contains('#ff0000'));
    expect(restored.join(), contains('align'));
    // Ukuran 'large' round-trip balik sebagai 18 (px).
    expect(restored.join(), contains('18'));
  });

  test('warna 8-digit ARGB (format lama flutter_quill) dinormalisasi ke 6-digit', () {
    expect(QuillHtml.normalizeHexColor('#FFFFEB3B'), '#FFEB3B');
    expect(QuillHtml.normalizeHexColor('#FF558B2F'), '#558B2F');
    expect(QuillHtml.normalizeHexColor('#ff0000'), '#ff0000');
    expect(
      QuillHtml.normalizeHtmlColors(
              '<p><span style="color: #FF558B2F; font-size: 0.75em;">x</span></p>')
          .toLowerCase(),
      contains('#558b2f'),
    );
    expect(QuillHtml.normalizeHtmlColors('a #FF558B2F b').toLowerCase(),
        contains('#558b2f'));
  });

  test('ukuran lama 0.75em/1.5em/2.5em masih terbaca sebagai small/large/huge', () {
    final html = QuillHtml.documentToHtml(Document.fromJson([
      {'insert': 'x', 'attributes': {'size': 'small'}},
      {'insert': '\n'},
    ]));
    expect(html, contains('font-size: 12px'));
    final restored = QuillHtml.documentFromHtml('<p style="font-size: 0.75em;">x</p>')
        .toDelta()
        .toJson()
        .join();
    expect(restored, contains('small'));
  });

  test('headers, alignment and bullet lists round-trip', () {
    final deltaJson = [
      {'insert': 'Heading'},
      {'insert': '\n', 'attributes': {'header': 1, 'align': 'center'}},
      {'insert': 'one'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
      {'insert': 'two'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
    ];
    final html = QuillHtml.documentToHtml(Document.fromJson(deltaJson));
    expect(html, contains('<h1 style="text-align: center;">'));
    expect(html, contains('<ul>'));
    expect(html, contains('<li>one</li>'));

    final restored = QuillHtml.documentFromHtml(html).toDelta().toJson();
    expect(attrKeys(restored).contains('header'), isTrue);
    expect(attrKeys(restored).contains('align'), isTrue);
    expect(attrKeys(restored).contains('list'), isTrue);
  });
}
