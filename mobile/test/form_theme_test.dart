import 'package:flutter_test/flutter_test.dart';

import 'package:form4x/utils/form_theme.dart';

/// Paritas web utils/formTheme.js: preset, validasi, normalisasi.
void main() {
  group('form_theme (parity web)', () {
    test('preset sama dengan web (6 warna, urutan sama)', () {
      expect(kFormThemePresets.map((p) => p.accent).toList(), [
        '#0053db',
        '#059669',
        '#7c3aed',
        '#d97706',
        '#e11d48',
        '#0891b2',
      ]);
      expect(kFormDefaultAccent, '#0053db');
    });

    test('validasi hex ketat', () {
      expect(isValidFormAccent('#0053db'), isTrue);
      expect(isValidFormAccent('#0053DB'), isTrue);
      expect(isValidFormAccent('0053db'), isFalse);
      expect(isValidFormAccent('#0053dbff'), isFalse);
      expect(isValidFormAccent('#zzzzzz'), isFalse);
      expect(isValidFormAccent(null), isFalse);
      expect(isValidFormAccent(''), isFalse);
    });

    test('normalize: map backend & string, lowercase, invalid → null', () {
      expect(normalizeFormAccent({'accent': '#059669'}), '#059669');
      expect(normalizeFormAccent({'accent': '#059669'.toUpperCase()}),
          '#059669');
      expect(normalizeFormAccent({'accent': 'biru'}), isNull);
      expect(normalizeFormAccent(null), isNull);
      expect(normalizeFormAccent('#7C3AED'), '#7c3aed');
    });

    test('aksen efektif fallback ke default', () {
      expect(formAccentOrDefault(null), '#0053db');
      expect(formAccentOrDefault({'accent': '#e11d48'}), '#e11d48');
      expect(formAccentOrDefault({'accent': 'rusak'}), '#0053db');
    });
  });
}
