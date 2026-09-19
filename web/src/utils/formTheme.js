// Tema fill page per-form: {"accent": "#0053db"}.
// Satu warna aksen → varian dark/soft diturunkan otomatis.

export const DEFAULT_ACCENT = '#0053db';

export const THEME_PRESETS = [
  { name: 'Biru Default', accent: '#0053db' },
  { name: 'Emerald', accent: '#059669' },
  { name: 'Violet', accent: '#7c3aed' },
  { name: 'Amber', accent: '#d97706' },
  { name: 'Rose', accent: '#e11d48' },
  { name: 'Cyan', accent: '#0891b2' },
];

const HEX_RE = /^#[0-9a-fA-F]{6}$/;

export function isValidHex(v) {
  return typeof v === 'string' && HEX_RE.test(v);
}

// Kembalikan { accent } yang sudah divalidasi, atau null (= pakai default).
export function normalizeTheme(theme) {
  const accent = theme?.accent;
  if (!isValidHex(accent)) return null;
  return { accent: accent.toLowerCase() };
}

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function mix(hex, target, weight) {
  const [r, g, b] = hexToRgb(hex);
  const m = (c, t) => Math.round(c + (t - c) * weight);
  return `#${((1 << 24) + (m(r, target[0]) << 16) + (m(g, target[1]) << 8) + m(b, target[2])).toString(16).slice(1)}`;
}

// Object style React → CSS vars --accent* (kosong bila tema default).
// Nama var mengikuti konvensi yang sudah dipakai form-fill.css.
export function themeStyle(theme) {
  const t = normalizeTheme(theme);
  if (!t) return {};
  return {
    '--accent': t.accent,
    '--accent-dark': mix(t.accent, [0, 0, 0], 0.18),
    '--accent-soft': mix(t.accent, [255, 255, 255], 0.88),
    '--accent-border': mix(t.accent, [255, 255, 255], 0.72),
    '--accent-ring': mix(t.accent, [255, 255, 255], 0.8),
  };
}

// Aksen efektif (untuk alt text / logic yang butuh nilai konkret).
export function themeAccent(theme) {
  return normalizeTheme(theme)?.accent || DEFAULT_ACCENT;
}
