import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .routers import auth, templates, forms, submissions, uploads, export, questions, search, import_docx, ai

from sqlalchemy import text, inspect

# Buat semua tabel otomatis kalau belum ada (development).
try:
    Base.metadata.create_all(bind=engine)
    # dispose pool agar koneksi create_all tidak mengunci pool untuk migrasi berikut
    # (fix hang: create_all + engine.begin() deadlock di postgres, lihat test_pg6.py)
    try:
        engine.dispose()
    except Exception:
        pass
except Exception as _e:
    print(f"[migrate] create_all failed: {_e}")


def _column_exists_conn(conn, table_name: str, column_name: str, dialect: str) -> bool:
    """Cek kolom pakai conn yang sama (hindari inspect(engine) di dalam transaksi -> deadlock SQLite)."""
    try:
        if dialect == "postgresql":
            r = conn.execute(text(
                "SELECT 1 FROM information_schema.columns WHERE table_name=:t AND column_name=:c"
            ), {"t": table_name, "c": column_name}).first()
            return r is not None
        else:
            rows = conn.execute(text(f"PRAGMA table_info({table_name})")).fetchall()
            # pragma: cid, name, type, notnull, dflt, pk
            return any(row[1] == column_name for row in rows)
    except Exception:
        return False


def _table_exists_conn(conn, table_name: str, dialect: str) -> bool:
    try:
        if dialect == "postgresql":
            r = conn.execute(text(
                "SELECT 1 FROM information_schema.tables WHERE table_name=:t"
            ), {"t": table_name}).first()
            return r is not None
        else:
            r = conn.execute(text(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=:t"
            ), {"t": table_name}).first()
            return r is not None
    except Exception:
        return False


# Auto-migrate ringan & schema update — dibungkus try agar tidak bikin uvicorn stuck
try:
    with engine.begin() as conn:
        dialect = engine.dialect.name

        def add_column(table: str, column: str, coldef: str):
            if not _column_exists_conn(conn, table, column, dialect):
                if dialect == "postgresql":
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {coldef}"))
                else:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {coldef}"))

        # Migrasi banner & opsi soal
        if _table_exists_conn(conn, "forms", dialect) and not _column_exists_conn(conn, "forms", "banner_url", dialect):
            conn.execute(text("ALTER TABLE forms ADD COLUMN banner_url VARCHAR;"))

        if _table_exists_conn(conn, "templates", dialect) and not _column_exists_conn(conn, "templates", "banner_url", dialect):
            conn.execute(text("ALTER TABLE templates ADD COLUMN banner_url VARCHAR;"))

        if _table_exists_conn(conn, "question_options", dialect) and not _column_exists_conn(conn, "question_options", "is_correct", dialect):
            conn.execute(text("ALTER TABLE question_options ADD COLUMN is_correct BOOLEAN;"))

        if _table_exists_conn(conn, "question_options", dialect) and not _column_exists_conn(conn, "question_options", "is_other", dialect):
            if dialect == "postgresql":
                conn.execute(text("ALTER TABLE question_options ADD COLUMN IF NOT EXISTS is_other BOOLEAN;"))
            else:
                conn.execute(text("ALTER TABLE question_options ADD COLUMN is_other BOOLEAN;"))

        # Backfill: opsi lama yang belum punya nilai dianggap bukan jawaban benar
        if _table_exists_conn(conn, "question_options", dialect):
            try:
                conn.execute(text("UPDATE question_options SET is_correct = FALSE WHERE is_correct IS NULL;"))
                conn.execute(text("UPDATE question_options SET is_other = FALSE WHERE is_other IS NULL;"))
            except Exception:
                pass

        # Setting baru Form Builder
        add_column("forms", "allow_see_result", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("forms", "max_submissions", "INTEGER NOT NULL DEFAULT 1")
        add_column("forms", "require_fullscreen", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("forms", "reveal_answers", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("forms", "shuffle_questions", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("forms", "shuffle_options", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("submissions", "is_cheated", "BOOLEAN NOT NULL DEFAULT FALSE")
        add_column("submissions", "shuffled_order", "JSON")
        add_column("submissions", "shuffled_options", "JSON")
        # Fix 500 /submissions/me — kolom baru untuk anonim (Google-Forms style)
        add_column("submissions", "respondent_key", "VARCHAR(64)")
        add_column("email_verifications", "purpose", "VARCHAR(20) NOT NULL DEFAULT 'signup'")
        # user_id sekarang boleh NULL untuk submission anonim
        try:
            if dialect == "postgresql":
                conn.execute(text("ALTER TABLE submissions ALTER COLUMN user_id DROP NOT NULL"))
        except Exception:
            pass

        # Hapus unique constraint (form_id, user_id) supaya multi-submit bisa jalan — SQLite only
        if dialect != "postgresql":
            try:
                indexes = conn.execute(
                    text("SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name='submissions'")
                ).fetchall()
                drop = False
                for name, sql in indexes:
                    if sql and "uq_one_submission_per_user_per_form" in sql:
                        drop = True
                        break
                    if not sql and name and name.startswith("sqlite_autoindex_submissions"):
                        cols = [r[2] for r in conn.execute(text(f"PRAGMA index_info({name})")).fetchall()]
                        if cols == ["form_id", "user_id"] or cols == ["user_id", "form_id"]:
                            drop = True
                            break
                if drop:
                    # cek kolom existing pakai pragma di conn yang sama
                    try:
                        pragma_rows = conn.execute(text("PRAGMA table_info(submissions)")).fetchall()
                        existing = {row[1] for row in pragma_rows}
                    except Exception:
                        existing = set()
                    cols_all = ["id", "form_id", "user_id", "respondent_key", "started_at", "is_auto_submitted", "submitted_at", "is_cheated", "shuffled_order", "shuffled_options"]
                    cols = [c for c in cols_all if c in existing or c in ("id","form_id")]
                    if not cols:
                        cols = ["id", "form_id", "user_id", "respondent_key", "started_at", "is_auto_submitted", "submitted_at", "is_cheated"]
                    cols_sql = ", ".join(cols)
                    conn.execute(text("DROP TABLE IF EXISTS submissions_new"))
                    conn.execute(text("""CREATE TABLE submissions_new (
                        id VARCHAR(36) NOT NULL,
                        form_id VARCHAR(36) NOT NULL,
                        user_id VARCHAR(36),
                        respondent_key VARCHAR(64),
                        started_at DATETIME,
                        is_auto_submitted BOOLEAN,
                        submitted_at DATETIME,
                        is_cheated BOOLEAN NOT NULL DEFAULT 0,
                        shuffled_order JSON,
                        shuffled_options JSON,
                        PRIMARY KEY (id)
                    )"""))
                    conn.execute(text(f"INSERT INTO submissions_new ({cols_sql}) SELECT {cols_sql} FROM submissions"))
                    conn.execute(text("DROP TABLE submissions"))
                    conn.execute(text("ALTER TABLE submissions_new RENAME TO submissions"))
            except Exception as _e:
                print(f"[migrate] sqlite submissions recreate failed: {_e}")

        # PostgreSQL: drop constraint terpisah (tidak butuh rebuild)
        if dialect == "postgresql":
            try:
                conn.execute(
                    text("ALTER TABLE submissions DROP CONSTRAINT IF EXISTS uq_one_submission_per_user_per_form")
                )
            except Exception as _e:
                print(f"[migrate] drop constraint failed: {_e}")

except Exception as _e:
    print(f"[migrate] auto-migrate failed (akan lanjut, cek manual): {_e}")
    import traceback as _tb
    _tb.print_exc()

# Tambah nilai enum baru untuk PostgreSQL — harus di luar transaksi (ADD VALUE tidak boleh di dalam BEGIN)
try:
    if engine.dialect.name == "postgresql":
        # gunakan engine dengan AUTOCOMMIT
        with engine.connect() as c:
            c = c.execution_options(isolation_level="AUTOCOMMIT")
            for val in [
                'text',
                'paragraph',
                'single_choice',
                'checkbox',
                'dropdown',
                'date',
                'time',
                'file_upload',
                'linear_scale',
                'rating',
                'multiple_choice_grid',
                'tick_box_grid',
                'page_break',
                'image',
                'text_block',
            ]:
                try:
                    c.execute(text(f"ALTER TYPE questiontype ADD VALUE IF NOT EXISTS '{val}'"))
                except Exception as _e:
                    # enum sudah ada atau tidak bisa — skip
                    pass
except Exception as _e:
    print(f"[migrate] enum add failed: {_e}")


app = FastAPI(title="Form Maker API", version="2.0.0")

# CORS: baca dari env ALLOWED_ORIGINS (comma-separated), fallback buka untuk ngrok/Vercel
_allowed_origins_raw = os.getenv("ALLOWED_ORIGINS", "")
_allowed_origins = [o.strip() for o in _allowed_origins_raw.split(",") if o.strip()] if _allowed_origins_raw.strip() else []

if _allowed_origins:
    # Production: origin eksplisit + regex untuk semua preview Vercel (formax-*.vercel.app)
    # Ini fix OPTIONS 400 di branch preview seperti fathinjam -> https://formax-b68duq2b1-fthnjamaluddn.vercel.app
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_allowed_origins,
        # Izin origin dev (Flutter Web pakai port acak localhost, React dev 5173/3000)
        # supaya preflight CORS tidak kena "400 Disallowed CORS origin" -> image
        # gagal tampil "HTTP request failed, statusCode: 0" di Flutter Web.
        allow_origin_regex=r"https://formax.*\.vercel\.app|http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    # Dev / ngrok tunnel: allow semua origin (Bearer token tidak butuh cookies)
    # Ini yang fix Cross-Origin di https://formax-seven.vercel.app -> ngrok-free.dev
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Fix OpaqueResponseBlocking untuk <img> dari Vercel → ngrok
# CORP header wajib agar browser tidak block opaque image meskipun COEP aktif
@app.middleware("http")
async def add_corp_header(request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/static"):
        # Izinkan embed cross-origin untuk banner & upload
        response.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
        response.headers["Cross-Origin-Embedder-Policy"] = "unsafe-none"
        # Pastikan CORS tetap ada untuk static (StaticFiles tidak lewat CORSMiddleware di beberapa versi)
        origin = request.headers.get("origin")
        if origin:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Methods"] = "*"
            response.headers["Access-Control-Allow-Headers"] = "*"
        else:
            response.headers["Access-Control-Allow-Origin"] = "*"
    return response

# Serve file QR code & hasil upload
app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(auth.router)
app.include_router(templates.router)
app.include_router(forms.router)
app.include_router(questions.router)
app.include_router(submissions.router)
app.include_router(uploads.router)
app.include_router(export.router)
app.include_router(search.router)
app.include_router(import_docx.router)
app.include_router(ai.router)


@app.get("/")
def root():
    return {"message": "Form Maker API v2 is running"}
