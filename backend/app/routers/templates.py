from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get("", response_model=List[schemas.TemplateOut])
def list_templates(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Nampilin template sistem (Blank/Attendance/Exam) + 'My Template' milik user.
    Eager load questions+options agar GET tidak cuma id/title (bug Template hilang form)."""
    return (
        db.query(models.Template)
        .options(selectinload(models.Template.questions).selectinload(models.Question.options))
        .filter(or_(models.Template.is_system == True, models.Template.owner_id == current_user.id))
        .order_by(models.Template.is_system.desc(), models.Template.created_at.asc(), models.Template.title.asc(), models.Template.id.asc())
        .all()
    )


@router.get("/mine", response_model=List[schemas.TemplateOut])
def list_my_templates(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Khusus 'My Template' — template buatan sendiri aja. Diurut terbaru dulu biar draft baru langsung kelihatan.
    Selalu sertakan questions agar UI tidak fallback ke default 'Pertanyaan/Opsi 1'."""
    return (
        db.query(models.Template)
        .options(selectinload(models.Template.questions).selectinload(models.Question.options))
        .filter(models.Template.owner_id == current_user.id)
        .order_by(models.Template.created_at.desc())
        .all()
    )


@router.post("", response_model=schemas.TemplateOut)
def create_template(
    payload: schemas.TemplateCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    # Validasi title tidak kosong (hindari draft tanpa judul yang membingungkan di UI)
    if not payload.title or not payload.title.strip():
        raise HTTPException(status_code=422, detail="Judul template tidak boleh kosong")

    try:
        template = models.Template(
            owner_id=current_user.id,
            title=payload.title.strip(),
            description=(payload.description or "").strip() or None,
            banner_url=payload.banner_url,
        )
        db.add(template)
        db.flush()

        for q in payload.questions:
            # Pastikan label tidak kosong
            label = (q.label or "").strip() or "Pertanyaan Tanpa Judul"
            question = models.Question(
                template_id=template.id,
                type=q.type, label=label, placeholder=q.placeholder,
                is_required=q.is_required, order_index=q.order_index, settings=q.settings or {},
            )
            db.add(question)
            db.flush()
            for opt in q.options:
                # is_other perlu diteruskan agar opsi "Lainnya" ikut tersimpan
                db.add(models.QuestionOption(
                    question_id=question.id,
                    label=(opt.label or "Opsi").strip(),
                    value=opt.value,
                    order_index=opt.order_index,
                    is_correct=opt.is_correct,
                    is_other=opt.is_other,
                ))

        db.commit()
        db.refresh(template)
        # refresh questions relationship supaya langsung kebaca di response
        db.refresh(template, attribute_names=["questions"])
        return template
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        # Log ke server console untuk debugging koneksi mobile
        print(f"[templates] create_template error: {e} payload_title={payload.title}")
        raise HTTPException(status_code=500, detail=f"Gagal menyimpan template: {str(e)}")


@router.get("/{template_id}", response_model=schemas.TemplateOut)
def get_template(template_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    template = (
        db.query(models.Template)
        .options(selectinload(models.Template.questions).selectinload(models.Question.options))
        .filter(models.Template.id == template_id)
        .first()
    )
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if not template.is_system and template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")
    return template


@router.patch("/{template_id}", response_model=schemas.TemplateOut)
def update_template(
    template_id: str,
    payload: schemas.TemplateUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    template = (
        db.query(models.Template)
        .options(selectinload(models.Template.questions).selectinload(models.Question.options))
        .filter(models.Template.id == template_id)
        .first()
    )
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if template.is_system:
        raise HTTPException(status_code=403, detail="Template sistem tidak bisa diedit")
    if template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")

    # pisahkan questions dari field biasa
    data = payload.model_dump(exclude_unset=True)
    questions_data = data.pop("questions", None)

    for key, value in data.items():
        setattr(template, key, value)

    # jika questions ikut dikirim (draft save), replace semua questions lama
    if questions_data is not None:
        # FIX Bug 25: sentuh updated_at parent agar perubahan question tercermin
        from datetime import datetime
        template.updated_at = datetime.utcnow()
        for q in list(template.questions):
            db.delete(q)
        db.flush()
        for q in questions_data:
            # q adalah dict dari QuestionCreate
            q_type = q.get("type") if isinstance(q, dict) else q.type
            # handle jika masih dict (exclude_unset) -> pydantic dump
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
                template_id=template.id,
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
        db.refresh(template)
        db.refresh(template, attribute_names=["questions"])
        return template
    except Exception as e:
        db.rollback()
        print(f"[templates] update_template error: {e}")
        raise HTTPException(status_code=500, detail=f"Gagal update template: {str(e)}")


@router.delete("/{template_id}")
def delete_template(template_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    template = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan")
    if template.is_system:
        raise HTTPException(status_code=403, detail="Template sistem tidak bisa dihapus")
    if template.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan template milikmu")
    db.delete(template)
    db.commit()
    return {"message": "Template dihapus"}

