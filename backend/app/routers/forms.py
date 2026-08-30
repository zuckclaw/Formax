import html as _html
import os
import re
import secrets
from typing import List

import qrcode
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user

_SLUG_RE = re.compile(r'^[a-z0-9-]+$')
_TAG_RE = re.compile(r'<[^>]+>')


def _slugify_plain(text: str) -> str:
    """Bersihkan teks (buang tag HTML & entitas) lalu jadikan slug."""
    text = _TAG_RE.sub(' ', str(text))
    text = _html.unescape(text)
    text = text.strip().lower()
    text = re.sub(r'[^a-z0-9\s-]', '', text)
    text = re.sub(r'\s+', '-', text).strip('-')
    return text[:60]

router = APIRouter(prefix="/forms", tags=["forms"])

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000").strip().rstrip("/")
QR_DIR = "static/qrcodes"


@router.get("", response_model=List[schemas.FormListOut])
def list_my_forms(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Ini yang dipakai buat halaman 'History' — list form + jumlah submission masing-masing."""
    forms = db.query(models.Form).filter(models.Form.owner_id == current_user.id).all()
    result = []
    for f in forms:
        total = db.query(func.count(models.Submission.id)).filter(models.Submission.form_id == f.id).scalar()
        item = schemas.FormListOut.model_validate(f)
        item.total_submissions = total or 0
        result.append(item)
    return result


@router.post("", response_model=schemas.FormOut)
def create_form(
    payload: schemas.FormCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # FIX Bug 30: validasi slug
    # FIX Bug 30b: title disimpan sebagai HTML rich-text; jika client mengirim slug
    # hasil generate dari HTML mentah (mis. "pspan-stylefont-weight-bold-...-mtecbzkp"),
    # sisa tag akan bocor ke URL/QR. Rebuild slug dari teks bersih title setiap kali
    # title mengandung markup, sehingga link selalu rapi dari client mana pun.
    if '<' in str(payload.title):
        base = _slugify_plain(str(payload.title)) or 'form'
        candidate = f'{base}-{secrets.token_hex(3)}'
        while db.query(models.Form).filter(models.Form.slug == candidate).first():
            candidate = f'{base}-{secrets.token_hex(3)}'
        payload.slug = candidate
    raw_slug = str(payload.slug).strip().lower()
    if not _SLUG_RE.match(raw_slug):
        raise HTTPException(status_code=422, detail="Slug tidak valid — hanya a-z, 0-9, dan -")
    if db.query(models.Form).filter(models.Form.slug == raw_slug).first():
        raise HTTPException(status_code=400, detail="Slug sudah dipakai, pilih yang lain")
    payload.slug = raw_slug  # normalisasi

    form = models.Form(
        owner_id=current_user.id,
        template_id=payload.template_id,
        title=payload.title,
        description=payload.description,
        slug=payload.slug,
        banner_url=payload.banner_url,
        start_date=payload.start_date,
        end_date=payload.end_date,
        join_token=security.generate_join_token() if payload.use_join_token else None,
        allow_see_result=payload.allow_see_result,
        max_submissions=payload.max_submissions,
        require_fullscreen=payload.require_fullscreen,
        reveal_answers=payload.reveal_answers,
    )
    db.add(form)
    db.flush()

    if payload.template_id:
        # FIX Bug 15 & 16: cek ownership + 404 jika template tidak ada / bukan milik user
        template = db.query(models.Template).filter(models.Template.id == str(payload.template_id)).first()
        if not template:
            raise HTTPException(status_code=404, detail="Template tidak ditemukan")
        if not template.is_system and template.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail="Bukan template milikmu")
        if not form.banner_url and template.banner_url:
            form.banner_url = template.banner_url
        template_questions = (
            db.query(models.Question)
            .filter(models.Question.template_id == str(payload.template_id))
            .order_by(models.Question.order_index)
            .all()
        )
        if not template_questions:
            # Jika template kosong, tetap lanjut tapi warn — jangan buat form 0 pertanyaan tanpa alasan
            pass
        for tq in template_questions:
            new_q = models.Question(
                form_id=form.id, type=tq.type, label=tq.label, placeholder=tq.placeholder,
                is_required=tq.is_required, order_index=tq.order_index, settings=tq.settings,
            )
            db.add(new_q)
            db.flush()
            for opt in tq.options:
                db.add(models.QuestionOption(question_id=new_q.id, label=opt.label, value=opt.value, order_index=opt.order_index, is_correct=opt.is_correct, is_other=getattr(opt, 'is_other', False)))
    else:
        for q in payload.questions:
            new_q = models.Question(
                form_id=form.id, type=q.type, label=q.label, placeholder=q.placeholder,
                is_required=q.is_required, order_index=q.order_index, settings=q.settings,
            )
            db.add(new_q)
            db.flush()
            for opt in q.options:
                db.add(models.QuestionOption(question_id=new_q.id, label=opt.label, value=opt.value, order_index=opt.order_index, is_correct=opt.is_correct, is_other=getattr(opt, 'is_other', False)))

    db.commit()
    db.expire_all()
    db.refresh(form)
    return form


# ── Public form access (MUST be declared before /{form_id} to avoid route conflict) ──

@router.get("/public/{slug}", response_model=schemas.FormOut)
def get_form_by_slug(slug: str, db: Session = Depends(get_db)):
    """
    Dipanggil pas orang buka link form. Tidak wajib login (agar bisa diisi siapa saja
    seperti Google Forms). Tetap cek window waktu & accept_responses.
    """
    form = db.query(models.Form).filter(models.Form.slug == slug).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.status == models.FormStatus.draft:
        raise HTTPException(status_code=403, detail="Form ini masih draft — buka Form Builder → Setelan → Status → Published lalu Simpan")
    if form.status == models.FormStatus.closed:
        raise HTTPException(status_code=403, detail="Form ini sudah ditutup (Closed)")
    if form.status != models.FormStatus.published:
        raise HTTPException(status_code=403, detail="Form ini belum/tidak lagi menerima jawaban")
    # FIX Bug 31: cek window waktu & accept_responses juga di get_form_by_slug
    if not form.accept_responses:
        raise HTTPException(status_code=403, detail="Form menutup penerimaan jawaban (Terima Respons dimatikan di Setelan)")
    from datetime import datetime, timezone, timedelta
    WIB = timezone(timedelta(hours=7))
    def _now(): return datetime.now(WIB)
    def _dt(dt):
        if dt is None:
            return None
        if dt.tzinfo is not None:
            return dt.astimezone(WIB)
        return dt.replace(tzinfo=WIB)
    now = _now()
    # Grace 60s untuk race publish→join & jam HP yang agak cepat (aman race, tidak ganggu web)
    GRACE = timedelta(seconds=60)
    if form.start_date and now + GRACE < _dt(form.start_date):
        raise HTTPException(status_code=403, detail="Form belum dibuka")
    if form.end_date and now > _dt(form.end_date):
        raise HTTPException(status_code=403, detail="Waktu pengisian form sudah berakhir")
    return form


# ── Owner-only form access (after /public/{slug} to avoid route conflict) ──

@router.get("/{form_id}", response_model=schemas.FormOut)
def get_form_for_owner(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")
    return form


@router.patch("/{form_id}", response_model=schemas.FormOut)
def update_form(
    form_id: str, payload: schemas.FormUpdate,
    db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user),
):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    data = payload.model_dump(exclude_unset=True)
    questions_data = data.pop("questions", None)

    # FIX data-loss: mengganti semua question dengan delete-orphan akan menghapus
    # seluruh jawaban responden (Answer.question_id ON DELETE CASCADE). Kalau form
    # sudah punya submission/jawaban, tolak pergantian pertanyaan supaya data
    # responden tidak musnah diam-diam.
    if questions_data is not None:
        has_answers = db.query(models.Submission.id).filter(
            models.Submission.form_id == form.id
        ).first() is not None
        if has_answers:
            raise HTTPException(
                status_code=409,
                detail="Form sudah punya jawaban; mengubah pertanyaan akan menghapus jawaban responden. Duplikasi form dulu (atau cadangkan jawaban) sebelum mengganti pertanyaan.",
            )

    for key, value in data.items():
        setattr(form, key, value)

    # Jika questions ikut dikirim (draft save), replace semua questions lama.
    # Sama seperti update template — dipakai agar draft form dari mobile bisa
    # menyimpan pertanyaan secara atomik tanpa perlu CRUD per question.
    if questions_data is not None:
        from datetime import datetime
        form.updated_at = datetime.utcnow()
        for q in list(form.questions):
            db.delete(q)
        db.flush()
        for q in questions_data:
            q_type = q.get("type") if isinstance(q, dict) else q.type
            if isinstance(q, dict):
                label = (q.get("label") or "").strip() or "Pertanyaan Tanpa Judul"
                placeholder = q.get("placeholder")
                is_required = q.get("is_required", False)
                order_index = q.get("order_index", 0)
                settings = q.get("settings") or {}
                options = q.get("options") or []
            else:
                label = (q.label or "").strip() or "Pertanyaan Tanpa Judul"
                placeholder = q.placeholder
                is_required = q.is_required
                order_index = q.order_index
                settings = q.settings or {}
                options = q.options
            question = models.Question(
                form_id=form.id,
                type=q_type, label=label, placeholder=placeholder,
                is_required=is_required, order_index=order_index, settings=settings,
            )
            db.add(question)
            db.flush()
            for opt in options:
                if isinstance(opt, dict):
                    db.add(models.QuestionOption(
                        question_id=question.id,
                        label=(opt.get("label") or "Opsi").strip(),
                        value=opt.get("value"),
                        order_index=opt.get("order_index", 0),
                        is_correct=opt.get("is_correct", False),
                        is_other=opt.get("is_other", False),
                    ))
                else:
                    db.add(models.QuestionOption(
                        question_id=question.id, label=(opt.label or "Opsi").strip(),
                        value=opt.value, order_index=opt.order_index,
                        is_correct=opt.is_correct, is_other=opt.is_other,
                    ))

    try:
        db.commit()
        db.refresh(form)
        db.refresh(form, attribute_names=["questions"])
        return form
    except Exception as e:
        db.rollback()
        print(f"[forms] update_form error: {e}")
        raise HTTPException(status_code=500, detail=f"Gagal update form: {str(e)}")


@router.post("/{form_id}/publish", response_model=schemas.FormOut)
def publish_form(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Terbitkan form: ubah status menjadi 'published' agar bisa diakses lewat link publik."""
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    form.status = models.FormStatus.published
    db.commit()
    db.refresh(form)
    return form


@router.delete("/{form_id}")
def delete_form(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")
    db.delete(form)
    db.commit()
    return {"message": "Form dihapus"}


@router.post("/{form_id}/generate-qr")
def generate_qr(form_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Generate QR code dari link publik form, simpan sebagai file static, update qr_code_url."""
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    frontend_url = os.getenv("FRONTEND_URL", "http://localhost:5173").strip().rstrip("/")
    public_url = f"{frontend_url}/f/{form.slug}"
    img = qrcode.make(public_url)

    os.makedirs(QR_DIR, exist_ok=True)
    filepath = f"{QR_DIR}/{form.slug}.png"
    img.save(filepath)

    form.qr_code_url = f"{BASE_URL}/static/qrcodes/{form.slug}.png"
    db.commit()
    return {"qr_code_url": form.qr_code_url, "share_link": public_url}

