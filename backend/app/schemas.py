import uuid
from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, EmailStr, field_validator

from .models import QuestionType, FormStatus
from .sanitize import sanitize_html
from .utils.emoji_filter import contains_emoji, remove_emojis


# ============================================================
# AUTH
# ============================================================
class SignUpRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    otp: str

    @field_validator("full_name")
    @classmethod
    def _validate_full_name(cls, v: str) -> str:
        if contains_emoji(v):
            raise ValueError("Nama lengkap tidak boleh mengandung emoji")
        cleaned = remove_emojis(v).strip()
        if not cleaned:
            raise ValueError("Nama lengkap tidak boleh kosong")
        return cleaned


class SendOTPRequest(BaseModel):
    email: EmailStr

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetOtpRequest(BaseModel):
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str
    new_password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    remember: bool = False


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    avatar_url: Optional[str] = None

    @field_validator("full_name")
    @classmethod
    def _validate_full_name(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            if contains_emoji(v):
                raise ValueError("Nama lengkap tidak boleh mengandung emoji")
            cleaned = remove_emojis(v).strip()
            if not cleaned:
                raise ValueError("Nama lengkap tidak boleh kosong")
            return cleaned
        return v


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: uuid.UUID
    full_name: str
    email: EmailStr
    avatar_url: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# QUESTION OPTIONS
# ============================================================
class QuestionOptionCreate(BaseModel):
    label: str
    value: Optional[str] = None
    order_index: int = 0
    is_correct: bool = False
    is_other: bool = False

    @field_validator("label")
    @classmethod
    def _clean_label(cls, v):
        return sanitize_html(v)


class QuestionOptionUpdate(BaseModel):
    label: Optional[str] = None
    value: Optional[str] = None
    order_index: Optional[int] = None
    is_correct: Optional[bool] = None
    is_other: Optional[bool] = None


class QuestionOptionOut(QuestionOptionCreate):
    id: uuid.UUID
    is_other: bool = False

    class Config:
        from_attributes = True


# ============================================================
# QUESTIONS
# ============================================================
class QuestionCreate(BaseModel):
    type: QuestionType
    label: str
    placeholder: Optional[str] = None
    is_required: bool = False
    order_index: int = 0
    settings: dict = {}
    options: List[QuestionOptionCreate] = []

    @field_validator("label", "placeholder")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class QuestionUpdate(BaseModel):
    type: Optional[QuestionType] = None
    label: Optional[str] = None
    placeholder: Optional[str] = None
    is_required: Optional[bool] = None
    order_index: Optional[int] = None
    settings: Optional[dict] = None

    @field_validator("label", "placeholder")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class QuestionOut(BaseModel):
    id: uuid.UUID
    type: QuestionType
    label: str
    placeholder: Optional[str]
    is_required: bool
    order_index: int
    settings: dict
    options: List[QuestionOptionOut] = []

    class Config:
        from_attributes = True


# ============================================================
# TEMPLATES
# ============================================================
class TemplateCreate(BaseModel):
    title: str
    description: Optional[str] = None
    banner_url: Optional[str] = None
    questions: List[QuestionCreate] = []

    @field_validator("title", "description")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class TemplateUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    banner_url: Optional[str] = None
    questions: Optional[List[QuestionCreate]] = None  # untuk draft update, replace semua questions

    @field_validator("title", "description")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class TemplateOut(BaseModel):
    id: uuid.UUID
    owner_id: Optional[uuid.UUID]
    title: str
    description: Optional[str]
    banner_url: Optional[str]
    is_system: bool
    created_at: datetime
    questions: List[QuestionOut] = []

    class Config:
        from_attributes = True


# ============================================================
# FORMS
# ============================================================
class FormCreate(BaseModel):
    title: str
    description: Optional[str] = None
    template_id: Optional[uuid.UUID] = None
    slug: str
    banner_url: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    use_join_token: bool = False        # kalau true, server generate token acak buat ujian bareng
    questions: List[QuestionCreate] = []  # dipakai kalau blank form (tanpa template)
    allow_see_result: bool = False
    max_submissions: int = 1
    require_fullscreen: bool = False
    reveal_answers: bool = False
    shuffle_questions: bool = False     # acak soal per-section
    shuffle_options: bool = False       # acak opsi per-soal
    # FIX publish bug: web kirim status=published saat klik Publish pada form baru,
    # tapi field ini tidak ada di FormCreate sehingga di-ignore Pydantic → selalu draft (403).
    # Tambahkan status & accept_responses agar create bisa langsung published.
    status: Optional[FormStatus] = FormStatus.draft
    accept_responses: Optional[bool] = True

    @field_validator("title", "description")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class FormUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[FormStatus] = None
    accept_responses: Optional[bool] = None
    banner_url: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    use_join_token: Optional[bool] = None
    allow_see_result: Optional[bool] = None
    max_submissions: Optional[int] = None
    require_fullscreen: Optional[bool] = None
    reveal_answers: Optional[bool] = None
    shuffle_questions: Optional[bool] = None
    shuffle_options: Optional[bool] = None
    questions: Optional[List[QuestionCreate]] = None  # draft/update: replace semua questions

    @field_validator("title", "description")
    @classmethod
    def _clean_html_fields(cls, v):
        return sanitize_html(v)


class FormOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    template_id: Optional[uuid.UUID]
    title: str
    description: Optional[str]
    banner_url: Optional[str]
    status: FormStatus
    slug: str
    join_token: Optional[str]
    qr_code_url: Optional[str]
    accept_responses: bool
    allow_see_result: bool
    max_submissions: int
    require_fullscreen: bool
    reveal_answers: bool
    shuffle_questions: bool = False
    shuffle_options: bool = False
    start_date: Optional[datetime]
    end_date: Optional[datetime]
    created_at: datetime
    questions: List[QuestionOut] = []

    class Config:
        from_attributes = True


class FormListOut(BaseModel):
    id: uuid.UUID
    title: str
    status: FormStatus
    slug: str
    banner_url: Optional[str] = None
    created_at: datetime
    total_submissions: int = 0   # dihitung on-the-fly, buat halaman History

    class Config:
        from_attributes = True


# ============================================================
# SEARCH
# ============================================================
class SearchTemplateOut(BaseModel):
    id: uuid.UUID
    title: str
    description: Optional[str] = None
    is_system: bool
    created_at: datetime

    class Config:
        from_attributes = True


class SearchFormOut(BaseModel):
    id: uuid.UUID
    title: str
    status: FormStatus
    slug: str
    created_at: datetime
    total_submissions: int = 0

    class Config:
        from_attributes = True


class SearchResultOut(BaseModel):
    system_templates: List[SearchTemplateOut] = []
    user_templates: List[SearchTemplateOut] = []
    published_forms: List[SearchFormOut] = []


# ============================================================
# JOIN / SUBMISSION / ANSWERS
# ============================================================
class JoinFormRequest(BaseModel):
    token: Optional[str] = None   # wajib diisi kalau form.join_token gak null


class SubmissionStartOut(BaseModel):
    id: uuid.UUID
    form_id: uuid.UUID
    started_at: datetime

    class Config:
        from_attributes = True


class AnswerSave(BaseModel):
    question_id: uuid.UUID
    answer_text: Optional[str] = None
    answer_options: Optional[List[str]] = None
    file_url: Optional[str] = None


class AnswerOut(BaseModel):
    id: uuid.UUID
    question_id: uuid.UUID
    answer_text: Optional[str]
    answer_options: Optional[Any]
    file_url: Optional[str]

    class Config:
        from_attributes = True


class ProgressOut(BaseModel):
    answered: int
    total: int


class SubmissionOut(BaseModel):
    id: uuid.UUID
    form_id: uuid.UUID
    user_id: Optional[uuid.UUID] = None  # None untuk responden anonim
    respondent_key: Optional[str] = None  # identitas anonim
    user: Optional[UserOut] = None
    started_at: datetime
    is_auto_submitted: bool
    submitted_at: Optional[datetime]
    is_cheated: bool = False
    shuffled_order: Optional[Any] = None
    shuffled_options: Optional[Any] = None
    answers: List[AnswerOut] = []

    class Config:
        from_attributes = True


# ============================================================
# AKTIVITAS SAYA — daftar form yang pernah/lagi diisi sebagai responden
# ============================================================
class FormBriefOut(BaseModel):
    id: uuid.UUID
    title: str
    slug: str
    banner_url: Optional[str] = None
    status: FormStatus
    created_at: datetime
    owner_id: uuid.UUID
    owner_name: Optional[str] = None
    allow_see_result: bool = False
    reveal_answers: bool = False
    description: Optional[str] = None

    class Config:
        from_attributes = True


class MySubmissionOut(BaseModel):
    id: uuid.UUID
    form_id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    respondent_key: Optional[str] = None
    started_at: datetime
    submitted_at: Optional[datetime]
    is_auto_submitted: bool = False
    is_cheated: bool = False
    answers: List[AnswerOut] = []
    form: Optional[FormBriefOut] = None
    total_questions: int = 0
    answered_count: int = 0

    class Config:
        from_attributes = True


# ============================================================
# RESULT (Responden lihat hasil sendiri)
# ============================================================
class AnswerResultOut(BaseModel):
    question_id: uuid.UUID
    label: str
    type: QuestionType
    user_answer: Optional[str] = None
    is_correct: Optional[bool] = None
    correct_answer: Optional[str] = None  # kunci jawaban, hanya dikirim jika form.reveal_answers


class SubmissionResultOut(BaseModel):
    submission_id: uuid.UUID
    form_title: str
    score_percent: Optional[int] = None   # None kalau belum ada soal ber-kunci
    correct_count: int = 0
    total_graded: int = 0
    is_cheated: bool = False
    submitted_at: Optional[datetime]
    answers: List[AnswerResultOut] = []

# ============================================================
# IMPORT SOAL DARI WORD (.docx)
# ============================================================
class DocxParsedOption(BaseModel):
    label: str
    value: Optional[str] = None
    order_index: int = 0
    is_correct: bool = False


class DocxParsedQuestion(BaseModel):
    number: int
    label: str
    options: List[DocxParsedOption] = []
    errors: List[str] = []


class DocxPreviewOut(BaseModel):
    total: int
    valid_count: int
    questions: List[DocxParsedQuestion]


class DocxImportQuestionIn(BaseModel):
    label: str
    is_required: bool = False
    options: List[QuestionOptionCreate] = []


class DocxImportRequest(BaseModel):
    questions: List[DocxImportQuestionIn]
