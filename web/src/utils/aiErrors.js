/**
 * aiErrors — pemetaan error AI Builder menjadi pesan ramah + tombol aksi.
 * Harus selaras dengan tag di backend/app/routers/ai.py
 * ([AI_BUSY], [AI_QUOTA], [AI_BAD_KEY], [AI_BAD_JSON]).
 * TIDAK ada retry otomatis — semua aksi bersifat manual oleh user.
 */

function stripTag(text) {
  return String(text ?? '')
    .replace(/\[(AI_BUSY|AI_QUOTA|AI_BAD_KEY|AI_BAD_JSON)\]\s*/g, '')
    .replace(/^AI (gagal generate|mengembalikan format rusak)[^:]*:\s*/i, '')
    .trim();
}

function shortTail(text, max = 400) {
  const t = stripTag(text);
  // Buang sisa dump teknis "... | ..." agar pesan tetap ringkas.
  const cut = t.split(' | ').filter(Boolean);
  // Ambil kalimat pertama yang bermakna (bukan potongan JSON).
  const pick = cut.find((s) => s.length > 10 && !s.trim().startsWith('{')) || cut[0] || t;
  return pick.length > max ? `${pick.slice(0, max).trim()}…` : pick;
}

/**
 * @param {Error|string} err
 * @param {{ hasOwnKey: boolean }} ctx
 * @returns {{ text: string, hint: string|null, action: 'key'|'retry'|null, actionLabel: string|null }}
 */
export function mapAiError(err, ctx = {}) {
  const raw = typeof err === 'string' ? err : (err?.message || 'Gagal generate form');
  const hasOwnKey = !!ctx.hasOwnKey;

  if (/\[AI_BAD_KEY\]/.test(raw)) {
    return {
      text: 'API key Gemini Anda ditolak Google.',
      hint: 'Periksa kembali key yang ditempel (biasanya diawali AIza). Ambil key baru gratis di Google AI Studio.',
      action: 'key',
      actionLabel: 'Periksa API Key',
    };
  }

  if (/\[AI_QUOTA\]/.test(raw)) {
    return {
      text: 'Kuota AI habis.',
      hint: hasOwnKey
        ? 'Kuota key Anda habis — tunggu reset kuota harian Google atau gunakan key lain.'
        : 'Kuota server habis — tempel API key Gemini gratis milik Anda untuk kuota pribadi, atau tunggu reset.',
      action: hasOwnKey ? null : 'key',
      actionLabel: hasOwnKey ? null : 'Tempel API Key',
    };
  }

  if (/\[AI_BUSY\]/.test(raw) || /high demand|overloaded|UNAVAILABLE/i.test(raw)) {
    return {
      text: 'Server AI Google sedang sibuk (lonjakan sesaat).',
      hint: hasOwnKey
        ? 'Ini masalah sisi Google, bukan key Anda. Tunggu ±1 menit lalu klik Coba lagi.'
        : 'Tunggu ±1 menit lalu klik Coba lagi. Tips: API key sendiri memberi kuota & prioritas terpisah.',
      action: 'retry',
      actionLabel: 'Coba lagi',
    };
  }

  if (/\[AI_BAD_JSON\]/.test(raw) || /Expecting ',' delimiter|Unterminated string|not valid JSON|JSON tidak valid/i.test(raw)) {
    return {
      text: 'AI mengembalikan format rusak.',
      hint: 'Umum terjadi saat server sibuk atau soal berisi banyak kode. Klik Generate ulang — bila masih gagal, sederhanakan prompt (minta code lebih pendek).',
      action: 'retry',
      actionLabel: 'Generate ulang',
    };
  }

  if (/Terlalu banyak permintaan AI/i.test(raw)) {
    return {
      text: 'Terlalu banyak permintaan AI.',
      hint: 'Batas 15x per menit untuk mencegah penyalahgunaan. Tunggu 1 menit lalu coba lagi.',
      action: null,
      actionLabel: null,
    };
  }

  if (/antara 3 hingga 40|ge=3|le=40|greater than or equal|less than or equal/i.test(raw)) {
    return {
      text: 'Jumlah soal harus antara 3 hingga 40.',
      hint: 'Pilih jumlah lewat pil di toolbar, atau tulis angkanya di prompt (mis. "buatkan 35 soal").',
      action: null,
      actionLabel: null,
    };
  }

  if (/Timeout|timed out|kehabisan waktu/i.test(raw)) {
    return {
      text: 'Generate kehabisan waktu (khususnya untuk 25+ soal).',
      hint: 'Klik Coba lagi — atau turunkan ke 20–25 soal dulu lalu gunakan tombol susulan untuk sisanya.',
      action: 'retry',
      actionLabel: 'Coba lagi',
    };
  }

  if (/timeout|Gagal terhubung ke server|network|Failed to fetch|Load failed/i.test(raw)) {
    return {
      text: 'Gagal terhubung ke server.',
      hint: 'Periksa koneksi / ngrok / VITE_API_BASE_URL, lalu coba lagi.',
      action: 'retry',
      actionLabel: 'Coba lagi',
    };
  }

  if (/Prompt (terlalu|tidak|mengandung)|ketikan acak|karakter berulang/i.test(raw)) {
    return { text: raw, hint: null, action: null, actionLabel: null };
  }

  return { text: shortTail(raw), hint: null, action: null, actionLabel: null };
}
