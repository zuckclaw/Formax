import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/utils/quill_html.dart';
import 'package:form4x/widgets/rich_text_view.dart';

void main() {
  testWidgets('warna kuning 8-digit (ARGB) dirender kuning setelah normalisasi',
      (tester) async {
    // flutter_quill menyimpan warna sebagai #AARRGGBB (di sini #FFFFEB3B =
    // kuning). Sebelumnya flutter_html membuang warna ini (jadi default) dan
    // browser membacanya sebagai RRGGBBAA (jadi pink/transparan).
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichTextView(
            html: '<p><span style="color: #FFFFEB3B;">Yellow</span></p>',
          ),
        ),
      ),
    );

    Color? leafColor;
    final texts =
        tester.widgetList<Text>(find.textContaining('Yellow')).toList();
    for (final t in texts) {
      void walk(InlineSpan? sp) {
        if (sp == null) return;
        final seg = sp.toPlainText().trim();
        if (seg.isNotEmpty && sp.style?.color != null) {
          leafColor = sp.style!.color;
        }
        if (sp is TextSpan && sp.children != null) {
          sp.children!.forEach(walk);
        }
      }

      walk(t.textSpan);
    }

    expect(leafColor, isNotNull, reason: 'warna tidak diaplikasikan sama sekali');
    // Kuning #FFEB3B = r:255, g:235, b:59
    expect((leafColor!.r * 255).round(), 255);
    expect((leafColor!.g * 255).round(), 235);
    expect((leafColor!.b * 255).round(), 59);
  });

  testWidgets('font-size px teraplikasi pada render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichTextView(
            html: '<p><span style="font-size: 24px;">BigText</span></p>',
          ),
        ),
      ),
    );

    bool sawBig = false;
    final texts = tester.widgetList<Text>(find.textContaining('BigText')).toList();
    for (final t in texts) {
      void walk(InlineSpan? sp) {
        if (sp == null) return;
        final seg = sp.toPlainText().trim();
        if (seg.isNotEmpty && sp.style?.fontSize != null && sp.style!.fontSize! >= 22) {
          sawBig = true;
        }
        if (sp is TextSpan && sp.children != null) {
          sp.children!.forEach(walk);
        }
      }

      walk(t.textSpan);
    }
    expect(sawBig, isTrue, reason: 'font-size px tidak diaplikasikan');
  });

  test('deltaToHtml menormalkan warna 8-digit dan ukuran em lama jadi px', () {
    final html = QuillHtml.documentToHtml(Document.fromJson([
      {
        'insert': 'Teks',
        'attributes': {
          'color': '#FFFFEB3B',
          'background': '#FF00FF00',
          'size': 'large',
        },
      },
      {'insert': '\n'},
    ]));
    expect(html, contains('color: #FFEB3B'));
    expect(html, contains('background-color: #00FF00'));
    expect(html, contains('font-size: 18px'));
  });
}