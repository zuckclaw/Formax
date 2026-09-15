from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user

router = APIRouter(prefix="/search", tags=["search"])


@router.get("", response_model=schemas.SearchResultOut)
def search(
    q: Optional[str] = Query(default=None, max_length=100, description="Kata kunci pencarian"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Pencarian gabungan untuk template (sistem + user) dan form yang sudah
    dipublikasikan milik user. Case-insensitive substring match.
    """

    def _like_escape(s: str) -> str:
        # Escape wildcard LIKE (% _ \) agar "100%" tidak over-match semua.
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    q_norm = (q or "").strip()[:100]
    q_esc = _like_escape(q_norm.lower()) if q_norm else None

    # --- System templates ------------------------------------------------
    sys_query = db.query(models.Template).filter(models.Template.is_system == True)
    if q_esc:
        sys_query = sys_query.filter(
            func.lower(models.Template.title).contains(q_esc, escape="\\")
        )
    system_templates = sys_query.order_by(models.Template.created_at.asc(), models.Template.title.asc(), models.Template.id.asc()).limit(50).all()

    # --- User templates --------------------------------------------------
    usr_query = db.query(models.Template).filter(
        models.Template.owner_id == current_user.id
    )
    if q_esc:
        usr_query = usr_query.filter(
            func.lower(models.Template.title).contains(q_esc, escape="\\")
        )
    user_templates = usr_query.order_by(models.Template.created_at.desc()).limit(50).all()  # keep desc: My Template terbaru dulu

    # --- Published forms (published / closed) ----------------------------
    form_query = db.query(models.Form).filter(
        models.Form.owner_id == current_user.id,
        models.Form.status.in_([
            models.FormStatus.published,
            models.FormStatus.closed,
        ]),
    )
    if q_esc:
        form_query = form_query.filter(
            func.lower(models.Form.title).contains(q_esc, escape="\\")
        )
    pub_forms = form_query.order_by(models.Form.created_at.desc()).limit(50).all()

    # Hitung total_submissions per form — satu GROUP BY, bukan N query.
    published_forms = []
    if pub_forms:
        form_ids = [f.id for f in pub_forms]
        counts = dict(
            db.query(models.Submission.form_id, func.count(models.Submission.id))
            .filter(models.Submission.form_id.in_(form_ids))
            .group_by(models.Submission.form_id)
            .all()
        )
        for f in pub_forms:
            item = schemas.SearchFormOut.model_validate(f)
            item.total_submissions = counts.get(f.id, 0) or 0
            published_forms.append(item)

    return schemas.SearchResultOut(
        system_templates=system_templates,
        user_templates=user_templates,
        published_forms=published_forms,
    )
