from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..deps import get_db, get_current_user, get_optional_user, get_respondent_key

router = APIRouter(tags=["submissions"])

# start_date / end_date dikirim dari <input datetime-local> browser sebagai waktu
# LOKAL (WIB) tanpa zona. Waktu server (utcnow) adalah UTC. Window timer wajib
# dibandingkan dalam zona yang sama supaya tidak meleset 7 jam di WIB.
WIB = timezone(timedelta(hours=7))


def _window_now():
    return datetime.now(WIB)


def _window_dt(dt):
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(WIB)
    return dt.replace(tzinfo=WIB)

_GRACE = timedelta(seconds=60)


# ------------------------------------------------------------------
# IDENTITAS RESPONDEN: login (user_id) ATAU anonim (respondent_key)
# Google-Forms style: siapa pun dengan link boleh isi tanpa akun.
# ------------------------------------------------------------------
def _resolve_identity(current_user, respondent_key):
    """Return (user_id, respondent_key) untuk identitas responden.

    Login -> user_id; anonim -> respondent_key. Wajib minimal salah satu.
    """
    if current_user is not None:
        return str(current_user.id), None
    key = (respondent_key or "").strip()
    if key:
        return None, key
    raise HTTPException(
        status_code=401,
        detail="Harus login atau menyertakan identitas responden (X-Respondent-Key)",
    )


def _owns_submission(submission, current_user, respondent_key):
    """Cek apakah request ini pemilik submission (login atau anonim)."""
    if current_user is not None:
        # Login: cocokkan user_id (handle UUID vs String); fallback cek respondent_key juga
        if submission.user_id is not None and str(submission.user_id) == str(current_user.id):
            return True
        key = (respondent_key or "").strip()
        if key and submission.respondent_key is not None and str(submission.respondent_key) == key:
            return True
        return False
    key = (respondent_key or "").strip()
    if key and submission.respondent_key is not None and str(submission.respondent_key) == key:
        return True
    return False


@router.post("/forms/public/{slug}/join", response_model=schemas.SubmissionOut)
def join_form(
    slug: str,
    payload: schemas.JoinFormRequest,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """
    Dipanggil pas user klik 'Mulai Isi Form' / 'Mulai Ujian'.
    - Responden boleh login ATAU anonim (X-Respondent-Key).
    - Kalau form.join_token diset, user WAJIB kirim token yang cocok (fitur ujian bareng).
    - Kalau ada start_date/end_date, dicek apakah sekarang ada di dalam window itu.
    - Logika submission mengikuti setting form.max_submissions:
        * Ada submission yang belum selesai -> dikembalikan lagi biar bisa lanjut isi.
        * max_submissions == 0 (unlimited) -> boleh buat submission baru terus.
        * max_submissions > 0 -> dibatasi jumlah submission yang SUDAH SELESAI (submitted).
          Kalau sudah capai limit dan form.allow_see_result aktif, submission terakhir
          dikembalikan supaya responden bisa lihat hasilnya; kalau tidak, ditolak.
    """
    user_id, rkey = _resolve_identity(current_user, respondent_key)

    form = db.query(models.Form).filter(models.Form.slug == slug).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.status != models.FormStatus.published or not form.accept_responses:
        raise HTTPException(status_code=403, detail="Form ini tidak menerima jawaban saat ini")

    if form.join_token:
        if not payload.token or payload.token.strip().upper() != form.join_token.upper():
            raise HTTPException(status_code=403, detail="Token salah atau belum diisi")

    now = _window_now()
    if form.start_date and now + _GRACE < _window_dt(form.start_date):
        raise HTTPException(status_code=403, detail="Form belum dibuka")
    if form.end_date and now > _window_dt(form.end_date):
        raise HTTPException(status_code=403, detail="Waktu pengisian form sudah berakhir")

    # 1) Kalau masih ada submission yang belum selesai, lanjutkan itu (bukan mulai dari 0).
    in_progress = (
        db.query(models.Submission)
        .filter(models.Submission.form_id == form.id, models.Submission.submitted_at.is_(None))
    )
    if user_id:
        in_progress = in_progress.filter(models.Submission.user_id == user_id)
    else:
        in_progress = in_progress.filter(models.Submission.respondent_key == rkey)
    existing = in_progress.first()
    if existing:
        return existing

    # 2) Cek batas jumlah submission yang sudah selesai.
    max_sub = form.max_submissions if form.max_submissions is not None else 1
    completed_q = db.query(func.count(models.Submission.id)).filter(
        models.Submission.form_id == form.id,
        models.Submission.submitted_at.isnot(None),
    )
    if user_id:
        completed_q = completed_q.filter(models.Submission.user_id == user_id)
    else:
        completed_q = completed_q.filter(models.Submission.respondent_key == rkey)
    completed_count = completed_q.scalar() or 0

    if max_sub != 0 and completed_count >= max_sub:
        if form.allow_see_result:
            latest_q = db.query(models.Submission).filter(
                models.Submission.form_id == form.id,
                models.Submission.submitted_at.isnot(None),
            )
            if user_id:
                latest_q = latest_q.filter(models.Submission.user_id == user_id)
            else:
                latest_q = latest_q.filter(models.Submission.respondent_key == rkey)
            latest = latest_q.order_by(models.Submission.submitted_at.desc()).first()
            if latest:
                return latest
        raise HTTPException(
            status_code=400,
            detail=f"Kamu sudah mencapai batas pengisian form ({max_sub} kali)",
        )

    # 3) Belum pernah / masih boleh isi -> buat submission baru.
    submission = models.Submission(form_id=form.id, user_id=user_id, respondent_key=rkey)
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return submission


@router.put("/submissions/{submission_id}/answers", response_model=schemas.AnswerOut)
def save_answer(
    submission_id: str,
    payload: schemas.AnswerSave,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """
    Autosave — dipanggil tiap kali user jawab 1 soal (bukan nunggu submit akhir).
    Upsert berdasarkan (submission_id, question_id): kalau udah pernah jawab soal ini,
    di-update; kalau belum, dibikin baru. Ini juga yang jadi basis progress indikator.
    """
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if not _owns_submission(submission, current_user, respondent_key):
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")
    if submission.submitted_at is not None:
        raise HTTPException(status_code=400, detail="Form ini sudah kamu submit, tidak bisa diubah lagi")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    if form.end_date and _window_now() > _window_dt(form.end_date):
        raise HTTPException(status_code=403, detail="Waktu pengisian sudah habis")

    # FIX: pastikan question milik form submission ini — kalau tidak, tolak supaya
    # tidak terjadi injeksi jawaban lintas form / IntegrityError FK → 500.
    belongs_to_form = db.query(models.Question.id).filter(
        models.Question.id == str(payload.question_id),
        models.Question.form_id == submission.form_id,
    ).first() is not None
    if not belongs_to_form:
        raise HTTPException(status_code=400, detail="Soal tidak ditemukan pada form ini")

    answer = (
        db.query(models.Answer)
        .filter(models.Answer.submission_id == submission_id, models.Answer.question_id == str(payload.question_id))
        .first()
    )
    if answer:
        answer.answer_text = payload.answer_text
        answer.answer_options = payload.answer_options
        answer.file_url = payload.file_url
    else:
        answer = models.Answer(
            submission_id=submission_id, question_id=str(payload.question_id),
            answer_text=payload.answer_text, answer_options=payload.answer_options, file_url=payload.file_url,
        )
        db.add(answer)

    db.commit()
    db.refresh(answer)
    return answer


@router.get("/submissions/{submission_id}/progress", response_model=schemas.ProgressOut)
def get_progress(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """Buat indikator 'X/Y soal terjawab' di UI."""
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if not _owns_submission(submission, current_user, respondent_key):
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")

    total = db.query(func.count(models.Question.id)).filter(models.Question.form_id == submission.form_id).scalar()
    answered = db.query(func.count(models.Answer.id)).filter(models.Answer.submission_id == submission_id).scalar()
    return schemas.ProgressOut(answered=answered or 0, total=total or 0)


@router.post("/submissions/{submission_id}/submit", response_model=schemas.SubmissionOut)
def submit_final(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """Finalisasi submission. Kalau waktunya udah lewat end_date form, ditandai is_auto_submitted."""
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if not _owns_submission(submission, current_user, respondent_key):
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")
    if submission.submitted_at is not None:
        raise HTTPException(status_code=400, detail="Sudah pernah disubmit")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    if form.end_date and _window_now() > _window_dt(form.end_date):
        submission.is_auto_submitted = True

    submission.submitted_at = datetime.utcnow()
    db.commit()
    db.refresh(submission)
    return submission


@router.get("/submissions/me", response_model=List[schemas.MySubmissionOut])
def list_my_submissions(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """
    Aktivitas Saya — daftar form yang pernah/sedang diisi oleh user login sebagai responden.
    Menampilkan bukti kapan submit (started_at/submitted_at), durasi, status, skor bisa dihitung di frontend.
    Diurutkan started_at terbaru di atas.
    """
    subs = (
        db.query(models.Submission)
        .filter(models.Submission.user_id == current_user.id)
        .order_by(models.Submission.started_at.desc())
        .all()
    )
    result = []
    for sub in subs:
        form = db.query(models.Form).filter(models.Form.id == sub.form_id).first()
        if not form:
            # form sudah dihapus — tetap tampilkan submission tanpa form
            result.append(
                schemas.MySubmissionOut(
                    id=sub.id,
                    form_id=sub.form_id,
                    user_id=sub.user_id,
                    started_at=sub.started_at,
                    submitted_at=sub.submitted_at,
                    is_auto_submitted=bool(sub.is_auto_submitted),
                    is_cheated=bool(sub.is_cheated),
                    answers=[schemas.AnswerOut.model_validate(a) for a in (sub.answers or [])],
                    form=None,
                    total_questions=0,
                    answered_count=len(sub.answers or []),
                )
            )
            continue

        owner = db.query(models.User).filter(models.User.id == form.owner_id).first() if form.owner_id else None
        total_q = db.query(func.count(models.Question.id)).filter(models.Question.form_id == form.id).scalar() or 0

        form_brief = schemas.FormBriefOut(
            id=form.id,
            title=form.title,
            slug=form.slug,
            banner_url=form.banner_url,
            status=form.status,
            created_at=form.created_at,
            owner_id=form.owner_id,
            owner_name=owner.full_name if owner else None,
            allow_see_result=bool(form.allow_see_result),
            reveal_answers=bool(form.reveal_answers),
            description=form.description,
        )
        result.append(
            schemas.MySubmissionOut(
                id=sub.id,
                form_id=sub.form_id,
                user_id=sub.user_id,
                started_at=sub.started_at,
                submitted_at=sub.submitted_at,
                is_auto_submitted=bool(sub.is_auto_submitted),
                is_cheated=bool(sub.is_cheated),
                answers=[schemas.AnswerOut.model_validate(a) for a in (sub.answers or [])],
                form=form_brief,
                total_questions=total_q,
                answered_count=len(sub.answers or []),
            )
        )
    return result


@router.get("/forms/{form_id}/submissions", response_model=List[schemas.SubmissionOut])
def list_submissions_for_form(
    form_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Halaman 'Lihat Respon' — owner form lihat semua jawaban yang masuk."""
    form = db.query(models.Form).filter(models.Form.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form tidak ditemukan")
    if form.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bukan form milikmu")

    return db.query(models.Submission).filter(models.Submission.form_id == form_id).all()


# ============================================================
# HELPERS SKOR (sama dengan logika export.py)
# ============================================================
def _correct_keys(question):
    return {_strip_grid_row(o.label) for o in question.options if o.is_correct}


def _is_graded(question):
    return len(_correct_keys(question)) > 0


def _strip_grid_row(value):
    """Grid jawaban mobile disimpan 'NamaBaris => Opsi'; buang prefix baris utk tampil/skor."""
    if isinstance(value, str) and " => " in value:
        return value.split(" => ", 1)[1]
    return value


def _user_answer_str(ans):
    if not ans:
        return ""
    if ans.answer_text:
        return _strip_grid_row(ans.answer_text)
    if ans.answer_options:
        return ", ".join(_strip_grid_row(x) for x in ans.answer_options)
    if ans.file_url:
        return ans.file_url
    return ""


def _is_answer_correct(question, ans):
    keys = _correct_keys(question)
    if not keys:
        return None
    if ans is None:
        return False
    selected = {_strip_grid_row(x) for x in ans.answer_options} if ans.answer_options else ({ans.answer_text} if ans.answer_text else set())
    return keys == selected


# ============================================================
# RESPONDEN LIHAT HASIL
# ============================================================
@router.get("/submissions/{submission_id}/result", response_model=schemas.SubmissionResultOut)
def get_submission_result(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """
    Responden lihat hasil submission-nya sendiri (skor + benar/salah per soal).
    Hanya aktif kalau form.allow_see_result true dan submission sudah di-submit.
    Kunci jawaban (opsi benar) hanya dikirim kalau form.reveal_answers true.
    """
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if not _owns_submission(submission, current_user, respondent_key):
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")
    if submission.submitted_at is None:
        raise HTTPException(status_code=400, detail="Hasil belum tersedia, submission belum disubmit")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    if not form or not form.allow_see_result:
        raise HTTPException(status_code=403, detail="Pembuat form tidak mengizinkan responden melihat hasil")

    questions = (
        db.query(models.Question)
        .filter(models.Question.form_id == form.id)
        .order_by(models.Question.order_index)
        .all()
    )
    answers = {a.question_id: a for a in submission.answers}
    reveal = bool(form.reveal_answers)

    total_graded = sum(1 for q in questions if _is_graded(q))
    correct_count = sum(
        1 for q in questions
        if _is_graded(q) and _is_answer_correct(q, answers.get(q.id))
    )
    score = round((correct_count / total_graded) * 100) if total_graded else None

    result_answers = [
        schemas.AnswerResultOut(
            question_id=q.id,
            label=q.label,
            type=q.type,
            user_answer=_user_answer_str(answers.get(q.id)),
            is_correct=_is_answer_correct(q, answers.get(q.id)),
            correct_answer=", ".join(sorted(_correct_keys(q))) if reveal else None,
        )
        for q in questions
    ]

    return schemas.SubmissionResultOut(
        submission_id=submission.id,
        form_title=form.title,
        score_percent=score,
        correct_count=correct_count,
        total_graded=total_graded,
        is_cheated=submission.is_cheated,
        submitted_at=submission.submitted_at,
        answers=result_answers,
    )


@router.post("/submissions/{submission_id}/flag-cheated", response_model=schemas.SubmissionOut)
def flag_cheated(
    submission_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(get_optional_user),
    respondent_key: Optional[str] = Depends(get_respondent_key),
):
    """
    Frontend kirim flag ini kalau user keluar dari mode fullscreen.
    is_cheated diset permanen (sekali). Hanya aktif kalau form.require_fullscreen true.
    """
    submission = db.query(models.Submission).filter(models.Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Submission tidak ditemukan")
    if not _owns_submission(submission, current_user, respondent_key):
        raise HTTPException(status_code=403, detail="Bukan submission milikmu")

    form = db.query(models.Form).filter(models.Form.id == submission.form_id).first()
    if not form or not form.require_fullscreen:
        raise HTTPException(status_code=403, detail="Form tidak mengaktifkan mode full screen")

    submission.is_cheated = True
    db.commit()
    db.refresh(submission)
    return submission

