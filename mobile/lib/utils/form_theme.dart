// Tema aksen fill page per-form: {"accent": "#0053db"}.
// Cermin web utils/formTheme.js: preset sama, validasi sama, null = default.
// Satu-satunya sumber kebenaran daftar preset + normalisasi di mobile.

/// Aksen default bila theme null (sama seperti web DEFAULT_ACCENT).
const String kFormDefaultAccent = '#0053db';

/// Preset web THEME_PRESETS (nama + hex, urutan sama).
const List<({String name, String accent})> kFormThemePresets = [
  (name: 'Biru Default', accent: '#0053db'),
  (name: 'Emerald', accent: '#059669'),
  (name: 'Violet', accent: '#7c3aed'),
  (name: 'Amber', accent: '#d97706'),
  (name: 'Rose', accent: '#e11d48'),
  (name: 'Cyan', accent: '#0891b2'),
];

final RegExp _hexRe = RegExp(r'^#[0-9a-fA-F]{6}$');

bool isValidFormAccent(String? v) =>
    v is String && _hexRe.hasMatch(v);

/// Kembalikan accent tervalidasi (lowercase) atau null (= default).
/// Menerima String hex langsung atau Map {"accent": ...} dari backend.
String? normalizeFormAccent(dynamic theme) {
  String? raw;
  if (theme is String) {
    raw = theme;
  } else if (theme is Map) {
    raw = theme['accent']?.toString();
  } else {
    return null;
  }
  if (!isValidFormAccent(raw)) return null;
  return raw!.toLowerCase();
}

/// Aksen efektif untuk logika/UI yang butuh nilai konkret.
String formAccentOrDefault(dynamic theme) =>
    normalizeFormAccent(theme) ?? kFormDefaultAccent;
