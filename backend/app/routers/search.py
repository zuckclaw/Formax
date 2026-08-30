from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/search", tags=["search"])


@router.get("", response_model=schemas.SearchResultOut)
def search(
    q: Optional[str] = Query(default=None, description="Kata kunci pencarian"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Pencarian gabungan untuk template (sistem + user) dan form yang sudah
    dipublikasikan milik user. Case-insensitive substring match.
    """

    # --- System templates ------------------------------------------------
    sys_query = db.query(models.Template).filter(models.Template.is_system == True)
    if q:
        sys_query = sys_query.filter(
            func.lower(models.Template.title).contains(q.lower())
        )
    system_templates = sys_query.order_by(models.Template.created_at.asc(), models.Template.title.asc(), models.Template.id.asc()).all()

    # --- User templates --------------------------------------------------
    usr_query = db.query(models.Template).filter(
        models.Template.owner_id == current_user.id
    )
    if q:
        usr_query = usr_query.filter(
            func.lower(models.Template.title).contains(q.lower())
        )
    user_templates = usr_query.order_by(models.Template.created_at.desc()).all()  # keep desc: My Template terbaru dulu

    # --- Published forms (published / closed) ----------------------------
    form_query = db.query(models.Form).filter(
        models.Form.owner_id == current_user.id,
        models.Form.status.in_([
            models.FormStatus.published,
            models.FormStatus.closed,
        ]),
    )
    if q:
        form_query = form_query.filter(
            func.lower(models.Form.title).contains(q.lower())
        )
    pub_forms = form_query.order_by(models.Form.created_at.desc()).all()

    # Hitung total_submissions per form
    published_forms = []
    for f in pub_forms:
        total = (
            db.query(func.count(models.Submission.id))
            .filter(models.Submission.form_id == f.id)
            .scalar()
        )
        item = schemas.SearchFormOut.model_validate(f)
        item.total_submissions = total or 0
        published_forms.append(item)

    return schemas.SearchResultOut(
        system_templates=system_templates,
        user_templates=user_templates,
        published_forms=published_forms,
    )
