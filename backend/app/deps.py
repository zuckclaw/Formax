from typing import Optional
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from .database import SessionLocal
from . import models
from .security import decode_access_token

security_scheme = HTTPBearer(auto_error=False)
security_scheme_optional = HTTPBearer(auto_error=False)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _is_revoked(db: Session, jti: Optional[str]) -> bool:
    if not jti:
        return False
    try:
        return db.query(models.RevokedToken).filter(models.RevokedToken.jti == jti).first() is not None
    except Exception as exc:
        # Denylist adalah bagian dari validasi token. Jika DB tidak bisa dibaca,
        # fail-closed agar token yang sudah dicabut tidak lolos saat outage.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Layanan autentikasi sedang tidak tersedia, coba lagi nanti",
        ) from exc


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token tidak valid atau kadaluarsa, silakan login ulang",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise credentials_exception
    token = credentials.credentials
    payload = decode_access_token(token)
    if payload is None or "sub" not in payload:
        raise credentials_exception
    # Refresh token tidak boleh dipakai untuk API biasa (hanya /auth/refresh).
    # Token lama tanpa typ tetap diterima sebagai access (backward-compat).
    if payload.get("typ") == "refresh":
        raise credentials_exception
    if _is_revoked(db, payload.get("jti")):
        raise credentials_exception

    user = db.query(models.User).filter(models.User.id == str(payload["sub"])).first()
    if user is None:
        raise credentials_exception
    return user


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme_optional),
    db: Session = Depends(get_db),
) -> Optional[models.User]:
    """Return the logged-in user or None if not authenticated.

    Mirip get_current_user, tapi TIDAK melempar error ketika token tidak ada/tidak valid.
    Dipakai untuk alur isi form anonim (Google-Forms style): kalau login, identitasnya =
    user.id; kalau tidak, pakai respondent_key.
    """
    try:
        if credentials is None:
            return None
        token = credentials.credentials
        payload = decode_access_token(token)
        if payload is None or "sub" not in payload:
            return None
        if payload.get("typ") == "refresh":
            return None
        if _is_revoked(db, payload.get("jti")):
            return None
        user = db.query(models.User).filter(models.User.id == str(payload["sub"])).first()
        return user
    except Exception:
        return None


def get_respondent_key(x_respondent_key: Optional[str] = Header(default=None)) -> Optional[str]:
    """Anonymous identity: UUID string produced by the client (web/mobile) and sent
    in header X-Respondent-Key. Returned as-is; endpoints validate it."""
    if x_respondent_key is None:
        return None
    key = x_respondent_key.strip()
    if not key:
        return None
    # Batasi panjang agar tidak jadi vektor DoS / error DB (kolom VARCHAR(64)).
    # Format longgar (UUID v4 / anon-xxx) agar kompatibel dengan client lama,
    # tapi tolak karakter kontrol & string raksasa.
    if len(key) > 64 or any(ord(c) < 32 or ord(c) == 127 for c in key):
        raise HTTPException(status_code=400, detail="X-Respondent-Key tidak valid")
    return key

