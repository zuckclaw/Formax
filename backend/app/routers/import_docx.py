import io
import os

try:
    from docx import Document
except ImportError:
    Document = None
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user
from ..utils.docx_import import parse_docx_questions, generate_template_docx

router = APIRouter(prefix="", tags=["import-docx"])

MAX_DOCX_SIZE = 5 * 1024 * 1024
BASE_URL = os.getenv("BASE_URL", "").strip().rstrip("/")  # 5 MB


def _get_owned_form(form_id: str, db: Session, current_user: models.User) -> models.Form:
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")
    return form


@router.get("/import/template-docx")
def download_template_docx(current_user: models.User = Depends(get_current_user)):
    """Download contoh template Word untuk import soal."""
    content = generate_template_docx()
    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": 'attachment; filename="template-import-soal.docx"'},
    )


@router.post("/forms/{form_id}/questions/import-docx/preview", response_model=schemas.DocxPreviewOut)
def preview_import_docx(
    form_id: str,
    file: UploadFile = File(...),
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    _get_owned_form(form_id, db, current_user)

    if not (file.filename or "").lower().endswith(".docx"):
        raise HTTPException(status_code=400, detail="File harus berformat .docx (Word modern)")

    data = file.file.read()
    if len(data) > MAX_DOCX_SIZE:
        raise HTTPException(status_code=400, detail="Ukuran file maksimal 5 MB")
    if len(data) < 4 or data[:4] != b"PK\x03\x04":
        raise HTTPException(status_code=400, detail="File bukan .docx valid (header ZIP tidak ditemukan)")

    base_url = BASE_URL if BASE_URL else ""
    try:
        parsed = parse_docx_questions(io.BytesIO(data), base_url=base_url)
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="File tidak bisa dibaca. Pastikan file Word valid (.docx), bukan .doc lama",
        )

    if parsed["total"] == 0:
        raise HTTPException(
            status_code=400,
            detail="Tidak ada soal yang terdeteksi. Ikuti format template: soal dimulai nomor '1.' dan opsi memakai huruf 'A.'",
        )

    return parsed


@router.post("/forms/{form_id}/questions/import-docx/confirm")
def confirm_import_docx(
    form_id: str,
    payload: schemas.DocxImportRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    form = _get_owned_form(form_id, db, current_user)

    if not payload.questions:
        raise HTTPException(status_code=400, detail="Tidak ada soal yang dipilih untuk diimpor")
    if len(payload.questions) > 200:
        raise HTTPException(status_code=400, detail="Maksimal 200 soal per import (kecilkan file)")

    last_order = (
        db.query(func.max(models.Question.order_index))
        .filter(models.Question.form_id == form.id)
        .scalar()
    )
    next_order = (last_order or -1) + 1

    imported = 0
    for q in payload.questions:
        question = models.Question(
            form_id=form.id,
            type=models.QuestionType.single_choice,
            label=q.label.strip(),
            placeholder=None,
            is_required=q.is_required,
            order_index=next_order,
            settings={},
        )
        db.add(question)
        db.flush()
        for opt in q.options:
            label = (opt.label or "").strip()
            if not label:
                continue
            db.add(models.QuestionOption(
                question_id=question.id,
                label=label,
                value=label,
                order_index=opt.order_index,
                is_correct=opt.is_correct,
                is_other=False,
            ))
        imported += 1
        next_order += 1

    db.commit()
    return {"message": f"{imported} soal berhasil diimpor", "imported_count": imported}
