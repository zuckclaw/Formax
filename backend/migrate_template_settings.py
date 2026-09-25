"""
Migrasi database lengkap untuk fitur 'Save as Template with Settings'.

Menambahkan semua kolom yang dibutuhkan di tabel templates agar
pengaturan form (fullscreen, token, acak, hasil, jadwal, tema, dll.)
tersimpan dengan benar saat form disimpan sebagai template.

Cocok untuk PostgreSQL (server live) dan SQLite (dev lokal).

Cara run:
    python migrate_template_settings.py

Script ini membaca DATABASE_URL dari .env secara otomatis.
"""
import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./formmaker.db")

# Kolom-kolom yang harus ada di tabel templates
TEMPLATE_COLUMNS = [
    ("accept_responses",   "BOOLEAN NOT NULL DEFAULT TRUE"),
    ("allow_see_result",   "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("max_submissions",    "INTEGER NOT NULL DEFAULT 0"),
    ("require_fullscreen", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("reveal_answers",     "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("shuffle_questions",  "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("shuffle_options",    "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("start_date",         "DATETIME"),
    ("end_date",           "DATETIME"),
    ("use_join_token",     "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("theme",              "JSON"),
]

# Kolom-kolom yang harus ada di tabel forms (jaga-jaga jika belum ada)
FORMS_COLUMNS = [
    ("allow_see_result",   "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("max_submissions",    "INTEGER NOT NULL DEFAULT 1"),
    ("require_fullscreen", "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("reveal_answers",     "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("shuffle_questions",  "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("shuffle_options",    "BOOLEAN NOT NULL DEFAULT FALSE"),
    ("start_date",         "DATETIME"),
    ("end_date",           "DATETIME"),
    ("theme",              "JSON"),
]


def _get_columns(conn, table, dialect):
    try:
        if dialect == "postgresql":
            rows = conn.execute(
                text("SELECT column_name FROM information_schema.columns WHERE table_name = :t"),
                {"t": table},
            ).fetchall()
            return {r[0] for r in rows}
        else:
            rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
            return {r[1] for r in rows}
    except Exception as e:
        print(f"  [WARN] Gagal baca kolom tabel {table}: {e}")
        return set()


def _table_exists(conn, table, dialect):
    try:
        if dialect == "postgresql":
            r = conn.execute(
                text("SELECT 1 FROM information_schema.tables WHERE table_name = :t"),
                {"t": table},
            ).first()
            return r is not None
        else:
            r = conn.execute(
                text("SELECT name FROM sqlite_master WHERE type='table' AND name=:t"),
                {"t": table},
            ).first()
            return r is not None
    except Exception:
        return False


def migrate(conn, dialect):
    added = 0

    # --- TEMPLATES ---
    if not _table_exists(conn, "templates", dialect):
        print("  [SKIP] Tabel 'templates' belum ada.")
    else:
        existing = _get_columns(conn, "templates", dialect)
        for col, coldef in TEMPLATE_COLUMNS:
            if col not in existing:
                if dialect == "postgresql":
                    conn.execute(text(
                        f"ALTER TABLE templates ADD COLUMN IF NOT EXISTS {col} {coldef}"
                    ))
                else:
                    conn.execute(text(
                        f"ALTER TABLE templates ADD COLUMN {col} {coldef}"
                    ))
                print(f"  [OK] templates.{col} ditambahkan")
                added += 1
            else:
                print(f"  [--] templates.{col} sudah ada")

    # --- FORMS ---
    if not _table_exists(conn, "forms", dialect):
        print("  [SKIP] Tabel 'forms' belum ada.")
    else:
        existing = _get_columns(conn, "forms", dialect)
        for col, coldef in FORMS_COLUMNS:
            if col not in existing:
                if dialect == "postgresql":
                    conn.execute(text(
                        f"ALTER TABLE forms ADD COLUMN IF NOT EXISTS {col} {coldef}"
                    ))
                else:
                    conn.execute(text(
                        f"ALTER TABLE forms ADD COLUMN {col} {coldef}"
                    ))
                print(f"  [OK] forms.{col} ditambahkan")
                added += 1
            else:
                print(f"  [--] forms.{col} sudah ada")

    return added


def main():
    print(f"Database : {DATABASE_URL[:80]}")
    engine = create_engine(DATABASE_URL)
    dialect = engine.dialect.name
    print(f"Dialect  : {dialect}\n")

    with engine.begin() as conn:
        added = migrate(conn, dialect)

    print(f"\nSelesai. {added} kolom baru ditambahkan.")
    if added == 0:
        print("(Semua kolom sudah ada, tidak ada yang perlu diubah.)")


if __name__ == "__main__":
    main()
