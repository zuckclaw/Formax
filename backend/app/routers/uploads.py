import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile

from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/uploads", tags=["uploads"])

_BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UPLOAD_DIR = os.path.join(_BASE_DIR, "static", "uploads")
BASE_URL = os.getenv("BASE_URL", "").strip().rstrip("/")

# FIX Bug: batchasi tipe file supaya tidak bisa upload HTML/JS (stored XSS kalau
# diserve static) atau file raksasa yang memenuhi disk.
ALLOWED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".gif", ".webp", ".pdf",
    ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".zip",
    # audio untuk RichTextEditor (fitur sisipkan audio dcb894e) — Opsi A
    ".mp3", ".wav", ".ogg", ".m4a", ".aac",
}
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB


def _check_magic(ext: str, content: bytes) -> bool:
    """Validasi magic-byte agar ekstensi tidak bisa dipalsukan (mis. .png berisi HTML/JS)."""
    if len(content) < 4:
        return False
    head = content[:12]
    if ext in (".jpg", ".jpeg"):
        return head[:3] == b"\xff\xd8\xff"
    if ext == ".png":
        return head[:8] == b"\x89PNG\r\n\x1a\n"
    if ext == ".gif":
        return head[:6] in (b"GIF87a", b"GIF89a")
    if ext == ".webp":
        return head[:4] == b"RIFF" and head[8:12] == b"WEBP"
    if ext == ".pdf":
        return head[:5] == b"%PDF-"
    if ext in (".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".zip"):
        # Office modern (OOXML) & zip = PK\x03\x04 ; .doc lama = OLE D0 CF 11 E0
        return head[:4] == b"PK\x03\x04" or head[:8] == b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"
    if ext == ".txt":
        # Tolak file teks yang sebenarnya HTML/SVG (bisa bawa <script> saat diserve).
        low = content[:512].lstrip().lower()
        if low.startswith((b"<html", b"<!doctype html", b"<script", b"<svg")):
            return False
        return True
    if ext in (".mp3", ".wav", ".ogg", ".m4a", ".aac"):
        # Audio: cek header umum, longgar agar tidak false-positive.
        if ext == ".mp3":
            return head[:3] == b"ID3" or head[:2] == b"\xff\xfb" or head[:2] == b"\xff\xf3"
        if ext == ".wav":
            return head[:4] == b"RIFF" and content[8:12] == b"WAVE"
        if ext == ".ogg":
            return head[:4] == b"OggS"
        if ext == ".m4a":
            return b"ftyp" in head
        # .aac ADTS sync (0xFFF) — longgar
        return True
    return False


@router.post("")
async def upload_file(
    request: Request,
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
):
    """
    Dipakai buat field tipe file_upload. Client upload file ke sini DULU,
    dapat balik file_url, baru URL itu yang dikirim ke PUT /submissions/{id}/answers.

    Wajib login (Bearer token).
    """

    ext = (os.path.splitext(file.filename or "")[1] or "").lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Tipe file '{ext or '(tanpa ekstensi)'}' tidak diizinkan")

    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="Ukuran file melebihi batas 10 MB")
    if not content:
        raise HTTPException(status_code=400, detail="File kosong")
    if not _check_magic(ext, content):
        raise HTTPException(status_code=400, detail=f"Isi file tidak sesuai ekstensi '{ext}' (kemungkinan file palsu)")

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.abspath(os.path.join(UPLOAD_DIR, filename))
    # Pastikan tidak ada path traversal (filename selalu uuid, tapi defense-in-depth).
    if os.path.commonpath([filepath, os.path.abspath(UPLOAD_DIR)]) != os.path.abspath(UPLOAD_DIR):
        raise HTTPException(status_code=400, detail="Nama file tidak valid")

    with open(filepath, "wb") as f:
        f.write(content)

    if BASE_URL:
        url_base = BASE_URL
        return {"file_url": f"{url_base}/static/uploads/{filename}"}

    return {"file_url": f"/static/uploads/{filename}"}
