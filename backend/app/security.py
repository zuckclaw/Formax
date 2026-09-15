import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext

from dotenv import load_dotenv

load_dotenv()

_PLACEHOLDERS = {
    "",
    "change-this-secret-in-production",
    "ganti-dengan-random-string-panjang-dan-rahasia",
}

_env_secret = (os.getenv("SECRET_KEY") or "").strip()
if not _env_secret or _env_secret in _PLACEHOLDERS or len(_env_secret) < 32:
    raise RuntimeError(
        "SECRET_KEY tidak valid: isi SECRET_KEY di environment/.env "
        "dengan string acak minimal 32 karakter. "
        "Generate: python -c \"import secrets; print(secrets.token_urlsafe(48))\""
    )

SECRET_KEY = _env_secret
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 hari default
REMEMBER_ME_EXPIRE_MINUTES = 60 * 24 * 30  # 30 hari untuk remember me
REFRESH_TOKEN_EXPIRE_MINUTES = 60 * 24 * 30  # refresh 30 hari (dipakai /auth/refresh)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(data: dict, expires_minutes: int = ACCESS_TOKEN_EXPIRE_MINUTES) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    # jti untuk denylist logout + rotasi refresh. Token lama tanpa jti tetap valid (backward-compat).
    to_encode.setdefault("jti", secrets.token_hex(16))
    to_encode.setdefault("typ", "access")
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict, expires_minutes: int = REFRESH_TOKEN_EXPIRE_MINUTES) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    to_encode["jti"] = secrets.token_hex(16)
    to_encode["typ"] = "refresh"
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None


def generate_join_token(length: int = 6) -> str:
    """Generate kode pendek buat fitur ujian bareng, ex: 'K3F9QZ'."""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # tanpa karakter yang gampang ketuker (0/O, 1/I)
    return "".join(secrets.choice(alphabet) for _ in range(length))
