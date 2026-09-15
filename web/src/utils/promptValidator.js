/**
 * Validator cerdas untuk mendeteksi prompt gibberish / teks asal-asalan.
 * Mencegah pemborosan token API ke model LLM.
 */

// Pola deretan tombol keyboard (QWERTY mash)
const KEYBOARD_SEQUENCES = [
  'qwerty', 'wertyu', 'ertyui', 'rtyuio', 'tyuiop',
  'asdfgh', 'sdfghj', 'dfghjk', 'fghjkl',
  'zxcvbn', 'xcvbnm',
  'poiuyt', 'oiuytr', 'iuytre', 'uytrew', 'ytrewq',
  'lkjhgf', 'kjhgfd', 'jhgfdsa',
  'mnbvcx', 'nbvcxz',
  'qazwsx', 'wsxedc', 'edcrfv', 'rfvtgb', 'tgbzhn', 'yhnujm',
  '123456', '234567', '345678', '456789', '567890',
  '098765', '987654', '876543', '765432', '654321',
  'abcdef', 'bcdefg', 'cdefgh', 'defghi'
];

/**
 * Validasi prompt apakah valid dan memiliki makna wajar atau terdeteksi gibberish.
 * @param {string} prompt
 * @returns {{ isValid: boolean, error: string | null }}
 */
export function validatePrompt(prompt) {
  if (!prompt || typeof prompt !== 'string') {
    return {
      isValid: false,
      error: 'Prompt tidak boleh kosong. Silakan jelaskan formulir yang ingin dibuat.'
    };
  }

  const trimmed = prompt.trim();

  // 1. Cek panjang minimal & maksimal
  if (trimmed.length < 10) {
    return {
      isValid: false,
      error: 'Prompt terlalu pendek (minimal 10 karakter). Jelaskan topik atau kebutuhan formulir Anda.'
    };
  }

  if (trimmed.length > 4000) {
    return {
      isValid: false,
      error: 'Prompt melebihi batas maksimal 4000 karakter.'
    };
  }

  // 2. Cek karakter berulang tidak wajar (misal: aaaaaa, 111111, ........)
  if (/(.)\1{4,}/.test(trimmed)) {
    return {
      isValid: false,
      error: 'Prompt mengandung karakter berulang yang tidak wajar. Mohon gunakan kalimat deskriptif yang jelas.'
    };
  }

  // 3. Cek pola suku kata berulang (misal: asdasdasd, hehehehehe, lalalala, abcabcabc)
  if (/([a-zA-Z0-9]{2,4})\1{3,}/i.test(trimmed)) {
    return {
      isValid: false,
      error: 'Prompt mengandung pengulangan kata/pola acak. Mohon berikan instruksi form yang spesifik.'
    };
  }

  // 4. Bersihkan spasi & normalisasi untuk analisis teks
  const cleanLower = trimmed.toLowerCase();
  const words = trimmed.split(/\s+/).filter(w => w.length > 0);

  // 5. Cek jika seluruh prompt hanya berupa 1 kata panjang tanpa spasi
  if (words.length === 1 && trimmed.length > 20) {
    return {
      isValid: false,
      error: 'Prompt tidak memiliki spasi atau pemisah kata. Mohon tuliskan dalam bentuk kalimat.'
    };
  }

  // Minimal ada 2 kata terpisah untuk kalimat bermakna
  if (words.length < 2 && trimmed.length < 25) {
    return {
      isValid: false,
      error: 'Prompt terlalu singkat. Mohon tuliskan minimal 2-3 kata (contoh: "Kuis Biologi Bab Sel").'
    };
  }

  // 6. Cek Keyboard Mash Sequences (qwertyuiop, asdfghjkl, dll)
  const compactText = cleanLower.replace(/[\s\-_.,!?]+/g, '');
  for (const seq of KEYBOARD_SEQUENCES) {
    if (compactText.includes(seq)) {
      return {
        isValid: false,
        error: 'Prompt terdeteksi sebagai ketikan acak keyboard (keyboard mash). Mohon jelaskan form yang ingin Anda buat.'
      };
    }
  }

  // 7. Analisis Kata: Kata tanpa vokal & Konsonan beruntun ekstrem
  let totalLetters = 0;
  let totalVowels = 0;

  for (const rawWord of words) {
    // Ambil hanya huruf alfabet
    const word = rawWord.toLowerCase().replace(/[^a-z]/g, '');
    if (!word) continue;

    totalLetters += word.length;
    const vowels = (word.match(/[aiueo]/g) || []).length;
    totalVowels += vowels;

    // Kata dengan 5+ huruf tanpa ada vokal sama sekali (misal: "bcdfgh", "zxcvb", "dfghj")
    if (word.length >= 5 && vowels === 0) {
      return {
        isValid: false,
        error: `Kata "${rawWord}" tidak dikenali atau tidak memiliki huruf vokal. Mohon ketikkan kalimat yang jelas.`
      };
    }

    // 5+ konsonan berurutan dalam satu kata (hampir tidak mungkin dalam bahasa Indonesia / Inggris alami)
    if (/[bcdfghjklmnpqrstvwxyz]{5,}/i.test(word)) {
      return {
        isValid: false,
        error: `Kata "${rawWord}" terdeteksi acak (konsonan beruntun tidak wajar). Mohon perbaiki instruksi Anda.`
      };
    }

    // 1 kata tunggal terlalu panjang tanpa jeda
    if (word.length > 30) {
      return {
        isValid: false,
        error: `Kata "${rawWord.slice(0, 20)}..." terlalu panjang. Pastikan terdapat spasi antar kata.`
      };
    }
  }

  // 8. Rasio Vokal terhadap Total Huruf (Hanya jika teks cukup panjang > 12 huruf)
  if (totalLetters >= 12) {
    const vowelRatio = totalVowels / totalLetters;
    // Bahasa normal vokal berada di kisaran ~20% s/d ~70%
    if (vowelRatio < 0.12) {
      return {
        isValid: false,
        error: 'Prompt tidak menyerupai bahasa yang valid (kadar vokal terlalu rendah). Mohon gunakan kalimat yang dapat dipahami.'
      };
    }
    if (vowelRatio > 0.85) {
      return {
        isValid: false,
        error: 'Prompt tidak valid (hampir seluruhnya huruf vokal). Mohon gunakan instruksi yang wajar.'
      };
    }
  }

  // 9. Entropi / Keanekaragaman karakter (mencegah variasi abab bab baab acak)
  if (trimmed.length >= 15) {
    const uniqueChars = new Set(cleanLower.replace(/\s+/g, '')).size;
    const uniqueRatio = uniqueChars / cleanLower.replace(/\s+/g, '').length;
    if (uniqueRatio < 0.15 && uniqueChars <= 3) {
      return {
        isValid: false,
        error: 'Prompt terdeteksi berisi variasi karakter yang sama berulang kali.'
      };
    }
  }

  return { isValid: true, error: null };
}
