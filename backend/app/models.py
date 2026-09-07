import uuid
import enum
from datetime import datetime

from sqlalchemy import (
    Column, String, Text, Boolean, Integer, ForeignKey, DateTime, Enum, CheckConstraint, UniqueConstraint, JSON
)
from sqlalchemy.orm import relationship

from .database import Base


def gen_uuid():
    return str(uuid.uuid4())



# ============================================================
# ENUMS
# ============================================================
class QuestionType(str, enum.Enum):
    text = "text"
    paragraph = "paragraph"
    single_choice = "single_choice"
    checkbox = "checkbox"
    dropdown = "dropdown"
    date = "date"
    time = "time"
    file_upload = "file_upload"
    linear_scale = "linear_scale"
    rating = "rating"
    multiple_choice_grid = "multiple_choice_grid"
    tick_box_grid = "tick_box_grid"
    page_break = "page_break"
    image = "image"
    text_block = "text_block"


class FormStatus(str, enum.Enum):
    draft = "draft"
    published = "published"
    closed = "closed"


# ============================================================
# 1. USERS
# ============================================================
class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    full_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    avatar_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    templates = relationship("Template", back_populates="owner", cascade="all, delete-orphan")
    forms = relationship("Form", back_populates="owner", cascade="all, delete-orphan")
    submissions = relationship("Submission", back_populates="user")


# ============================================================
# 2. TEMPLATES
# ============================================================
class Template(Base):
    __tablename__ = "templates"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    owner_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    banner_url = Column(String, nullable=True)
    is_system = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner = relationship("User", back_populates="templates")
    questions = relationship("Question", back_populates="template", cascade="all, delete-orphan")


# ============================================================
# 3. FORMS
# ============================================================
class Form(Base):
    __tablename__ = "forms"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    owner_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    template_id = Column(String(36), ForeignKey("templates.id", ondelete="SET NULL"), nullable=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    status = Column(Enum(FormStatus), default=FormStatus.draft)

    slug = Column(String, unique=True, nullable=False, index=True)
    join_token = Column(String, unique=True, nullable=True)   # buat ujian bareng, opsional
    qr_code_url = Column(String, nullable=True)
    banner_url = Column(String, nullable=True)

    accept_responses = Column(Boolean, default=True)

    # settings tambahan
    allow_see_result = Column(Boolean, default=False)   # responden boleh lihat hasil submit + skor
    max_submissions = Column(Integer, default=0)        # berapa kali boleh submit (0 = unlimited)
    require_fullscreen = Column(Boolean, default=False) # wajib fullscreen, keluar = ditandai curang
    reveal_answers = Column(Boolean, default=False)     # tampilkan kunci jawaban di halaman hasil

    # timer: window waktu tetap, berlaku sama buat semua orang
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)

    # section / shuffle
    shuffle_questions = Column(Boolean, default=False)  # acak soal per-section untuk responden
    shuffle_options = Column(Boolean, default=False)    # acak opsi jawaban per-soal

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner = relationship("User", back_populates="forms")
    questions = relationship("Question", back_populates="form", cascade="all, delete-orphan")
    submissions = relationship("Submission", back_populates="form", cascade="all, delete-orphan")


# ============================================================
# 4. QUESTIONS
# ============================================================
class Question(Base):
    __tablename__ = "questions"
    __table_args__ = (
        CheckConstraint("form_id IS NOT NULL OR template_id IS NOT NULL", name="ck_form_or_template"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    form_id = Column(String(36), ForeignKey("forms.id", ondelete="CASCADE"), nullable=True)
    template_id = Column(String(36), ForeignKey("templates.id", ondelete="CASCADE"), nullable=True)
    type = Column(Enum(QuestionType), nullable=False)
    label = Column(String, nullable=False)
    placeholder = Column(String, nullable=True)
    is_required = Column(Boolean, default=False)
    order_index = Column(Integer, nullable=False, default=0)
    settings = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)

    form = relationship("Form", back_populates="questions")
    template = relationship("Template", back_populates="questions")
    options = relationship("QuestionOption", back_populates="question", cascade="all, delete-orphan")
    answers = relationship("Answer", back_populates="question")


# ============================================================
# 5. QUESTION_OPTIONS
# ============================================================
class QuestionOption(Base):
    __tablename__ = "question_options"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    question_id = Column(String(36), ForeignKey("questions.id", ondelete="CASCADE"), nullable=False)
    label = Column(String, nullable=False)
    value = Column(String, nullable=True)
    order_index = Column(Integer, default=0)
    is_correct = Column(Boolean, default=False)  # kunci jawaban (1 opsi benar per soal pilihan)
    is_other = Column(Boolean, default=False)  # opsi "Lainnya" yang memungkinkan input bebas

    question = relationship("Question", back_populates="options")


# ============================================================
# 6. SUBMISSIONS  (1 row = 1 user ngisi 1 form)
# ============================================================
class Submission(Base):
    __tablename__ = "submissions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    form_id = Column(String(36), ForeignKey("forms.id", ondelete="CASCADE"), nullable=False)
    # Responden: harus login ATAU punya respondent_key (anonim). user_id nullable utk anonim.
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=True)  # login (opsional)
    respondent_key = Column(String(64), nullable=True)  # anonim: UUID client utk identitas tanpa akun

    started_at = Column(DateTime, default=datetime.utcnow)
    is_auto_submitted = Column(Boolean, default=False)
    submitted_at = Column(DateTime, nullable=True)
    is_cheated = Column(Boolean, default=False)  # ditandai curang jika keluar mode fullscreen
    shuffled_order = Column(JSON, nullable=True)  # snapshot urutan soal teracak per-section {section_idx: [qid,...]}
    shuffled_options = Column(JSON, nullable=True)  # snapshot opsi teracak {qid: [opt_idx,...]}

    form = relationship("Form", back_populates="submissions")
    user = relationship("User", back_populates="submissions")
    answers = relationship("Answer", back_populates="submission", cascade="all, delete-orphan")


# ============================================================
# 7. ANSWERS
# ============================================================
class Answer(Base):
    __tablename__ = "answers"
    __table_args__ = (
        UniqueConstraint("submission_id", "question_id", name="uq_one_answer_per_question"),
    )

    id = Column(String(36), primary_key=True, default=gen_uuid)
    submission_id = Column(String(36), ForeignKey("submissions.id", ondelete="CASCADE"), nullable=False)
    question_id = Column(String(36), ForeignKey("questions.id", ondelete="CASCADE"), nullable=False)
    answer_text = Column(Text, nullable=True)
    answer_options = Column(JSON, nullable=True)
    file_url = Column(String, nullable=True)
    answered_at = Column(DateTime, default=datetime.utcnow)

    submission = relationship("Submission", back_populates="answers")
    question = relationship("Question", back_populates="answers")


# ============================================================
# 8. EMAIL VERIFICATIONS (OTP)
# ============================================================
class EmailVerification(Base):
    __tablename__ = "email_verifications"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    email = Column(String, nullable=False, index=True)
    otp_code = Column(String(6), nullable=False)
    purpose = Column(String(20), nullable=False, default="signup")
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)

