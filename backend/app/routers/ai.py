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

def _check_rate_limit(user_id: str, limit: int = 10, window_sec: int = 60):
    now = time.time()
    lst = _rate_store.get(user_id, [])
    lst = [t for t in lst if now - t < window_sec]
    if len(lst) >= limit:
        raise HTTPException(status_code=429, detail="Terlalu banyak permintaan, coba lagi dalam 1 menit")
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

ALLOWED_TYPES = {"text","paragraph","single_choice","checkbox","dropdown","date","file_upload","page_break"}

# Pintar: system prompt dengan few-shot example
SYSTEM_BASE = """You are Formax AI — expert form generator for Form4X platform.
CRITICAL: Output MUST be valid JSON only, no markdown, no explanation. Strictly follow schema.
Follow prompt language (ikut bahasa prompt user). If prompt Indonesian, output Indonesian. If English, output English.

Schema:
{
  "title": "string 5-80 chars - catchy form title",
  "description": "string 20-300 chars - engaging description",
  "questions": [
    {"type":"page_break","label":"Bagian 1: Informasi Pribadi","settings":{"description":"Isi data diri dengan benar","shuffle":false}},
    {"type":"text","label":"Nama Lengkap","is_required":true,"placeholder":"Masukkan nama lengkap","settings":{},"options":[]},
    {"type":"single_choice","label":"Soal ...?","is_required":true,"settings":{},"options":[{"label":"Jawaban A","is_correct":true},{"label":"Jawaban B","is_correct":false},{"label":"Jawaban C","is_correct":false},{"label":"Jawaban D","is_correct":false}]}
  ]
}

Rules:
- type: text, paragraph, single_choice, checkbox, dropdown, date, file_upload, page_break. Default: text for isian, single_choice for pilihan ganda.
- page_break = section header. If use_sections true and prompt has 2 contexts (biodata + soal), create page_break per Bagian. Else 0-1 page_break. Never 2 page_break consecutive.
- For single_choice/checkbox/dropdown: options 3-4, exactly 1 is_correct true if include_correct true, else all false. Make options plausible & distinct, not "Opsi A Soal 1".
- is_required true for important questions.
- Shuffle: for exam, set page_break settings.shuffle true for Bagian Soal.
- label must be complete question/sentence, not "Soal 1: prompt..." - make it real question content.
- Output JSON valid.

Example 1 - Prompt: "Buatkan ujian bahasa Inggris kelas 10, 2 Bagian: biodata & 5 soal tenses"
Output:
{
  "title": "Ujian Bahasa Inggris Kelas 10 - Tenses",
  "description": "Ujian untuk mengukur pemahaman tenses dasar. Kerjakan dengan teliti, waktu 30 menit.",
  "questions": [
    {"type":"page_break","label":"Bagian 1: Informasi Pribadi","settings":{"description":"Isi data diri dengan benar","shuffle":false}},
    {"type":"text","label":"Nama Lengkap","is_required":true,"placeholder":"Masukkan nama","settings":{},"options":[]},
    {"type":"text","label":"Kelas","is_required":true,"settings":{},"options":[]},
    {"type":"page_break","label":"Bagian 2: Soal Bahasa Inggris","settings":{"description":"Pilih jawaban yang paling tepat","shuffle":true}},
    {"type":"single_choice","label":"She ___ to school every day.","is_required":true,"settings":{},"options":[{"label":"go","is_correct":false},{"label":"goes","is_correct":true},{"label":"going","is_correct":false},{"label":"gone","is_correct":false}]},
    {"type":"single_choice","label":"What is the past tense of \\"go\\"?","is_required":true,"settings":{},"options":[{"label":"goed","is_correct":false},{"label":"went","is_correct":true},{"label":"gone","is_correct":false},{"label":"going","is_correct":false}]}
  ]
}

Example 2 - Prompt: "Make English exam about daily activities, 5 multiple choice"
Output:
{
  "title": "Daily Activities - English Quiz",
  "description": "Test your understanding of daily routines vocabulary.",
  "questions": [
    {"type":"single_choice","label":"What do you do in the morning?","is_required":true,"settings":{},"options":[{"label":"I brush my teeth","is_correct":true},{"label":"I sleep at night","is_correct":false}] }
  ]
}
"""

def _build_user_prompt(req: AiGenerateRequest) -> str:
    title_hint = f"Judul form: {req.title}" if req.title else "Judul form: generate kreatif sesuai prompt"
    desc_hint = f"Deskripsi form: {req.description}" if req.description else "Deskripsi: generate menarik 1-2 kalimat"
    correct_hint = "Sertakan kunci jawaban (is_correct) untuk soal pilihan ganda, 1 benar per soal." if req.include_correct else "Jangan sertakan kunci jawaban, semua is_correct false."
    section_hint = "Gunakan page_break untuk tiap Bagian (mis. Bagian 1: Informasi Pribadi, Bagian 2: Soal Ujian) dengan label dan settings.description + shuffle true untuk Bagian Soal." if req.use_sections else "Jangan gunakan page_break, buat flat questions saja."
    type_hint = f"Prefer type: {req.prefer_type}" if req.prefer_type and req.prefer_type != "auto" else "Pilih type paling cocok per soal."
    return f"{title_hint}\n{desc_hint}\nPrompt user: {req.prompt}\nJumlah soal yang diminta (hanya hitung type bukan page_break): {req.num_questions}\n{correct_hint}\n{section_hint}\n{type_hint}\nIkut bahasa prompt user.\n\n{SYSTEM_BASE}"

def _repair_json(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    m = re.search(r"\{[\s\S]*\}", text)
    if m:
        return m.group(0)
    return text

async def _call_gemini(prompt: str) -> str:
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY belum dikonfigurasi di server")
    # coba beberapa model dan versi API, paling hemat dulu
    candidates = [
        ("v1", os.getenv("GEMINI_MODEL", "gemini-flash-latest")),
        ("v1", "gemini-2.0-flash-lite"),
        ("v1beta", "gemini-flash-latest"),
        ("v1", "gemini-1.5-flash"),
        ("v1", "gemini-pro"),
    ]
    # hilangkan duplikat sambil preserve order
    seen = set()
    uniq = []
    for v,m in candidates:
        if m not in seen:
            uniq.append((v,m))
            seen.add(m)
    last_err = None
    for api_version, model in uniq:
        url = f"https://generativelanguage.googleapis.com/{api_version}/models/{model}:generateContent?key={api_key}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.8,
                "maxOutputTokens": 3000,
            }
        }
        # coba 2x: pertama tanpa responseMimeType, kedua dengan
        for attempt in range(2):
            try:
                if attempt == 1:
                    payload["generationConfig"]["responseMimeType"] = "application/json"
                async with httpx.AsyncClient(timeout=25) as client:
                    resp = await client.post(url, json=payload)
                    if resp.status_code == 200:
                        data = resp.json()
                        try:
                            text = data["candidates"][0]["content"]["parts"][0]["text"]
                            if text and len(text.strip()) > 20:
                                return text
                        except Exception:
                            return json.dumps(data)
                    else:
                        last_err = f"{model} {resp.status_code} {resp.text[:400]}"
                        # jika 404 model not found, coba model berikutnya
                        if resp.status_code in (404, 503):
                            break
                        # 429 quota, 400 bad request -> break ke fallback
                        if resp.status_code >= 400:
                            break
            except httpx.HTTPStatusError as e:
                last_err = str(e)
                break
            except Exception as e:
                last_err = str(e)
                break
        # jika sudah coba dan gagal, lanjut ke model berikutnya
        if last_err and "503" in last_err and "high demand" in last_err:
            # tunggu sebentar sebelum coba model lain
            time.sleep(0.5)
            continue
    # semua model gagal -> fallback
    print(f"[ai] all gemini models failed last_err={last_err}, fallback mock")
    return None

# ============== SMART MOCK (pintar, tidak ngaco) ==============
ENGLISH_BANK = [
    ("What is the past tense of \"go\"?", ["goed","went","gone","going"], 1),
    ("She ___ to school every day.", ["go","goes","going","gone"], 1),
    ("Choose the correct sentence:", ["She don't like apples","She doesn't like apples","She not like apples","She no like apples"], 1),
    ("What is the synonym of \"happy\"?", ["sad","joyful","angry","tired"], 1),
    ("___ apple a day keeps the doctor away.", ["A","An","The","No article"], 1),
    ("I have ___ finished my homework.", ["already","yet","still","ever"], 0),
    ("Which word is an adjective?", ["quickly","beautiful","run","happiness"], 1),
    ("He ___ playing football when it started to rain.", ["was","were","is","are"], 0),
    ("What is the opposite of \"easy\"?", ["simple","difficult","hard","tough"], 1),
    ("___ you help me, please?", ["Could","Must","Should to","Ought"], 0),
    ("The book ___ on the table.", ["is","are","be","been"], 0),
    ("We ___ to the cinema yesterday.", ["go","went","gone","going"], 1),
    ("Choose the correctly spelled word:", ["Accomodate","Accommodate","Acommodate","Accomodete"], 1),
    ("What does \"break a leg\" mean?", ["Good luck","Be careful","Take a rest","Hurry up"], 0),
    ("If it rains, we ___ at home.", ["stay","will stay","stayed","staying"], 1),
]

MATH_BANK = [
    ("Hasil dari 7 × 8 adalah...", ["54","56","64","48"], 1),
    ("Nilai x jika 2x + 3 = 11 adalah...", ["2","4","5","3"], 1),
    ("Luas persegi dengan sisi 5 cm adalah...", ["10 cm²","15 cm²","25 cm²","20 cm²"], 2),
    ("Hasil dari 15 ÷ 3 + 2 × 4 = ...", ["13","14","18","11"], 0),
    ("Bilangan prima berikut adalah...", ["9","15","13","21"], 2),
]

INDO_BANK = [
    ("Apa sinonim kata \"indah\"?", ["cantik","buruk","jelek","kotor"], 0),
    ("Kalimat efektif adalah...", ["Saya pergi ke pasar kemarin","Kemarin saya pergi ke pasar kemarin","Saya pergi ke pasar kemarin sore hari","Pergi saya ke pasar"], 1),
]

def _detect_subject(prompt: str) -> str:
    p = prompt.lower()
    if any(k in p for k in ["bahasa inggris","english","inggris","tenses","grammar","vocabulary"]):
        return "english"
    if any(k in p for k in ["matematika","math","aljabar","geometri","bilangan"]):
        return "math"
    if any(k in p for k in ["bahasa indonesia","b. indonesia"]):
        return "indo"
    if any(k in p for k in ["ipa","fisika","biologi"]):
        return "ipa"
    return "general"

def _fallback_mock(req: AiGenerateRequest) -> dict:
    subject = _detect_subject(req.prompt)
    # judul pintar
    title = (req.title or "").strip()
    if not title or len(title) < 5:
        if subject == "english":
            title = "Ujian Bahasa Inggris - Daily & Grammar"
        elif subject == "math":
            title = "Ujian Matematika - Aljabar & Aritmatika"
        elif subject == "indo":
            title = "Ujian Bahasa Indonesia"
        else:
            # ambil 5 kata pertama prompt
            words = [w for w in req.prompt.strip().split() if len(w) > 2][:5]
            title = " ".join(w.capitalize() for w in words)[:60] or "Form Buatan AI"
            if "ujian" not in title.lower() and "form" not in title.lower():
                title = f"Form: {title}"
    desc = (req.description or "").strip()
    if not desc:
        if subject == "english":
            desc = "Ujian untuk mengukur pemahaman bahasa Inggris dasar. Kerjakan dengan teliti."
        elif subject == "math":
            desc = "Ujian matematika untuk mengukur kemampuan berhitung dan logika."
        else:
            desc = f"Form otomatis dari prompt: {req.prompt[:100]}..."
    questions = []
    # Bagian 1 biodata jika use_sections
    if req.use_sections:
        questions.append({"type":"page_break","label":"Bagian 1: Informasi Pribadi","settings":{"description":"Isi data diri dengan lengkap dan benar.","shuffle":False},"options":[]})
        questions.append({"type":"text","label":"Nama Lengkap","is_required":True,"placeholder":"Masukkan nama lengkap","settings":{},"options":[]})
        questions.append({"type":"text","label":"Kelas / Email","is_required":True,"placeholder":"","settings":{},"options":[]})
        questions.append({"type":"page_break","label":"Bagian 2: Soal Ujian","settings":{"description":"Pilih jawaban yang paling tepat. Soal di bagian ini akan diacak.","shuffle":True},"options":[]})
        remaining = req.num_questions
    else:
        remaining = req.num_questions

    bank = ENGLISH_BANK if subject == "english" else MATH_BANK if subject == "math" else INDO_BANK if subject == "indo" else ENGLISH_BANK + MATH_BANK
    random.seed(hash(req.prompt) % 10000)
    random.shuffle(bank)
    # jika english tapi prompt minta spesifik topik, tetap pakai bank english
    for i in range(remaining):
        if bank and i < len(bank):
            q_text, opts, correct_idx = bank[i % len(bank)]
        else:
            # fallback generic
            q_text = f"Pertanyaan {i+1} tentang {req.prompt[:30]}..."
            opts = [f"Pilihan A {i+1}", f"Pilihan B {i+1}", f"Pilihan C {i+1}", f"Pilihan D {i+1}"]
            correct_idx = 0
        # buat opsi
        options = []
        for idx, lab in enumerate(opts):
            options.append({"label": lab, "is_correct": req.include_correct and idx == correct_idx})
        # jika tidak include_correct, semua false
        if not req.include_correct:
            for o in options:
                o["is_correct"] = False
        # label soal
        questions.append({
            "type": "single_choice",
            "label": q_text,
            "is_required": True,
            "settings": {},
            "options": options
        })
    # jika masih kurang karena bank habis, loop lagi dengan variasi
    return {"title": title[:80], "description": desc[:300], "questions": questions}

def _validate_and_normalize(raw_questions, num_questions: int, use_sections: bool) -> List[dict]:
    out = []
    count = 0
    for q in raw_questions:
        if not isinstance(q, dict):
            continue
        t = str(q.get("type") or "").strip()
        if t not in ALLOWED_TYPES:
            alias = {"multiple_choice":"single_choice","choice":"single_choice","essay":"paragraph","short_answer":"text"}
            t = alias.get(t, "text")
            if t not in ALLOWED_TYPES:
                t = "text"
        label = str(q.get("label") or "").strip()
        if not label:
            continue
        # cegah label ngaco yang masih mengandung "buatkan saya form"
        if "buatkan saya form" in label.lower() or "prompt:" in label.lower():
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
        allowed = num_questions + (2 if use_sections else 0)
        if count >= allowed:
            continue
        opts = q.get("options") or []
        norm_opts = []
        if t in ("single_choice","checkbox","dropdown"):
            for o in opts[:4]:
                if not isinstance(o, dict):
                    continue
                lab = str(o.get("label") or "").strip()
                if not lab:
                    continue
                # cegah opsi ngaco "Opsi A Soal 1"
                if lab.startswith("Opsi A Soal") or lab.startswith("Opsi B Soal"):
                    continue
                norm_opts.append({"label": lab[:200], "is_correct": bool(o.get("is_correct"))})
            if not norm_opts:
                norm_opts = [{"label":"Opsi 1","is_correct":False},{"label":"Opsi 2","is_correct":False}]
        out.append({
            "type": t,
            "label": label[:500],
            "is_required": bool(q.get("is_required")),
            "placeholder": str(q.get("placeholder") or "")[:120],
            "settings": q.get("settings") or {},
            "options": norm_opts
        })
        count += 1
    while out and out[-1].get("type") == "page_break":
        out.pop()
    return out

@router.post("/generate-form", response_model=AiGenerateOut)
async def generate_form(payload: AiGenerateRequest, current_user: models.User = Depends(get_current_user)):
    _check_rate_limit(str(current_user.id))
    title = (payload.title or "").strip()
    description = (payload.description or "").strip()
    user_prompt = _build_user_prompt(payload)
    raw_text = await _call_gemini(user_prompt)
    if raw_text is None:
        data = _fallback_mock(payload)
        questions = _validate_and_normalize(data["questions"], payload.num_questions, payload.use_sections)
        return AiGenerateOut(title=data["title"], description=data["description"], questions=questions, usage={"model": "smart-mock", "prompt_chars": len(payload.prompt), "fallback": True})
    cleaned = _repair_json(raw_text)
    try:
        data = json.loads(cleaned)
    except Exception as e:
        try:
            cleaned2 = _repair_json(raw_text[raw_text.find("{"):])
            data = json.loads(cleaned2)
        except Exception:
            data = _fallback_mock(payload)
            questions = _validate_and_normalize(data["questions"], payload.num_questions, payload.use_sections)
            return AiGenerateOut(title=data["title"], description=data["description"], questions=questions, usage={"model": "smart-mock", "prompt_chars": len(payload.prompt), "fallback": True})
    gen_title = str(data.get("title") or title or "Form Buatan AI").strip()[:120]
    gen_desc = str(data.get("description") or description or "").strip()[:2000]
    raw_questions = data.get("questions") or data.get("items") or []
    if not isinstance(raw_questions, list) or len(raw_questions) == 0:
        data = _fallback_mock(payload)
        questions = _validate_and_normalize(data["questions"], payload.num_questions, payload.use_sections)
        return AiGenerateOut(title=data["title"], description=data["description"], questions=questions, usage={"model": "smart-mock", "prompt_chars": len(payload.prompt), "fallback": True})
    questions = _validate_and_normalize(raw_questions, payload.num_questions, payload.use_sections)
    if len([q for q in questions if q["type"] != "page_break"]) == 0:
        data = _fallback_mock(payload)
        questions = _validate_and_normalize(data["questions"], payload.num_questions, payload.use_sections)
        return AiGenerateOut(title=data["title"], description=data["description"], questions=questions, usage={"model": "smart-mock", "prompt_chars": len(payload.prompt), "fallback": True})
    return AiGenerateOut(title=gen_title, description=gen_desc, questions=questions, usage={"model": os.getenv("GEMINI_MODEL","gemini-flash-latest"), "prompt_chars": len(payload.prompt)})
