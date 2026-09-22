import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/utils/quill_html.dart';
import 'package:form4x/widgets/math_tex.dart';

void main() {
  group('KaTeX web → mobile (tidak hilang)', () {
    test('span ql-formula web dipertahankan sebagai embed formula', () {
      const html =
          '<p>Hitung <span class="ql-formula" data-value="\\frac{a}{b}"><span class="katex">RENDERED</span></span> berikut.</p>';
      final doc = QuillHtml.documentFromHtml(html);
      final ops = doc.toDelta().toJson();
      final hasFormula = ops.whereType<Map>().any((op) {
        final m = Map<String, dynamic>.from(op);
        final ins = m['insert'];
        return ins is Map && ins.containsKey('formula');
      });
      expect(hasFormula, isTrue,
          reason: 'rumus inline web harus jadi embed formula, bukan hilang');
    });

    test('div math-display-block web dipertahankan sebagai displayMath', () {
      const html =
          '<div class="math-display-block" data-latex="\\sum_{i=1}^{n} x_i"><div class="katex-display">RENDERED</div></div>';
      final doc = QuillHtml.documentFromHtml(html);
      final ops = doc.toDelta().toJson();
      final hasDisplay = ops.whereType<Map>().any((op) {
        final m = Map<String, dynamic>.from(op);
        final ins = m['insert'];
        return ins is Map && ins.containsKey('displayMath');
      });
      expect(hasDisplay, isTrue);
    });

    test('round-trip editor → HTML → editor tidak menghilangkan rumus', () {
      const html =
          '<p>Soal <span class="ql-formula" data-value="x^{n}"></span> dan blok:</p>'
          '<div class="math-display-block" data-latex="\\int_{a}^{b} f(x)\\,dx"></div>';
      final doc = QuillHtml.documentFromHtml(html);
      final out = QuillHtml.documentToHtml(doc);
      expect(out, contains('x^{n}'));
      expect(out, contains(r'\int_{a}^{b}'));
    });

    test('normalizeHtmlForDisplay membersihkan inner KaTeX bersarang', () {
      const html =
          '<p>A <span class="ql-formula" data-value="\\alpha"><span class="katex"><span class="katex-mathml">α</span></span></span> B</p>';
      final norm = QuillHtml.normalizeHtmlForDisplay(html);
      expect(norm, contains('data-value="\\alpha"'));
      expect(norm.contains('katex-mathml'), isFalse);
    });
  });

  group('Delimiter LaTeX mentah (parity web mathRender.js)', () {
    test(r'\(...\) menjadi tag rumus inline', () {
      const html = r'<p>Hitung \(\frac{a}{b}\) berikut.</p>';
      final norm = QuillHtml.normalizeHtmlForDisplay(html);
      expect(norm, contains('<ql-formula data-value="\\frac{a}{b}">'));
      expect(norm.contains(r'\('), isFalse);
    });

    test(r'\[...\] menjadi tag rumus display', () {
      const html = r'<p>Hasil: \[x^2 + y^2\]</p>';
      final norm = QuillHtml.normalizeHtmlForDisplay(html);
      expect(norm, contains('<math-display data-latex="x^2 + y^2">'));
    });

    test('isi <pre>/<code> tidak disentuh', () {
      const html = r'<pre>\(jangan sentuh\)</pre>';
      final norm = QuillHtml.normalizeHtmlForDisplay(html);
      expect(norm.contains(r'\('), isTrue);
      expect(norm.contains('ql-formula'), isFalse);
    });
  });

  group('MathTex.looksValid', () {
    test('kurung seimbang valid, tak seimbang tidak', () {
      expect(MathTex.looksValid(r'\frac{a}{b}'), isTrue);
      expect(MathTex.looksValid(r'\frac{a}{b'), isFalse);
      expect(MathTex.looksValid(''), isFalse);
      expect(MathTex.looksValid(r'x\'), isFalse);
    });
  });
}
