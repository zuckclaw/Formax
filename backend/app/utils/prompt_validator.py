"""
Validator cerdas untuk mendeteksi prompt gibberish / teks asal-asalan di sisi backend.
Mencegah request liar memanggil API LLM (Gemini / OpenRouter) dan menghabiskan kuota token.
"""
import re
from typing import Tuple, Optional

KEYBOARD_SEQUENCES = [
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
]

RE_REPEATED_CHARS = re.compile(r'(.)\1{4,}')
RE_REPEATED_SUBSTR = re.compile(r'([a-zA-Z0-9]{2,4})\1{3,}', re.IGNORECASE)
RE_CONSONANT_STREAK = re.compile(r'[bcdfghjklmnpqrstvwxyz]{5,}', re.IGNORECASE)
RE_VOWELS = re.compile(r'[aiueo]', re.IGNORECASE)


def validate_prompt(prompt: str) -> Tuple[bool, Optional[str]]:
    """
    Memvalidasi apakah prompt memiliki makna wajar atau terdeteksi gibberish/spam.
    Returns: (is_valid, error_message)
    """
    if not prompt or not isinstance(prompt, str):
        return False, "Prompt tidak boleh kosong. Silakan jelaskan formulir yang ingin dibuat."

    trimmed = prompt.strip()

    # 1. Cek panjang
    if len(trimmed) < 10:
        return False, "Prompt terlalu pendek (minimal 10 karakter). Jelaskan topik atau kebutuhan formulir Anda."

    if len(trimmed) > 4000:
        return False, "Prompt melebihi batas maksimal 4000 karakter."

    # 2. Cek karakter berulang tidak wajar (misal: aaaaaa, 111111)
    if RE_REPEATED_CHARS.search(trimmed):
        return False, "Prompt mengandung karakter berulang yang tidak wajar. Mohon gunakan kalimat deskriptif yang jelas."

    # 3. Cek pola suku kata berulang (misal: asdasdasd, hehehehehe)
    if RE_REPEATED_SUBSTR.search(trimmed):
        return False, "Prompt mengandung pengulangan pola acak. Mohon berikan instruksi form yang spesifik."

    # 4. Normalisasi kata
    clean_lower = trimmed.lower()
    words = [w for w in re.split(r'\s+', trimmed) if w]

    # 5. Cek jika seluruh prompt hanya berupa 1 kata panjang tanpa spasi
    if len(words) == 1 and len(trimmed) > 20:
        return False, "Prompt tidak memiliki spasi atau pemisah kata. Mohon tuliskan dalam bentuk kalimat."

    if len(words) < 2 and len(trimmed) < 25:
        return False, "Prompt terlalu singkat. Mohon tuliskan minimal 2-3 kata (contoh: 'Kuis Biologi Bab Sel')."

    # 6. Cek Keyboard Mash
    compact_text = re.sub(r'[\s\-_.,!?]+', '', clean_lower)
    for seq in KEYBOARD_SEQUENCES:
        if seq in compact_text:
            return False, "Prompt terdeteksi sebagai ketikan acak keyboard (keyboard mash). Mohon jelaskan form yang ingin Anda buat."

    # 7. Analisis Kata (ketiadaan vokal & konsonan beruntun ekstrem)
    total_letters = 0
    total_vowels = 0

    for raw_word in words:
        word = re.sub(r'[^a-z]', '', raw_word.lower())
        if not word:
            continue

        total_letters += len(word)
        vowels_count = len(RE_VOWELS.findall(word))
        total_vowels += vowels_count

        # Kata dengan 5+ huruf tanpa ada vokal sama sekali
        if len(word) >= 5 and vowels_count == 0:
            return False, f"Kata '{raw_word}' tidak dikenali atau tidak memiliki huruf vokal. Mohon ketikkan kalimat yang jelas."

        # 5+ konsonan beruntun dalam satu kata
        if RE_CONSONANT_STREAK.search(word):
            return False, f"Kata '{raw_word}' terdeteksi acak (konsonan beruntun tidak wajar). Mohon perbaiki instruksi Anda."

        if len(word) > 30:
            return False, f"Kata '{raw_word[:20]}...' terlalu panjang. Pastikan terdapat spasi antar kata."

    # 8. Rasio Vokal terhadap Total Huruf
    if total_letters >= 12:
        vowel_ratio = total_vowels / total_letters
        if vowel_ratio < 0.12:
            return False, "Prompt tidak menyerupai bahasa yang valid (kadar vokal terlalu rendah). Mohon gunakan kalimat yang dapat dipahami."
        if vowel_ratio > 0.85:
            return False, "Prompt tidak valid (hampir seluruhnya huruf vokal). Mohon gunakan instruksi yang wajar."

    # 9. Entropi Karakter Unik
    if len(trimmed) >= 15:
        non_space = re.sub(r'\s+', '', clean_lower)
        unique_chars = len(set(non_space))
        if unique_chars <= 3 and (unique_chars / len(non_space)) < 0.15:
            return False, "Prompt terdeteksi berisi variasi karakter yang sama berulang kali."

    return True, None
