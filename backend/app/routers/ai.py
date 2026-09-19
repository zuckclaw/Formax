import os
import io
import json
import re
import time
import random
from typing import Optional, List

import httpx
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Header
from pydantic import BaseModel, Field

from ..deps import get_current_user
from .. import models
from ..utils.prompt_validator import validate_prompt, extract_question_count

router = APIRouter(prefix="/ai", tags=["ai"])

_rate_store = {}
_RATE_STORE_MAX_KEYS = 5000


def _check_rate_limit(user_id: str, limit: int = 15, window_sec: int = 60):
    now = time.time()
    lst = _rate_store.get(user_id, [])
    lst = [t for t in lst if now - t < window_sec]
    if len(lst) >= limit:
        raise HTTPException(status_code=429, detail="Terlalu banyak permintaan AI. Silakan tunggu 1 menit.")
    lst.append(now)
    _rate_store[user_id] = lst
    # Cegah leak memori: hapus key kedaluwarsa & batasi jumlah key (single-process).
    # Tanpa ini dict tumbuh selamanya (satu key per user) dan hilang saat restart/worker lain.
    if len(_rate_store) > _RATE_STORE_MAX_KEYS:
        expired = [k for k, v in _rate_store.items() if not v or (now - v[-1] > window_sec)]
        for k in expired[:1000]:
            _rate_store.pop(k, None)

class AiGenerateRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=120)
    description: Optional[str] = Field(None, max_length=2000)
    prompt: str = Field(..., min_length=10, max_length=4000)
    num_questions: int = Field(10, ge=3, le=40)
    include_correct: bool = True
    use_sections: bool = True
    prefer_type: Optional[str] = None
    file_context: Optional[str] = Field(None, max_length=20000)

class AiQuestionOptionOut(BaseModel):
    label: str
    is_correct: bool = False

class AiQuestionOut(BaseModel):
    type: str
    label: str
    is_required: bool = False
    placeholder: Optional[str] = None
    settings: dict = {}
    options: List[AiQuestionOptionOut] = []

class AiGenerateOut(BaseModel):
    title: str
    description: str
    questions: List[AiQuestionOut]
    usage: Optional[dict] = None

ALLOWED_TYPES = {"text", "paragraph", "single_choice", "checkbox", "dropdown", "date", "file_upload", "page_break"}

SYSTEM_BASE = """You are Formax AI — a world-class form, exam, and survey architect for the Formax platform.
Your task is to generate high-quality, professional, intelligent forms based on the user's prompt.

CRITICAL INSTRUCTIONS:
1. Output MUST be valid JSON only, strictly matching the schema. No conversational preamble.
2. Language: Follow the prompt's language (Indonesian prompt -> Indonesian output; English prompt -> English output).
3. ZERO AI-SLOP: Never generate generic placeholders like "Opsi A", "Jawaban 1", "Pertanyaan 1", "Teks placeholder", or "Soal tentang X". Every question label, section header, and option MUST be realistic, specific, and complete.
4. MATH & SCIENCE FORMULAS: If the form includes math, physics, or statistics, format equations in standard LaTeX syntax wrapped in \\(...\\) for inline or \\[...\\] for block math (e.g., \\(f(x) = ax^2 + bx + c\\), \\(\\lim_{x \\to 0} \\frac{\\sin x}{x} = 1\\)).
5. EXAM ACCURACY: When include_correct is true, ensure EXACTLY 1 correct option (is_correct: true) per single_choice question, with plausible distractors.
6. CODE SNIPPETS (HTML/CSS/JS/Python/dll): NEVER output raw/bare HTML tags inside label/options (e.g. NEVER write "fungsi tag <p>" or option "<div class=...>" as raw tags). ALWAYS escape angle brackets as entities (&lt; &gt; &amp;) for inline code, e.g. "fungsi tag &lt;p&gt;", "penulisan &lt;div class=&quot;container&quot;&gt; yang benar". For multi-line code, wrap the ESCAPED code in <pre><code class="language-html">...escaped code...</code></pre> (language-html/css/javascript/python as appropriate). Markdown fences (```html) are FORBIDDEN inside JSON — use <pre><code> instead. Keep double quotes inside JSON strings properly escaped (JSON syntax must stay valid).

JSON SCHEMA:
{
  "title": "Short, professional form title (5-80 chars)",
  "description": "Clear form description detailing instructions or background (20-300 chars)",
  "questions": [
    {
      "type": "page_break | text | paragraph | single_choice | checkbox | dropdown | date | file_upload",
      "label": "Full, well-punctuated question text",
      "is_required": true,
      "placeholder": "Helpful placeholder hint for text inputs or empty string",
      "settings": {
        "description": "Sub-instruction or empty string",
        "shuffle": true
      },
      "options": [
        {"label": "Option content", "is_correct": false}
      ]
    }
  ]
}

QUESTION TYPE RULES:
- page_break: Section header (Bagian). Use when prompt mentions sections/parts or for grouping (e.g. "Bagian 1: Data Diri", "Bagian 2: Soal Ujian"). Set settings.shuffle = true for exam sections.
- single_choice: Standard multiple choice (3-4 options). Exactly 1 option is_correct=true if include_correct=true.
- checkbox: Multiple selection choices (3-5 options).
- dropdown: Selection menu for categories, departments, classes, or locations.
- text: Short text answer (e.g. Nama, NIM, Email, Jabatan).
- paragraph: Long text answer / Essay / Detailed Feedback.
- date: Date selection (e.g. Tanggal Lahir, Tanggal Pelaksanaan).
- file_upload: File attachment (e.g. Upload Bukti, Resume, Foto KTP).
"""

def _build_user_prompt(req: AiGenerateRequest, effective_num_questions: int) -> str:
    title_hint = f"Judul form spesifik: {req.title}" if req.title else "Judul form: Buatkan judul profesional & menarik sesuai konteks prompt."
    desc_hint = f"Deskripsi form spesifik: {req.description}" if req.description else "Deskripsi: Generate 1-2 kalimat petunjuk pengisian yang ramah & jelas."
    correct_hint = "KUNCI JAWABAN: Wajib tandai tepat 1 opsi benar (is_correct: true) untuk tiap soal pilihan ganda (single_choice)." if req.include_correct else "KUNCI JAWABAN: Matikan kunci jawaban, semua is_correct: false."
    section_hint = "BAGIAN (SECTION): Gunakan page_break untuk memisahkan Bagian 1 (Identitas/Info) dan Bagian 2 (Soal/Evaluasi). Beri label bagian & deskripsi yang pas." if req.use_sections else "BAGIAN (SECTION): Jangan gunakan page_break, susun pertanyaan secara mendatar (flat)."
    type_hint = f"PREFER TYPE: Utamakan penggunaan tipe {req.prefer_type} untuk soal utama." if req.prefer_type and req.prefer_type != "auto" else "TIPE SOAL: Variasikan tipe soal secara logis sesuai konteks (single_choice untuk kuis, text/dropdown untuk identitas, paragraph untuk esai)."
    
    # Check if prompt contains math/science related terms
    is_math = bool(re.search(r'(matematika|math|aljabar|kalkulus|geometri|trigonometri|fisika|rumus|persamaan|equation|hitung|kuadrat|pecahan|integral|turunan)', req.prompt, re.IGNORECASE))
    math_hint = "PENTING SINTAKS MATEMATIKA: Bungkus SEMUA rumus, persamaan, variabel (seperti x, y), pecahan, eksponen, atau simbol matematika dengan notasi LaTeX \\(...\\) (contoh: \\(f(x) = ax^2 + bx + c\\), \\(\\frac{1}{2}\\), \\(\\sqrt{b^2 - 4ac}\\)) agar otomatis ter-render oleh KaTeX! RUMUS SATU BARIS: di dalam \\(...\\) DILARANG memakai pemisah baris \\\\, environment aligned/matrix/cases/pmatrix, atau tag <br> — tulis tiap rumus opsi dalam SATU BARIS utuh." if is_math else ""

    # Check if prompt asks for coding questions (HTML/CSS/JS/Python/dll)
    is_code = bool(re.search(r'(html|css|javascript|js\b|python|php|java\b|tag\b|elemen|koding|coding|program|script|div\b|kode\b|informatika|pemrograman|web\b|tailwind|react|vue)', req.prompt, re.IGNORECASE))
    code_hint = (
        "PENTING FORMAT CODE: Soal ini mengandung KODE. Aturan wajib: "
        "(1) JANGAN tulis tag HTML mentah di label/opsi (contoh SALAH: \"fungsi tag <p>\", opsi \"<div>\"). "
        "(2) Inline code WAJIB di-escape sebagai entities: &lt; &gt; &amp; &quot; "
        "(contoh BENAR: \"fungsi tag &lt;p&gt;\", \"&lt;div class=&quot;container&quot;&gt;\"). "
        "(3) Kode multi-baris WAJIB dibungkus <pre><code class=\"language-html\">...kode yang sudah di-escape...</code></pre> "
        "(ganti language-html dengan language-css/language-javascript/language-python sesuai bahasa). "
        "(4) DILARANG memakai markdown fence ``` di dalam JSON. "
        "(5) VALIDITAS JSON DI ATAS SEGALANYA: tidak ada newline literal di dalam string "
        "(pakai escape \\n bila perlu baris baru), setiap tanda kutip ganda di dalam string "
        "WAJIB di-escape sebagai \\\", dan snippet code dibuat sekompak mungkin."
    ) if is_code else ""

    file_context_hint = ""
    if req.file_context and req.file_context.strip():
        file_context_hint = f"\n=== REFERENSI DOKUMEN / MATERI TERLAMPIR ===\n{req.file_context.strip()[:15000]}\n=== AKHIR DOKUMEN TERLAMPIR ===\n(PENTING: Buat soal/formulir berdasarkan materi dokumen di atas secara relevan dan presisi.)\n"

    # Target besar (26-40): tekankan kompak agar JSON tidak terpotong di tengah.
    # Soal yang tidak muat lebih baik sedikit — JANGAN mengorbankan validitas JSON.
    big_hint = ""
    if effective_num_questions > 25:
        big_hint = (
            f"TARGET BESAR ({effective_num_questions} soal): buat snippet code MAKSIMAL 6 baris per soal, "
            "opsi singkat (maksimal ±12 kata), deskripsi section 1 kalimat. "
            "Utamakan SEMUA soal lengkap & JSON valid daripada detail berlebih. "
            "Jika tidak muat, hasilkan soal selengkap mungkin — jangan potong JSON di tengah."
        )

    return f"""{title_hint}
{desc_hint}
Prompt Pengguna: "{req.prompt}"
{file_context_hint}Target Jumlah Soal (tidak menghitung page_break): {effective_num_questions} soal (Wajib tepat {effective_num_questions} pertanyaan)
{correct_hint}
{section_hint}
{type_hint}
{math_hint}
{code_hint}
{big_hint}

PENTING:
- Buat tepat {effective_num_questions} pertanyaan utama (di luar type page_break).
- Seluruh teks dalam bahasa yang sama dengan prompt pengguna.
- Hasilkan JSON murni sesuai schema.
"""

def _repair_json(text: str) -> str:
    text = text.strip()
    # Hapus fence markdown yang membungkus SELURUH respons (dengan/tanpa preamble).
    # Contoh: "Here is JSON:\n```json\n{...}\n```" -> ambil isi fence dulu.
    fence_m = re.search(r"```(?:json)?\s*(\{[\s\S]*\})\s*```", text)
    if fence_m:
        return fence_m.group(1)
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    m = re.search(r"\{[\s\S]*\}", text)
    if m:
        return m.group(0)
    return text


# ==================== ERROR TAGS (kontrak stabil untuk UX frontend) ====================
# Frontend (AiFormBuilderPage via mapAiError) memetakan prefix ini menjadi pesan
# ramah + tombol aksi. JANGAN ubah string tag tanpa update web/src/utils/aiErrors.js.
TAG_BUSY = "[AI_BUSY]"        # semua kandidat 503/overload/transien -> coba lagi manual
TAG_QUOTA = "[AI_QUOTA]"      # kuota Google habis -> tempel API key sendiri / tunggu reset
TAG_BAD_KEY = "[AI_BAD_KEY]"  # API key (milik user) tidak valid -> periksa key
TAG_BAD_JSON = "[AI_BAD_JSON]"  # model mengembalikan JSON rusak -> generate ulang manual


def _classify_provider_error(status_code: int, body: str) -> Optional[str]:
    """Kembalikan tag error berdasarkan status + isi body dari Google. None = tak dikenal."""
    b = (body or "").lower()
    if status_code == 503 or "high demand" in b or "unavailable" in b or "overloaded" in b:
        return TAG_BUSY
    if status_code == 429 or "quota" in b or "rate limit" in b or "resource_exhausted" in b:
        return TAG_QUOTA
    if status_code in (400, 401, 403) and ("api key" in b or "api_key" in b or "invalid" in b or "permission denied" in b):
        return TAG_BAD_KEY
    if status_code in (500, 502, 504) or "internal error" in b or "timeout" in b:
        return TAG_BUSY
    return None


# ==================== BYOK (Bring Your Own Key — Gemini milik user) ====================
# Key dikirim per-request via header X-Gemini-API-Key (tidak disimpan di server).
# TIDAK PERNAH log full key — hanya suffix 4 char untuk diagnosis.

def _mask_key(key: str) -> str:
    if not key or len(key) <= 4:
        return "****"
    return f"****{key[-4:]}"


def _resolve_gemini_key(header_key: Optional[str]):
    """Kembalikan (api_key, source, error). source: 'own' | 'server'. error: str|None."""
    own = (header_key or "").strip()
    if own:
        if len(own) < 20 or len(own) > 300 or any(ord(c) < 32 or ord(c) == 127 for c in own):
            return None, "own", "Format API key tidak valid. Tempel ulang API key Gemini (biasanya diawali AIza, ~39 karakter)."
        return own, "own", None
    env_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not env_key:
        return None, "server", None
    return env_key, "server", None


# ==================== LENIENT JSON PARSER (jaring pengaman output model lemah) ====================
# Model non-JSON-mode (gemma/groq fallback, atau kandidat lemah saat overload)
# sering menulis newline literal / trailing comma di dalam string code.
# Parser ini string-aware: tidak pernah menyentuh isi di dalam string JSON.

def _escape_controls_in_strings(s: str) -> str:
    out = []
    in_str = False
    esc = False
    for ch in s:
        if in_str:
            if esc:
                out.append(ch)
                esc = False
            elif ch == "\\":
                out.append(ch)
                esc = True
            elif ch == '"':
                out.append(ch)
                in_str = False
            elif ch == "\n":
                out.append("\\n")
            elif ch == "\r":
                out.append("\\r")
            elif ch == "\t":
                out.append("\\t")
            elif ord(ch) < 32:
                out.append(f"\\u{ord(ch):04x}")
            else:
                out.append(ch)
        else:
            out.append(ch)
            if ch == '"':
                in_str = True
    return "".join(out)


def _strip_trailing_commas_outside_strings(s: str) -> str:
    out = []
    in_str = False
    esc = False
    i, n = 0, len(s)
    while i < n:
        ch = s[i]
        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
            continue
        if ch == ",":
            j = i + 1
            while j < n and s[j] in " \t\r\n":
                j += 1
            if j < n and s[j] in "}]":
                i += 1  # buang koma tergantung — di luar string, aman
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def _looks_like_latex_after_bs(s: str, i: int) -> bool:
    """True bila backslash di posisi i kemungkinan awal perintah LaTeX.

    Kasus: model menulis \\frac / \\neq / \\theta tunggal. Dalam JSON,
    \\f/\\b/\\n/\\t adalah escape VALID (formfeed/backspace/newline/tab)
    sehingga json.loads lolos tapi isi rusak (formfeed + "rac").
    Prosa normal praktis tidak pernah memakai escape itu diikuti huruf,
    jadi pola di bawah aman digandakan menjadi backslash literal.
    """
    if i + 1 >= len(s):
        return False
    nxt = s[i + 1]
    if nxt == "f" and i + 2 < len(s) and s[i + 2].isalpha():
        return True  # \frac, \footnotesize, ...
    if nxt == "b" and i + 2 < len(s) and s[i + 2].isalpha():
        return True  # \binom, \bar, \beta, ...
    if nxt == "n":
        # \neq \notin \nexists \nabla — newline asli + huruf kecil jarang
        # diawali pola ini; newline + kapital tetap dibiarkan.
        tail = s[i + 1:i + 7].lower()
        if tail.startswith(("neq", "notin", "nexists", "nabla")):
            return True
        return False
    if nxt == "t":
        tail = s[i + 2:i + 6].lower()
        if tail.startswith(("heta", "imes")):  # \theta, \times
            return True
        return False
    return False


def _escape_lone_backslashes(s: str) -> str:
    """Perbaiki escape LaTeX tunggal ("\\frac", "\\sqrt") di dalam string JSON.

    Dalam JSON yang valid, backslash harus ditulis ganda ("\\\\frac"). Model
    sering menulis tunggal sehingga json.loads gagal (Invalid \\escape) ATAU
    lolos tapi rusak (\\f → formfeed). Fungsi ini string-aware: hanya menyentuh
    backslash yang ilegal, atau yang valid tapi jelas perintah LaTeX.
    Tidak mengubah isi luar string.
    """
    valid_next = set('"\\/bfnrtu')
    out = []
    in_str = False
    esc = False
    i, n = 0, len(s)
    while i < n:
        ch = s[i]
        if in_str:
            if esc:
                out.append(ch)
                esc = False
            elif ch == "\\":
                nxt = s[i + 1] if i + 1 < n else ""
                if nxt in valid_next and not _looks_like_latex_after_bs(s, i):
                    out.append(ch)
                    esc = True
                else:
                    # backslash liar (mis. \( \) \.) atau perintah LaTeX → gandakan
                    out.append("\\\\")
            elif ch == '"':
                out.append(ch)
                in_str = False
            else:
                out.append(ch)
            i += 1
            continue
        out.append(ch)
        if ch == '"':
            in_str = True
        i += 1
    return "".join(out)


def _loads_lenient(text: str):
    """json.loads ketat dulu, lalu repair string-aware. Raise JSONDecodeError asli bila gagal."""
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    fixed = _escape_controls_in_strings(text)
    try:
        return json.loads(fixed)
    except json.JSONDecodeError:
        pass
    fixed2 = _escape_lone_backslashes(fixed)
    try:
        return json.loads(fixed2)
    except json.JSONDecodeError:
        pass
    fixed3 = _strip_trailing_commas_outside_strings(fixed2)
    return json.loads(fixed3)


def _error_window(text: str, pos: int, radius: int = 200) -> str:
    lo = max(0, pos - radius)
    hi = min(len(text), pos + radius)
    return text[lo:hi]


# ==================== CODE NORMALIZER (fix soal coding/HTML kosong) ====================
# AI sering mengembalikan tag HTML mentah di label/opsi (mis. "fungsi tag <p>",
# opsi "<div class=\"container\">"). Tag mentah itu kemudian dianggap elemen HTML
# beneran oleh DOMPurify di frontend dan di-strip -> soal/opsi tampak kosong.
# Normalizer ini mengubahnya menjadi entities + <pre><code> yang aman dirender.

import html as _html_mod

_CODE_FENCE_RE = re.compile(r"```(\w*)\s*\n?([\s\S]*?)```", re.MULTILINE)
_PRE_BLOCK_RE = re.compile(r"<pre(\s[^>]*)?>([\s\S]*?)</pre\s*>", re.IGNORECASE)
_CODE_TAG_RE = re.compile(r"</?(?:html|head|body|title|meta|link|div|span|p|a|img|ul|ol|li|table|thead|tbody|tr|td|th|form|input|button|select|option|textarea|label|h1|h2|h3|h4|h5|h6|header|footer|section|article|nav|main|aside|style|script|pre|code|blockquote|br|hr)(?:\s[^<>]*)?/?>", re.IGNORECASE)


def _escape_code_text(code: str) -> str:
    """Escape < > & untuk ditampilkan sebagai teks code (hindari double-escape)."""
    if not code:
        return ""
    # Jika sudah berbentuk entities, jangan escape ulang.
    if "&lt;" in code or "&gt;" in code:
        return code
    return _html_mod.escape(code, quote=False)


def _normalize_code_html(value: str) -> str:
    """Normalisasi satu string label/opsi/deskripsi agar snippet code aman dirender.

    - Lindungi <pre>...</pre> yang sudah benar (escape isi mentahnya).
    - Konversi markdown fence ```lang ... ``` menjadi <pre><code>.
    - Escape bare tag HTML di luar <pre>/<code> menjadi entities + bungkus
      inline <code> bila berupa potongan pendek, atau <pre><code> bila multi-baris.
    - Idempoten: konten yang sudah &lt;...&gt; tidak diubah.
    """
    if not value or not isinstance(value, str):
        return value
    s = value.strip()
    if not s:
        return s
    # 1) <pre> block yang sudah ada -> perbaiki isinya langsung (sebelum stash),
    #    agar tidak terjadi nested <code> ganda.
    # Sudah ada <pre> yang benar -> pastikan isinya ter-escape, lalu selesai.
    if "<pre" in s.lower():
        def _fix_pre(m):
            attrs, inner = m.group(1) or "", m.group(2) or ""
            # Jika inner sudah berisi <code>, escape di dalam code saja.
            cm = re.search(r"<code(\s[^>]*)?>([\s\S]*?)</code\s*>", inner, re.IGNORECASE)
            if cm:
                code_attrs, code_inner = cm.group(1) or "", cm.group(2) or ""
                if "<" in code_inner and "&lt;" not in code_inner:
                    code_inner = _html_mod.escape(code_inner, quote=False)
                # pastikan ada language class untuk highlight
                if "language-" not in (code_attrs or ""):
                    code_attrs = (code_attrs or "") + ' class="language-html"'
                inner = re.sub(
                    r"<code(\s[^>]*)?>([\s\S]*?)</code\s*>",
                    f"<code{code_attrs}>{code_inner}</code>",
                    inner, count=1, flags=re.IGNORECASE,
                )
                return f"<pre{attrs}>{inner}</pre>"
            # <pre> tanpa <code>: escape seluruh inner lalu bungkus <code>
            if "<" in inner and "&lt;" not in inner:
                inner = _html_mod.escape(inner, quote=False)
            return f'<pre{attrs}><code class="language-html">{inner}</code></pre>'
        return _PRE_BLOCK_RE.sub(_fix_pre, s)

    # 2) Lindungi inline <code>...</code> yang sudah benar agar tidak di-escape ulang.
    _code_placeholders = []

    def _stash_code(m):
        _code_placeholders.append(m.group(0))
        return f"\x00CODE{len(_code_placeholders) - 1}\x00"

    s = re.sub(r"<code(\s[^>]*)?>[\s\S]*?</code\s*>", _stash_code, s, flags=re.IGNORECASE)

    def _restore(t):
        for i, orig in enumerate(_code_placeholders):
            t = t.replace(f"\x00CODE{i}\x00", orig)
        return t

    # Konversi markdown fence -> <pre><code> (AI kadang tetap memakai fence di dalam JSON string)
    def _fence_to_pre(m):
        lang = (m.group(1) or "html").strip().lower() or "html"
        if lang in ("htm",):
            lang = "html"
        if lang in ("js",):
            lang = "javascript"
        if lang in ("py",):
            lang = "python"
        code = m.group(2) or ""
        return f'<pre><code class="language-{lang}">{_escape_code_text(code.strip())}</code></pre>'
    s = _CODE_FENCE_RE.sub(_fence_to_pre, s)

    # Tidak ada tag mentah -> selesai.
    if "<" not in s or "&lt;" in s and not _CODE_TAG_RE.search(s):
        # Masih mungkin ada backtick inline `code` -> jadikan <code>
        if "`" in s:
            s = re.sub(
                r"`([^`\n]+)`",
                lambda m: f"<code>{_escape_code_text(m.group(1))}</code>",
                s,
            )
        return _restore(s)

    # Ada bare tag di luar pre/code.
    # Kasus multi-baris mirip dokumen HTML utuh -> bungkus seluruhnya sebagai block.
    if "\n" in s and _CODE_TAG_RE.search(s) and s.count("<") >= 2:
        return _restore(f'<pre><code class="language-html">{_escape_code_text(s)}</code></pre>')

    # Kasus umum: escape tiap bare tag, bungkus potongan code pendek dengan <code>.
    def _esc_tag(m):
        raw = m.group(0)
        return f"<code>{_html_mod.escape(raw, quote=False)}</code>"
    s = _CODE_TAG_RE.sub(_esc_tag, s)
    # Sisa backtick inline -> <code>
    if "`" in s:
        s = re.sub(
            r"`([^`\n]+)`",
            lambda m: f"<code>{_escape_code_text(m.group(1))}</code>",
            s,
        )
    return _restore(s)

# last error string for fail-loud response (set by _call_gemini / _call_openrouter)
_last_ai_error: Optional[str] = None


def _budget_for_count(n: int) -> tuple[int, float]:
    """Budget output + timeout per-kandidat berdasarkan jumlah soal.
    40 soal JSON ≈ 12–20k token; beri ruang agar tidak terpotong (BAD_JSON)."""
    n = max(3, min(40, int(n or 10)))
    if n <= 15:
        return 8192, 25.0
    if n <= 25:
        return 16384, 30.0
    return 32768, 40.0


async def _call_gemini(user_prompt: str, api_key: Optional[str] = None, key_source: str = "server", num_questions: int = 10) -> Optional[str]:
    global _last_ai_error
    if not api_key:
        api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        _last_ai_error = "GEMINI_API_KEY belum di-set di environment"
        print(f"[ai] {_last_ai_error}")
        return None
    print(f"[ai] Gemini key source: {key_source} ({_mask_key(api_key)})")

    env_model = (os.getenv("GEMINI_MODEL") or "").strip()
    # Filter env model yang sudah retire — jangan biarkan GEMINI_MODEL=gemini-1.5-flash meracuni daftar
    _retired = {"gemini-1.5-flash", "gemini-1.5-flash-latest", "gemini-1.5-flash-001", "gemini-1.5-pro", "gemma-4-26b-a4b-it"}
    if env_model in _retired or "gemma-4" in env_model:
        print(f"[ai] GEMINI_MODEL '{env_model}' sudah retire/invalid -> ignore, pakai default 2.x")
        env_model = ""

    # Coba v1 dulu (stable), baru v1beta sebagai fallback
    # UPDATE 2026-09-08: gemini-2.5-flash/2.0-flash/1.5-* sudah 404 untuk key baru.
    # Pesan Google: "use models/gemini-3.6-flash". ListModels 2026-09 membuktikan viable:
    #  gemini-3.6-flash (200), gemini-3.5-flash (200), gemini-3.7-flash (200),
    #  gemini-3.5-flash-lite (200), gemma-4-26b-a4b-it (200)
    raw_candidates = []
    if env_model:
        raw_candidates.append(("v1", env_model))
        raw_candidates.append(("v1beta", env_model))
    raw_candidates.extend([
        ("v1", "gemini-3.6-flash"),
        ("v1beta", "gemini-3.6-flash"),
        ("v1", "gemini-3.5-flash"),
        ("v1beta", "gemini-3.5-flash"),
        ("v1", "gemini-3.7-flash"),
        ("v1beta", "gemini-3.7-flash"),
        ("v1", "gemini-3.8-flash"),
        ("v1beta", "gemini-3.8-flash"),
        ("v1", "gemini-3.5-flash-lite"),
        ("v1beta", "gemini-3.5-flash-lite"),
        ("v1", "gemma-4-26b-a4b-it"),
        ("v1beta", "gemma-4-26b-a4b-it"),
        ("v1", "gemini-3.1-flash-lite"),
        ("v1beta", "gemini-3.1-flash-lite"),
    ])

    # --- Auto-discover via ListModels (fix utama untuk 404 gemini-1.5-flash-latest) ---
    # Jika API key valid, endpoint ini akan return daftar model yang benar-benar support generateContent
    # Kita prepend hasilnya agar dicoba pertama kali
    discovered = []
    for ver in ("v1", "v1beta"):
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                r = await client.get(f"https://generativelanguage.googleapis.com/{ver}/models?key={api_key}")
                if r.status_code == 200:
                    j = r.json()
                    for m in j.get("models", []):
                        name = m.get("name", "")  # e.g. models/gemini-2.0-flash
                        mid = name.split("/")[-1] if "/" in name else name
                        # hanya yang support generateContent
                        if "generateContent" in (m.get("supportedGenerationMethods") or []):
                            # skip model deprecated untuk akun baru — sudah terbukti 404
                            if mid.startswith("gemini-2.5-") or mid.startswith("gemini-2.0-") or mid == "gemini-2.5-pro":
                                continue
                            # jangan pakai image/deep-research/antigravity untuk form JSON
                            if "image" in mid or "antigravity" in mid or "deep-research" in mid:
                                continue
                            if "flash" in mid or "pro" in mid or "gemma" in mid:
                                discovered.append((ver, mid))
                    # priority: gemini-3.6-flash (direkomendasikan Google untuk key baru) > 3.5 > 3.7 > 3.8 > 3.1 > gemma
                    # 3.8/3.7 sering 429 quota untuk tier gratis, jadi 3.6 paling stabil
                    _priority = {
                        "gemini-3.6-flash": 100,
                        "gemini-3.5-flash": 90,
                        "gemini-3.5-flash-lite": 85,
                        "gemini-3.7-flash": 80,
                        "gemini-3.8-flash": 70,
                        "gemini-3.1-flash-lite": 60,
                    }
                    def _rank(item):
                        _, mid = item
                        return (_priority.get(mid, 0), mid)
                    discovered.sort(key=_rank, reverse=True)
                    if discovered:
                        print(f"[ai] ListModels {ver} discovered (filtered+sorted): {[x[1] for x in discovered[:6]]}")
                        break
                else:
                    tag = _classify_provider_error(r.status_code, r.text[:500])
                    print(f"[ai] ListModels {ver} failed {r.status_code}: {r.text[:200]}")
                    # Key milik user yang invalid -> fail fast dengan pesan jelas (jangan
                    # buang waktu mencoba semua kandidat dengan key yang pasti ditolak).
                    if tag == TAG_BAD_KEY and key_source == "own":
                        _last_ai_error = f"{TAG_BAD_KEY} API key Gemini milik Anda ditolak Google ({_mask_key(api_key)}). Periksa kembali key di Google AI Studio."
                        print(f"[ai] {_last_ai_error}")
                        return None
        except Exception as e:
            print(f"[ai] ListModels {ver} exception: {e}")
    if discovered:
        # prepend discovered, tapi jangan duplikat hardcoded
        raw_candidates = discovered + raw_candidates

    # dedup by (api_version, model) but keep order
    seen = set()
    candidates = []
    for v, m in raw_candidates:
        key = (v, m)
        if key not in seen:
            candidates.append((v, m))
            seen.add(key)

    all_errors = []
    tag_counts = {}
    overloaded_models = set()
    consecutive_overload = 0
    last_err = None
    for api_version, model in candidates:
        # Jika v1 model ini sudah 503 (overload Google), v1beta-nya hampir pasti
        # ikut 503 — lewati agar failover lebih cepat (tanpa auto-retry berulang).
        if api_version == "v1beta" and model in overloaded_models:
            print(f"[ai] skip {api_version}/{model} (v1 sudah 503)")
            continue
        # 3x 503 beruntun = overload sistemik Google, bukan model tertentu.
        # Berhenti cepat dengan pesan jelas (user klik Coba lagi manual 1-2 mnt).
        if consecutive_overload >= 3:
            print("[ai] fail fast: 3x 503 beruntun, stop failover")
            break
        url = f"https://generativelanguage.googleapis.com/{api_version}/models/{model}:generateContent?key={api_key}"

        full_prompt = f"{SYSTEM_BASE}\n\n{user_prompt}"
        max_tokens, candidate_timeout = _budget_for_count(num_questions)
        payload = {
            "contents": [{"parts": [{"text": full_prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": max_tokens
            }
        }

        # hanya Gemini yang support responseMimeType json
        if "gemini" in model:
            payload["generationConfig"]["responseMimeType"] = "application/json"

        try:
            # Timeout per-kandidat: generate normal 10-20 dtk (40 dtk untuk 26-40
            # soal); lebih dari itu kemungkinan hang/overload — lanjut ke kandidat
            # berikut agar total failover tetap di bawah timeout frontend (120 dtk).
            async with httpx.AsyncClient(timeout=candidate_timeout) as client:
                resp = await client.post(url, json=payload)
                if resp.status_code == 200:
                    data = resp.json()
                    try:
                        text = data["candidates"][0]["content"]["parts"][0]["text"]
                        if text and len(text.strip()) > 30:
                            return text
                    except (KeyError, IndexError):
                        if "candidates" in data:
                            return json.dumps(data)
                else:
                    err_text = resp.text[:500]
                    tag = _classify_provider_error(resp.status_code, err_text)
                    if tag:
                        tag_counts[tag] = tag_counts.get(tag, 0) + 1
                    if resp.status_code == 503:
                        overloaded_models.add(model)
                        consecutive_overload += 1
                    else:
                        consecutive_overload = 0
                    last_err = f"{api_version}/{model} -> {resp.status_code}: {err_text[:300]}"
                    all_errors.append(last_err)
                    print(f"[ai] Gemini try failed: {last_err}")
                    # Key milik user yang invalid -> fail fast, jangan coba kandidat lain.
                    if tag == TAG_BAD_KEY and key_source == "own":
                        _last_ai_error = f"{TAG_BAD_KEY} API key Gemini milik Anda ditolak Google ({_mask_key(api_key)}). Periksa kembali key di Google AI Studio."
                        print(f"[ai] {_last_ai_error}")
                        return None
                    # Retry tanpa responseMimeType jika 400 karena mime tidak support
                    if resp.status_code == 400 and "responseMimeType" in err_text and "responseMimeType" in payload.get("generationConfig", {}):
                        payload["generationConfig"].pop("responseMimeType", None)
                        try:
                            resp2 = await client.post(url, json=payload)
                            if resp2.status_code == 200:
                                data2 = resp2.json()
                                try:
                                    text2 = data2["candidates"][0]["content"]["parts"][0]["text"]
                                    if text2 and len(text2.strip()) > 30:
                                        return text2
                                except (KeyError, IndexError):
                                    if "candidates" in data2:
                                        return json.dumps(data2)
                            else:
                                last_err2 = f"{api_version}/{model} retry-no-mime -> {resp2.status_code}: {resp2.text[:300]}"
                                all_errors.append(last_err2)
                                print(f"[ai] Gemini retry failed: {last_err2}")
                        except Exception as e2:
                            print(f"[ai] Gemini retry exception: {e2}")
                    if resp.status_code in (404, 400):
                        continue
                    # 429 / 500 -> coba model lain
                    continue
        except Exception as e:
            last_err = f"{api_version}/{model} exception: {str(e)}"
            all_errors.append(last_err)
            print(f"[ai] Gemini exception: {last_err}")
            # Timeout ke Google biasanya menyertai overload — hitung ke budget.
            if "timeout" in str(e).lower():
                consecutive_overload += 1
            else:
                consecutive_overload = 0
            continue

    # gabung semua error biar 502 tidak cuma tampil last model tapi semua kandidat.
    # Awali dengan tag dominan agar frontend (mapAiError) bisa memetakan ke
    # pesan ramah + tombol aksi yang tepat.
    dominant = None
    if tag_counts.get(TAG_BAD_KEY) and key_source == "own":
        dominant = TAG_BAD_KEY
    elif tag_counts.get(TAG_QUOTA):
        dominant = TAG_QUOTA
    elif tag_counts.get(TAG_BUSY):
        dominant = TAG_BUSY
    if all_errors:
        tail = " | ".join(all_errors[-6:])  # max 6 biar tidak kepanjangan
        _last_ai_error = f"{dominant + ' ' if dominant else ''}Semua model Gemini gagal ({key_source} key {_mask_key(api_key)}): {tail}"
    else:
        _last_ai_error = (dominant + " " if dominant else "") + (last_err or "Semua model Gemini gagal tanpa detail")
    print(f"[ai] All Gemini models failed. Last error: {_last_ai_error}")
    return None


async def _call_openrouter(user_prompt: str, num_questions: int = 10) -> Optional[str]:
    """Fallback ke OpenRouter / Groq (OpenAI-compatible) agar tetap pintar & kritis jika Gemini down."""
    global _last_ai_error
    api_key = os.getenv("OPENROUTER_API_KEY") or os.getenv("GROQ_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("[ai] No OPENROUTER_API_KEY / GROQ_API_KEY set, skip openrouter fallback")
        return None

    # tentukan endpoint & model
    if os.getenv("OPENROUTER_API_KEY"):
        base_url = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        model = os.getenv("OPENROUTER_MODEL", "google/gemini-2.0-flash-exp:free")
        headers_extra = {"HTTP-Referer": os.getenv("FRONTEND_URL", "http://localhost:5173"), "X-Title": "Formax AI"}
    elif os.getenv("GROQ_API_KEY"):
        base_url = "https://api.groq.com/openai/v1"
        model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
        headers_extra = {}
    else:
        base_url = "https://api.openai.com/v1"
        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
        headers_extra = {}

    url = f"{base_url}/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json", **headers_extra}
    full_prompt = f"{SYSTEM_BASE}\n\n{user_prompt}"
    or_tokens, _ = _budget_for_count(num_questions)
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": full_prompt}],
        "temperature": 0.7,
        "max_tokens": min(16384, or_tokens),
        "response_format": {"type": "json_object"} if "gpt" in model or "gemini" in model else None,
    }
    # hapus None
    if payload["response_format"] is None:
        payload.pop("response_format")

    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                text = data["choices"][0]["message"]["content"]
                if text and len(text.strip()) > 30:
                    return text
            # simpan error
            _last_ai_error = f"openrouter/{model} -> {resp.status_code}: {resp.text[:500]}"
            print(f"[ai] OpenRouter failed: {_last_ai_error}")
    except Exception as e:
        _last_ai_error = f"openrouter/{model} exception: {str(e)}"
        print(f"[ai] OpenRouter exception: {_last_ai_error}")
    return None


async def _call_ai(user_prompt: str, gemini_key: Optional[str] = None, key_source: str = "server", num_questions: int = 10) -> Optional[str]:
    """Orchestrator: coba Gemini dulu, baru OpenRouter/Groq fallback."""
    global _last_ai_error
    _last_ai_error = None
    text = await _call_gemini(user_prompt, api_key=gemini_key, key_source=key_source, num_questions=num_questions)
    if text:
        return text
    # Key milik user yang invalid -> fail fast, jangan timpa pesan jelas dengan fallback.
    if key_source == "own" and _last_ai_error and TAG_BAD_KEY in _last_ai_error:
        return None
    # fallback kritis - hanya jika Gemini gagal total
    text2 = await _call_openrouter(user_prompt, num_questions=num_questions)
    if text2:
        return text2
    # tetap None -> akan di-handle fail-loud di generate_form
    return None

# ==================== DYNAMIC SMART FALLBACK MOCK ====================

def _detect_domain(prompt: str) -> str:
    p = prompt.lower()
    if any(k in p for k in ["html", "css", "javascript", "python", "koding", "coding", "pemrograman", "tag ", "elemen html", "informatika", "web dasar"]):
        return "code"
    if any(k in p for k in ["matematika", "math", "aljabar", "geometri", "kalkulus", "persamaan", "kuadrat", "akar"]):
        return "math"
    if any(k in p for k in ["inggris", "english", "grammar", "tense", "vocabulary", "reading"]):
        return "english"
    if any(k in p for k in ["survei", "survey", "kepuasan", "feedback", "layanan", "pelanggan", "evaluasi", "rating"]):
        return "survey"
    if any(k in p for k in ["pendaftaran", "daftar", "registrasi", "form", "biodata", "formulir", "penerimaan"]):
        return "registration"
    if any(k in p for k in ["fisika", "kimia", "biologi", "ipa", "science"]):
        return "science"
    if any(k in p for k in ["sejarah", "history", "pkn", "sosialisasi", "geografi"]):
        return "social"
    return "general"

def _smart_fallback_generator(req: AiGenerateRequest) -> dict:
    domain = _detect_domain(req.prompt)
    seed = abs(hash(req.prompt)) % 10000
    rng = random.Random(seed)

    title = (req.title or "").strip()
    if not title or len(title) < 5:
        if domain == "code":
            title = "Kuis Pemrograman Web — HTML & Dasar Coding"
        elif domain == "math":
            title = "Ujian Matematika — Aljabar & Pemecahan Masalah"
        elif domain == "english":
            title = "English Language Proficiency Quiz"
        elif domain == "survey":
            title = "Survei Kepuasan & Evaluasi Layanan"
        elif domain == "registration":
            title = "Formulir Pendaftaran & Data Peserta"
        elif domain == "science":
            title = "Kuis Ilmu Pengetahuan Alam (IPA)"
        elif domain == "social":
            title = "Ujian Wawasan Sejarah & Kebangsaan"
        else:
            clean_prompt = re.sub(r'buatkan|tolong|buat|form|soal|ujian|kuesioner', '', req.prompt, flags=re.I).strip()
            words = [w.capitalize() for w in clean_prompt.split() if len(w) > 2][:4]
            title = f"Form: {' '.join(words)}" if words else "Form Buatan Formax AI"

    desc = (req.description or "").strip()
    if not desc:
        if domain == "survey":
            desc = "Mohon berikan masukan jujur Anda untuk membantu kami meningkatkan kualitas layanan. Jawaban Anda sangat berharga."
        elif domain == "registration":
            desc = "Isi formulir ini dengan informasi valid. Pastikan semua data terisi dengan benar."
        else:
            desc = f"Formulir ini dibuat otomatis sesuai petunjuk: {req.prompt[:120]}... Mohon kerjakan dengan cermat."

    questions = []

    if req.use_sections:
        questions.append({
            "type": "page_break",
            "label": "Bagian 1: Informasi Identitas",
            "settings": {"description": "Lengkapi identitas diri Anda sebelum memulai.", "shuffle": False},
            "options": []
        })
        questions.append({"type": "text", "label": "Nama Lengkap", "is_required": True, "placeholder": "Masukkan nama lengkap Anda", "settings": {}, "options": []})
        questions.append({"type": "text", "label": "Email / Nomor Telepon", "is_required": True, "placeholder": "contoh@email.com / 0812...", "settings": {}, "options": []})
        if domain in ("registration", "survey"):
            questions.append({"type": "dropdown", "label": "Kategori / Status", "is_required": True, "settings": {}, "options": [{"label": "Mahasiswa / Pelajar", "is_correct": False}, {"label": "Karyawan / Profesional", "is_correct": False}, {"label": "Umum", "is_correct": False}]})
        
        questions.append({
            "type": "page_break",
            "label": "Bagian 2: Soal & Isian Utama",
            "settings": {"description": "Jawablah pertanyaan berikut dengan teliti.", "shuffle": True},
            "options": []
        })

    # Domain Specific Item Banks
    MATH_ITEMS = [
        ("Jika \\(2x + 5 = 15\\), maka nilai \\(x\\) adalah...", ["3", "5", "7", "10"], 1),
        ("Hasil dari \\(3x^2 \\times 4x^3\\) adalah...", ["\\(7x^5\\)", "\\(12x^5\\)", "\\(12x^6\\)", "\\(7x^6\\)"], 1),
        ("Akar-akar dari persamaan kuadrat \\(x^2 - 5x + 6 = 0\\) adalah...", ["\\(x = 2\\) dan \\(x = 3\\)", "\\(x = -2\\) dan \\(x = -3\\)", "\\(x = 1\\) dan \\(x = 6\\)", "\\(x = -1\\) dan \\(x = 6\\)"], 0),
        ("Nilai dari \\(\\sin(30^\\circ) + \\cos(60^\\circ)\\) adalah...", ["\\(0.5\\)", "\\(1\\)", "\\(\\sqrt{3}\\)", "\\(1.5\\)"], 1),
        ("Sebuah persegi panjang memiliki panjang 12 cm dan lebar 5 cm. Panjang diagonalnya adalah...", ["13 cm", "17 cm", "25 cm", "15 cm"], 0),
        ("Turunan pertama dari \\(f(x) = 4x^3 - 2x + 7\\) adalah...", ["\\(f'(x) = 12x^2 - 2\\)", "\\(f'(x) = 12x^3 - 2\\)", "\\(f'(x) = 4x^2 - 2\\)", "\\(f'(x) = 12x^2\\)"], 0),
        ("Hasil matriks \\(\\begin{pmatrix} 2 & 3 \\\\ 1 & 4 \\end{pmatrix}\\) determinannya adalah...", ["5", "11", "8", "6"], 0),
    ]

    ENGLISH_ITEMS = [
        ("She ___ to the library every Wednesday afternoon.", ["go", "goes", "is going", "went"], 1),
        ("Choose the correct passive voice sentence:", ["The report was written by Sarah.", "Sarah wrote the report.", "The report write Sarah.", "Sarah was writing report."], 0),
        ("What is the synonym of the word \"METICULOUS\"?", ["Careless", "Thorough", "Quick", "Lazy"], 1),
        ("If I ___ more time, I would learn a third language.", ["have", "had", "would have", "will have"], 1),
        ("Identify the correctly spelled word:", ["Accommodate", "Acommodate", "Accomodate", "Acomodate"], 0),
        ("Neither the teacher nor the students ___ present at the auditorium.", ["was", "were", "is", "be"], 1),
    ]

    SURVEY_ITEMS = [
        ("Seberapa puas Anda secara keseluruhan terhadap kecepatan layanan kami?", ["Sangat Puas", "Puas", "Netral", "Tidak Puas", "Sangat Tidak Puas"], 0),
        ("Seberapa ramah dan profesional staf kami saat melayani Anda?", ["Sangat Baik", "Baik", "Cukup", "Kurang", "Sangat Kurang"], 0),
        ("Seberapa jelas informasi yang diberikan dalam platform ini?", ["Sangat Jelas", "Cukup Jelas", "Kurang Jelas", "Sangat Tidak Jelas"], 0),
        ("Apakah Anda akan merekomendasikan layanan kami kepada rekan Anda?", ["Pasti Ya", "Mungkin Ya", "Ragu-ragu", "Tidak"], 0),
    ]

    REGISTRATION_ITEMS = [
        ("Tanggal Lahir / Tanggal Pelaksanaan", [], 0, "date"),
        ("Instansi / Organisasi / Asal Sekolah", [], 0, "text"),
        ("Upload Bukti Identitas / Dokumen Pendukung", [], 0, "file_upload"),
    ]

    CODE_ITEMS = [
        ("Apa fungsi tag &lt;p&gt; pada HTML?", ['<code>&lt;p&gt;</code> membuat paragraf teks', '<code>&lt;p&gt;</code> membuat gambar', '<code>&lt;p&gt;</code> membuat tabel', '<code>&lt;p&gt;</code> membuat link'], 0),
        ("Manakah penulisan elemen &lt;div class=&quot;container&quot;&gt; yang benar?", ['<code>&lt;div class=&quot;container&quot;&gt;</code>', '<code>&lt;div container&gt;</code>', '<code>&lt;division class=&quot;container&quot;&gt;</code>', '<code>&lt;div=&quot;container&quot;&gt;</code>'], 0),
        ("Tag HTML yang tepat untuk membuat tabel adalah...", ['<code>&lt;table&gt;</code>', '<code>&lt;tab&gt;</code>', '<code>&lt;grid&gt;</code>', '<code>&lt;form&gt;</code>'], 0),
        ("Perhatikan kode berikut:<pre><code class=\"language-html\">&lt;a href=\"https://contoh.id\"&gt;Kunjungi&lt;/a&gt;</code></pre>Atribut href berfungsi untuk...", ["Menentukan tujuan link", "Mengubah warna teks", "Membuat tabel", "Menyisipkan gambar"], 0),
        ("Tag &lt;img&gt; membutuhkan atribut wajib berupa...", ['<code>src</code> dan <code>alt</code>', '<code>href</code> dan <code>link</code>', '<code>class</code> saja', '<code>id</code> saja'], 0),
        ("Perhatikan kode berikut:<pre><code class=\"language-html\">&lt;ul&gt;\n  &lt;li&gt;Apel&lt;/li&gt;\n  &lt;li&gt;Jeruk&lt;/li&gt;\n&lt;/ul&gt;</code></pre>Hasil tampilan kode tersebut adalah...", ["Daftar bullet (tidak bernomor)", "Daftar bernomor", "Tabel 2 kolom", "Formulir input"], 0),
    ]

    # Select pool
    if domain == "code":
        pool = CODE_ITEMS
    elif domain == "math":
        pool = MATH_ITEMS
    elif domain == "english":
        pool = ENGLISH_ITEMS
    elif domain == "survey":
        pool = SURVEY_ITEMS
    else:
        pool = MATH_ITEMS + ENGLISH_ITEMS

    rng.shuffle(pool)

    needed = req.num_questions
    added = 0

    for i in range(needed):
        if domain == "registration" and i < len(REGISTRATION_ITEMS):
            label, opts, c_idx, q_type = REGISTRATION_ITEMS[i]
            questions.append({
                "type": q_type,
                "label": label,
                "is_required": True,
                "placeholder": f"Masukkan {label.lower()}",
                "settings": {},
                "options": []
            })
            added += 1
            continue

        if i < len(pool):
            item = pool[i % len(pool)]
            q_text = item[0]
            opts_text = item[1]
            correct_idx = item[2]
        else:
            q_text = f"Pertanyaan evaluasi ke-{i+1} mengenai konteks prompt..."
            opts_text = ["Opsi A (Sesuai)", "Opsi B (Alternatif)", "Opsi C (Variasi)", "Opsi D (Lainnya)"]
            correct_idx = 0

        options = []
        for idx, opt_label in enumerate(opts_text):
            options.append({
                "label": opt_label,
                "is_correct": req.include_correct and (idx == correct_idx)
            })

        q_type = req.prefer_type if (req.prefer_type and req.prefer_type != "auto") else "single_choice"
        if q_type not in ALLOWED_TYPES or q_type == "page_break":
            q_type = "single_choice" if opts_text else "text"

        questions.append({
            "type": q_type,
            "label": q_text,
            "is_required": True,
            "placeholder": "",
            "settings": {},
            "options": options if q_type in ("single_choice", "checkbox", "dropdown") else []
        })
        added += 1

    return {"title": title, "description": desc, "questions": questions}

def _visible_text_len(s: str) -> int:
    """Panjang teks terlihat (strip tag + unescape entities) agar label code
    seperti '&lt;div&gt;' tidak dianggap kosong."""
    if not s:
        return 0
    t = re.sub(r"<[^>]+>", "", s)
    t = _html_mod.unescape(t).strip()
    return len(t)


def _safe_truncate(s: str, limit: int) -> str:
    """Potong string tanpa memenggal tag/entity HTML di tengah."""
    if not s or len(s) <= limit:
        return s
    cut = s[:limit]
    # Jangan potong di dalam tag <...>
    lt, gt = cut.rfind("<"), cut.rfind(">")
    if lt > gt:
        cut = cut[:lt]
    # Jangan potong di dalam entity &...;
    amp, semi = cut.rfind("&"), cut.rfind(";")
    if amp > semi and amp > len(cut) - 10:
        cut = cut[:amp]
    # Tutup tag code/pre yang terpotong agar markup tetap valid
    low = cut.lower()
    if "<code" in low and "</code>" not in low:
        cut += "</code>"
    if "<pre" in low and "</pre>" not in low:
        cut += "</pre>"
    return cut


def _validate_and_normalize(raw_questions: list, num_questions: int, use_sections: bool) -> List[dict]:
    out = []
    question_count = 0

    for q in raw_questions:
        if not isinstance(q, dict):
            continue

        t = str(q.get("type") or "").strip().lower()
        alias_map = {
            "multiple_choice": "single_choice",
            "choice": "single_choice",
            "radio": "single_choice",
            "essay": "paragraph",
            "short_answer": "text",
            "section": "page_break",
            "header": "page_break",
            "upload": "file_upload",
            "file": "file_upload"
        }
        t = alias_map.get(t, t)
        if t not in ALLOWED_TYPES:
            t = "text"

        label = _normalize_code_html(str(q.get("label") or "").strip())
        if not label or _visible_text_len(label) < 2:
            continue

        # Clean AI slop artifacts from labels
        if any(bad in label.lower() for bad in ["buatkan saya form", "prompt user:", "system base", "json schema"]):
            continue

        if t == "page_break":
            if not use_sections:
                continue
            if out and out[-1].get("type") == "page_break":
                continue
            out.append({
                "type": "page_break",
                "label": label[:2000],
                "is_required": False,
                "placeholder": "",
                "settings": {
                    "description": _normalize_code_html(str(q.get("settings", {}).get("description") or ""))[:2000],
                    "shuffle": bool(q.get("settings", {}).get("shuffle", True))
                },
                "options": []
            })
            continue

        if question_count >= num_questions:
            continue

        opts = q.get("options") or []
        norm_opts = []
        if t in ("single_choice", "checkbox", "dropdown"):
            for o in opts[:5]:
                if not isinstance(o, dict):
                    continue
                o_label = _normalize_code_html(str(o.get("label") or "").strip())
                if not o_label or _visible_text_len(o_label) < 1 or o_label.lower().startswith("opsi a soal") or o_label.lower().startswith("jawaban 1"):
                    continue
                norm_opts.append({
                    "label": _safe_truncate(o_label, 2000),
                    "is_correct": bool(o.get("is_correct", False))
                })

            # Ensure at least 2 valid options if choices empty
            if not norm_opts:
                norm_opts = [
                    {"label": "Opsi A", "is_correct": True},
                    {"label": "Opsi B", "is_correct": False}
                ]

        out.append({
            "type": t,
            "label": _safe_truncate(label, 4000),
            "is_required": bool(q.get("is_required", True)),
            "placeholder": _normalize_code_html(str(q.get("placeholder") or ""))[:150],
            "settings": {k: (_normalize_code_html(v) if isinstance(v, str) else v) for k, v in (q.get("settings") if isinstance(q.get("settings"), dict) else {}).items()},
            "options": norm_opts if t in ("single_choice", "checkbox", "dropdown") else []
        })
        question_count += 1

    # Remove trailing page_break
    while out and out[-1].get("type") == "page_break":
        out.pop()

    return out

@router.post("/generate-form", response_model=AiGenerateOut)
async def generate_form(
    payload: AiGenerateRequest,
    current_user: models.User = Depends(get_current_user),
    x_gemini_api_key: Optional[str] = Header(default=None, alias="X-Gemini-API-Key"),
):
    is_valid, err_msg = validate_prompt(payload.prompt)
    if not is_valid:
        raise HTTPException(status_code=400, detail=err_msg or "Prompt tidak valid atau terdeteksi ketikan acak.")

    _check_rate_limit(str(current_user.id))

    # BYOK: kunci Gemini milik user (header) lebih diutamakan dari env server.
    gemini_key, key_source, key_err = _resolve_gemini_key(x_gemini_api_key)
    if key_err:
        raise HTTPException(status_code=400, detail=key_err)

    # Cek apakah pengguna meminta jumlah soal eksplisit dalam prompt teks
    extracted_count = extract_question_count(payload.prompt)
    effective_num_questions = extracted_count if extracted_count is not None else payload.num_questions

    title = (payload.title or "").strip()
    description = (payload.description or "").strip()
    user_prompt = _build_user_prompt(payload, effective_num_questions)

    raw_text = await _call_ai(user_prompt, gemini_key=gemini_key, key_source=key_source, num_questions=effective_num_questions)

    if raw_text is None:
        # Fail loudly (opsi A) — jangan silent fallback bodoh; tanpa auto-retry.
        detail = _last_ai_error or "Semua model AI gagal. Periksa GEMINI_API_KEY dan koneksi."
        # beri hint spesifik untuk kasus 404 model lama
        if "404" in detail and "1.5-flash" in detail:
            detail += " | Hint: model gemini-1.5-flash/2.5-flash sudah di-retire. Set GEMINI_MODEL=gemini-3.6-flash di .env / Vercel env."
        raise HTTPException(status_code=502, detail=f"AI gagal generate (bukan fallback): {detail}")

    cleaned = _repair_json(raw_text)
    try:
        data = _loads_lenient(cleaned)
    except Exception:
        try:
            cleaned2 = _repair_json(raw_text[raw_text.find("{"):])
            data = _loads_lenient(cleaned2)
        except Exception as je:
            # Fail loudly + beri konteks lokasi rusak agar bisa didiagnosis.
            pos = getattr(je, "pos", None)
            if isinstance(pos, int):
                window = _error_window(cleaned, pos)
                loc = f" (karakter {pos}, potongan: ...{window}...)"
            else:
                loc = f" Raw snippet: {raw_text[:500]}"
            raise HTTPException(
                status_code=502,
                detail=f"{TAG_BAD_JSON} AI mengembalikan format rusak.{loc} | parse error: {je} | Silakan klik Generate ulang, atau sederhanakan prompt."
            )

    gen_title = _safe_truncate(_normalize_code_html(str(data.get("title") or title or "Form Buatan Formax AI").strip()), 200)
    gen_desc = _safe_truncate(_normalize_code_html(str(data.get("description") or description or "").strip()), 3000)
    raw_questions = data.get("questions") or data.get("items") or []

    if not isinstance(raw_questions, list) or len(raw_questions) == 0:
        raise HTTPException(
            status_code=502,
            detail=f"AI tidak mengembalikan questions. Raw: {raw_text[:500]}"
        )

    questions = _validate_and_normalize(raw_questions, effective_num_questions, payload.use_sections)

    if len([q for q in questions if q["type"] != "page_break"]) == 0:
        raise HTTPException(
            status_code=502,
            detail=f"AI questions kosong setelah validasi. Raw: {raw_text[:500]}"
        )

    return AiGenerateOut(
        title=gen_title,
        description=gen_desc,
        questions=questions,
        usage={"model": os.getenv("GEMINI_MODEL", "gemini-3.6-flash"), "prompt_chars": len(payload.prompt), "key_source": key_source, "requested": effective_num_questions, "returned": len([q for q in questions if q["type"] != "page_break"])},
    )


class ValidateKeyOut(BaseModel):
    valid: bool
    models: List[str] = []
    key_suffix: str = ""


@router.post("/validate-key", response_model=ValidateKeyOut)
async def validate_gemini_key(
    current_user: models.User = Depends(get_current_user),
    x_gemini_api_key: Optional[str] = Header(default=None, alias="X-Gemini-API-Key"),
):
    """Cek API key Gemini milik user via ListModels (tanpa menghabiskan kuota generate)."""
    _check_rate_limit(str(current_user.id), limit=30)
    gemini_key, key_source, key_err = _resolve_gemini_key(x_gemini_api_key)
    if key_err or not gemini_key or key_source != "own":
        raise HTTPException(status_code=400, detail=key_err or "Tempel API key Gemini Anda di header X-Gemini-API-Key.")
    found: List[str] = []
    last_status: Optional[int] = None
    last_body = ""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            for ver in ("v1", "v1beta"):
                try:
                    r = await client.get(f"https://generativelanguage.googleapis.com/{ver}/models?key={gemini_key}")
                except Exception as e:
                    last_body = str(e)
                    continue
                last_status = r.status_code
                last_body = r.text[:300]
                if r.status_code == 200:
                    try:
                        j = r.json()
                    except Exception:
                        continue
                    for m in j.get("models", []):
                        name = m.get("name", "")
                        mid = name.split("/")[-1] if "/" in name else name
                        if "generateContent" in (m.get("supportedGenerationMethods") or []):
                            if "flash" in mid or "pro" in mid or "gemma" in mid:
                                found.append(mid)
                    if found:
                        break
                elif _classify_provider_error(r.status_code, r.text[:500]) == TAG_BAD_KEY:
                    raise HTTPException(status_code=401, detail=f"{TAG_BAD_KEY} API key ditolak Google. Periksa kembali key di Google AI Studio.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"{TAG_BUSY} Gagal menghubungi Google: {e}")
    if not found:
        tag = _classify_provider_error(last_status or 0, last_body)
        if tag == TAG_BAD_KEY:
            raise HTTPException(status_code=401, detail=f"{TAG_BAD_KEY} API key ditolak Google. Periksa kembali key di Google AI Studio.")
        raise HTTPException(status_code=502, detail=f"{tag + ' ' if tag else ''}Google tidak mengembalikan daftar model (HTTP {last_status}). Coba lagi nanti.")
    seen = set()
    uniq = [m for m in found if not (m in seen or seen.add(m))]
    print(f"[ai] validate-key ok ({_mask_key(gemini_key)}): {len(uniq)} models")
    return ValidateKeyOut(valid=True, models=uniq[:20], key_suffix=_mask_key(gemini_key))


@router.post("/extract-file")
async def extract_file_content(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user)
):
    _check_rate_limit(str(current_user.id), limit=30)
    filename = (file.filename or "").lower()
    data = await file.read()
    if len(data) > 8 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Ukuran file maksimal 8 MB")

    text_content = ""
    if filename.endswith(".docx"):
        try:
            import docx
            doc = docx.Document(io.BytesIO(data))
            paragraphs = [p.text.strip() for p in doc.paragraphs if p.text.strip()]
            # Also extract tables if present
            for table in doc.tables:
                for row in table.rows:
                    row_text = " | ".join(c.text.strip() for c in row.cells if c.text.strip())
                    if row_text:
                        paragraphs.append(row_text)
            text_content = "\n".join(paragraphs)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Gagal membaca file .docx: {str(e)}")
    elif filename.endswith((".txt", ".md", ".csv", ".json", ".tsv", ".yaml", ".yml")):
        try:
            text_content = data.decode("utf-8", errors="ignore").strip()
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Gagal membaca teks file: {str(e)}")
    else:
        raise HTTPException(status_code=400, detail="Format file tidak didukung. Gunakan .docx, .txt, .md, .csv, atau .json")

    if not text_content or not text_content.strip():
        raise HTTPException(status_code=400, detail="File kosong atau tidak mengandung teks yang dapat dibaca.")

    # Limit extracted context to 15,000 characters
    trimmed_text = text_content.strip()[:15000]
    return {
        "filename": file.filename,
        "text": trimmed_text,
        "char_count": len(trimmed_text),
        "preview": trimmed_text[:150] + ("..." if len(trimmed_text) > 150 else "")
    }

