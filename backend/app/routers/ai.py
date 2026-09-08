import os
import json
import re
import time
import random
from typing import Optional, List

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..deps import get_current_user
from .. import models

router = APIRouter(prefix="/ai", tags=["ai"])

_rate_store = {}

def _check_rate_limit(user_id: str, limit: int = 15, window_sec: int = 60):
    now = time.time()
    lst = _rate_store.get(user_id, [])
    lst = [t for t in lst if now - t < window_sec]
    if len(lst) >= limit:
        raise HTTPException(status_code=429, detail="Terlalu banyak permintaan AI. Silakan tunggu 1 menit.")
    lst.append(now)
    _rate_store[user_id] = lst

class AiGenerateRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=120)
    description: Optional[str] = Field(None, max_length=2000)
    prompt: str = Field(..., min_length=10, max_length=4000)
    num_questions: int = Field(10, ge=3, le=30)
    include_correct: bool = True
    use_sections: bool = True
    prefer_type: Optional[str] = None

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

def _build_user_prompt(req: AiGenerateRequest) -> str:
    title_hint = f"Judul form spesifik: {req.title}" if req.title else "Judul form: Buatkan judul profesional & menarik sesuai konteks prompt."
    desc_hint = f"Deskripsi form spesifik: {req.description}" if req.description else "Deskripsi: Generate 1-2 kalimat petunjuk pengisian yang ramah & jelas."
    correct_hint = "KUNCI JAWABAN: Wajib tandai tepat 1 opsi benar (is_correct: true) untuk tiap soal pilihan ganda (single_choice)." if req.include_correct else "KUNCI JAWABAN: Matikan kunci jawaban, semua is_correct: false."
    section_hint = "BAGIAN (SECTION): Gunakan page_break untuk memisahkan Bagian 1 (Identitas/Info) dan Bagian 2 (Soal/Evaluasi). Beri label bagian & deskripsi yang pas." if req.use_sections else "BAGIAN (SECTION): Jangan gunakan page_break, susun pertanyaan secara mendatar (flat)."
    type_hint = f"PREFER TYPE: Utamakan penggunaan tipe {req.prefer_type} untuk soal utama." if req.prefer_type and req.prefer_type != "auto" else "TIPE SOAL: Variasikan tipe soal secara logis sesuai konteks (single_choice untuk kuis, text/dropdown untuk identitas, paragraph untuk esai)."
    
    return f"""{title_hint}
{desc_hint}
Prompt Pengguna: "{req.prompt}"
Target Jumlah Soal (tidak menghitung page_break): {req.num_questions} soal
{correct_hint}
{section_hint}
{type_hint}

PENTING:
- Buat tepat {req.num_questions} pertanyaan utama (di luar type page_break).
- Seluruh teks dalam bahasa yang sama dengan prompt pengguna.
- Hasilkan JSON murni sesuai schema.
"""

def _repair_json(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    m = re.search(r"\{[\s\S]*\}", text)
    if m:
        return m.group(0)
    return text

# last error string for fail-loud response (set by _call_gemini / _call_openrouter)
_last_ai_error: Optional[str] = None


async def _call_gemini(user_prompt: str) -> Optional[str]:
    global _last_ai_error
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        _last_ai_error = "GEMINI_API_KEY belum di-set di environment"
        print(f"[ai] {_last_ai_error}")
        return None

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
                    print(f"[ai] ListModels {ver} failed {r.status_code}: {r.text[:200]}")
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
    last_err = None
    for api_version, model in candidates:
        url = f"https://generativelanguage.googleapis.com/{api_version}/models/{model}:generateContent?key={api_key}"

        full_prompt = f"{SYSTEM_BASE}\n\n{user_prompt}"
        payload = {
            "contents": [{"parts": [{"text": full_prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 8192
            }
        }

        # hanya Gemini yang support responseMimeType json
        if "gemini" in model:
            payload["generationConfig"]["responseMimeType"] = "application/json"

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
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
                    last_err = f"{api_version}/{model} -> {resp.status_code}: {err_text[:300]}"
                    all_errors.append(last_err)
                    print(f"[ai] Gemini try failed: {last_err}")
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
            continue

    # gabung semua error biar 502 tidak cuma tampil last model (1.5-flash-latest) tapi semua kandidat
    if all_errors:
        _last_ai_error = " | ".join(all_errors[-6:])  # max 6 biar tidak kepanjangan
    else:
        _last_ai_error = last_err or "Semua model Gemini gagal tanpa detail"
    print(f"[ai] All Gemini models failed. Last error: {_last_ai_error}")
    return None


async def _call_openrouter(user_prompt: str) -> Optional[str]:
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
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": full_prompt}],
        "temperature": 0.7,
        "max_tokens": 4096,
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


async def _call_ai(user_prompt: str) -> Optional[str]:
    """Orchestrator: coba Gemini dulu, baru OpenRouter/Groq fallback."""
    global _last_ai_error
    _last_ai_error = None
    text = await _call_gemini(user_prompt)
    if text:
        return text
    # fallback kritis - hanya jika Gemini gagal total
    text2 = await _call_openrouter(user_prompt)
    if text2:
        return text2
    # tetap None -> akan di-handle fail-loud di generate_form
    return None

# ==================== DYNAMIC SMART FALLBACK MOCK ====================

def _detect_domain(prompt: str) -> str:
    p = prompt.lower()
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
        if domain == "math":
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

    # Select pool
    if domain == "math":
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

        label = str(q.get("label") or "").strip()
        if not label or len(label) < 2:
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
                "label": label[:120],
                "is_required": False,
                "placeholder": "",
                "settings": {
                    "description": str(q.get("settings", {}).get("description") or "")[:300],
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
                o_label = str(o.get("label") or "").strip()
                if not o_label or o_label.lower().startswith("opsi a soal") or o_label.lower().startswith("jawaban 1"):
                    continue
                norm_opts.append({
                    "label": o_label[:300],
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
            "label": label[:600],
            "is_required": bool(q.get("is_required", True)),
            "placeholder": str(q.get("placeholder") or "")[:150],
            "settings": q.get("settings") if isinstance(q.get("settings"), dict) else {},
            "options": norm_opts if t in ("single_choice", "checkbox", "dropdown") else []
        })
        question_count += 1

    # Remove trailing page_break
    while out and out[-1].get("type") == "page_break":
        out.pop()

    return out

@router.post("/generate-form", response_model=AiGenerateOut)
async def generate_form(payload: AiGenerateRequest, current_user: models.User = Depends(get_current_user)):
    _check_rate_limit(str(current_user.id))

    title = (payload.title or "").strip()
    description = (payload.description or "").strip()
    user_prompt = _build_user_prompt(payload)

    raw_text = await _call_ai(user_prompt)

    if raw_text is None:
        # Fail loudly (opsi A) — jangan silent fallback bodoh
        detail = _last_ai_error or "Semua model AI gagal. Periksa GEMINI_API_KEY dan koneksi."
        # beri hint spesifik untuk kasus 404 model lama
        if "404" in detail and "1.5-flash" in detail:
            detail += " | Hint: model gemini-1.5-flash/2.5-flash sudah di-retire. Set GEMINI_MODEL=gemini-3.6-flash di .env / Vercel env."
        raise HTTPException(status_code=502, detail=f"AI gagal generate (bukan fallback): {detail}")

    cleaned = _repair_json(raw_text)
    try:
        data = json.loads(cleaned)
    except Exception:
        try:
            cleaned2 = _repair_json(raw_text[raw_text.find("{"):])
            data = json.loads(cleaned2)
        except Exception as je:
            # Fail loudly — jangan jatuh ke template bodoh
            raise HTTPException(
                status_code=502,
                detail=f"AI mengembalikan JSON tidak valid (bukan fallback). Raw snippet: {raw_text[:500]} | parse error: {je}"
            )

    gen_title = str(data.get("title") or title or "Form Buatan Formax AI").strip()[:120]
    gen_desc = str(data.get("description") or description or "").strip()[:2000]
    raw_questions = data.get("questions") or data.get("items") or []

    if not isinstance(raw_questions, list) or len(raw_questions) == 0:
        raise HTTPException(
            status_code=502,
            detail=f"AI tidak mengembalikan questions. Raw: {raw_text[:500]}"
        )

    questions = _validate_and_normalize(raw_questions, payload.num_questions, payload.use_sections)

    if len([q for q in questions if q["type"] != "page_break"]) == 0:
        raise HTTPException(
            status_code=502,
            detail=f"AI questions kosong setelah validasi. Raw: {raw_text[:500]}"
        )

    return AiGenerateOut(
        title=gen_title,
        description=gen_desc,
        questions=questions,
        usage={"model": os.getenv("GEMINI_MODEL", "gemini-3.6-flash"), "prompt_chars": len(payload.prompt)}
    )
