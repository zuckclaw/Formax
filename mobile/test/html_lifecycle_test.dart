import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/utils/quill_html.dart';
import 'package:form4x/widgets/rich_text_view.dart';

/// Regresi bug "HTML hilang setelah Save → Publish → Open":
/// ROOT CAUSE (sudah diperbaiki di QuillHtml):
///  1. Embed asli editor (formula/displayMath/video/audio, bentuk
///     {'custom': '{"type":"data"}'}) terserial sebagai teks mentah
///     "{custom: ...}" ke database → musnah dari form publish.
///  2. Op teks multi-baris tak dipecah → format blok (h1/h3/list)
///     menelan baris tetangga setiap kali disimpan.
///  3. Reader (HtmlToDelta) membuang div.video-embed + menghancurkan
///     <audio> → video/audio hilang tiap buka-simpan di mobile.
///
/// Lifecycle yang diuji: create → save → reload → edit → save →
/// publish → open → render (tanpa backend, level unit + widget).
void main() {
  // HTML acceptance criteria dari laporan bug.
  const acceptanceSimple = [
    '<b>Bold Text</b>',
    '<i>Italic Text</i>',
    '<u>Underline Text</u>',
    '<p>Paragraph</p>',
    '<h1>Heading</h1>',
    '<br>',
    '<ul><li>Item 1</li><li>Item 2</li></ul>',
    'Nama Peserta: <b>John Doe</b>',
    '<h3>Data Diri</h3>',
  ];

  String plainOf(String html) => RichTextView.stripHtml(html);

  group('lifecycle editor: simpan → muat ulang → simpan lagi', () {
    test('HTML sederhana & kompleks tidak hilang & stabil', () {
      const html =
          '<b>Bold Text</b><p>Paragraph</p><h3>Heading</h3><ul><li>Item 1</li><li>Item 2</li></ul>';
      var current = html;
      for (var i = 0; i < 3; i++) {
        current = QuillHtml.documentToHtml(
          QuillHtml.documentFromHtml(current),
        );
      }
      for (final needle in [
        'Bold Text',
        'Paragraph',
        'Heading',
        'Item 1',
        'Item 2',
      ]) {
        expect(plainOf(current), contains(needle));
      }
      // Struktur blok tidak runtuh menjadi satu heading raksasa.
      expect(current.indexOf('<h3>'), isNonNegative);
      expect(current.indexOf('Paragraph'), lessThan(current.indexOf('<h3>')));
    });

    test('set acceptance tetap ada setelah 2 siklus', () {
      for (final html in acceptanceSimple) {
        var current = html;
        for (var i = 0; i < 2; i++) {
          current = QuillHtml.documentToHtml(
            QuillHtml.documentFromHtml(current),
          );
        }
        final want = plainOf(html);
        if (want.isEmpty) continue; // <br> saja
        for (final word in want.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          expect(plainOf(current), contains(word), reason: html);
        }
      }
    });

    test('video & audio web selamat dari buka-simpan', () {
      const html =
          '<div class="video-embed" data-video="https://youtu.be/abc" data-embed="https://youtu.be/abc"><a href="https://youtu.be/abc">Video</a></div>'
          '<p><audio controls src="https://x.test/a.mp3"></audio></p>';
      final out = QuillHtml.documentToHtml(QuillHtml.documentFromHtml(html));
      expect(out, contains('data-video="https://youtu.be/abc"'));
      expect(out, contains('<audio'));
      expect(out, contains('https://x.test/a.mp3'));
      expect(out.contains('{custom:'), isFalse);
    });

    test('rumus web selamat dari buka-simpan', () {
      const html =
          '<p>Hitung <span class="ql-formula" data-value="\\frac{a}{b}"></span> berikut.</p>'
          '<div class="math-display-block" data-latex="x^2"><span class="katex">X</span></div>';
      final out = QuillHtml.documentToHtml(QuillHtml.documentFromHtml(html));
      expect(out, contains('data-value="\\frac{a}{b}"'));
      expect(out, contains('data-latex="x^2"'));
    });
  });

  group('emit dari delta asli editor (custom embeds)', () {
    Future<String> emitWith(void Function(QuillController) build) async {
      final c = QuillController.basic();
      build(c);
      final html = QuillHtml.documentToHtml(c.document);
      c.dispose();
      return html;
    }

    test('formula inline tidak jadi teks {custom: ...}', () async {
      final html = await emitWith((c) {
        c.replaceText(0, 0, 'Hitung ', null);
        c.replaceText(7, 0,
            BlockEmbed.custom(CustomBlockEmbed('formula', r'\frac{a}{b}')),
            null);
        c.replaceText(8, 0, '\n', null);
      });
      expect(html, contains('data-value="\\frac{a}{b}"'));
      expect(html.contains('{custom:'), isFalse);
    });

    test('display math / video / audio terserial benar', () async {
      final html = await emitWith((c) {
        c.replaceText(
            0,
            0,
            BlockEmbed.custom(CustomBlockEmbed('displayMath', 'x^2')),
            null);
        c.replaceText(1, 0, '\n', null);
        c.replaceText(
            2,
            0,
            BlockEmbed.custom(
                CustomBlockEmbed('video', 'https://youtu.be/abc')),
            null);
        c.replaceText(3, 0, '\n', null);
        c.replaceText(
            4,
            0,
            BlockEmbed.custom(
                CustomBlockEmbed('audio', 'https://x.test/a.mp3')),
            null);
        c.replaceText(5, 0, '\n', null);
      });
      expect(html, contains('data-latex="x^2"'));
      expect(html, contains('data-video="https://youtu.be/abc"'));
      expect(html, contains('<audio'));
      expect(html.contains('{custom:'), isFalse);
    });
  });

  group('render fill menampilkan HTML publish', () {
    testWidgets('semua teks acceptance tampil', (tester) async {
      const html =
          '<b>Nama Peserta</b><p>Silakan isi data berikut:</p><h3>Data Diri</h3>'
          '<ul><li>Item 1</li><li>Item 2</li></ul>';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RichTextView(html: html))),
      );
      await tester.pumpAndSettle();
      for (final t in [
        'Nama Peserta',
        'Silakan isi data berikut:',
        'Data Diri',
        'Item 1',
        'Item 2',
      ]) {
        expect(find.textContaining(t, findRichText: true), findsWidgets,
            reason: t);
      }
    });

    testWidgets('hasil save mobile tetap tampil di fill', (tester) async {
      const created =
          '<b>Bold Text</b><p>Paragraph</p><h3>Heading</h3><ul><li>Item 1</li><li>Item 2</li></ul>';
      // Simulasi: simpan dari mobile → publish → buka (DB menyimpan string).
      final published =
          QuillHtml.documentToHtml(QuillHtml.documentFromHtml(created));
      final displayed =
          QuillHtml.normalizeHtmlForDisplay(published);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RichTextView(html: displayed))),
      );
      await tester.pumpAndSettle();
      for (final t in ['Bold Text', 'Paragraph', 'Heading', 'Item 1']) {
        expect(find.textContaining(t, findRichText: true), findsWidgets,
            reason: t);
      }
    });
  });
}
