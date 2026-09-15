import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query, Request
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user, security_scheme
from ..utils.mail import send_otp_email
from ..utils.emoji_filter import contains_emoji, remove_emojis

router = APIRouter(prefix="/auth", tags=["auth"])

# Rate-limit in-memory (single-process) untuk cegah brute-force OTP 6-digit
# dan spam kirim OTP. Bukan pengganti Redis di multi-worker, tapi jauh lebih
# aman daripada tanpa batas sama sekali. Key kedaluwarsa di-prune tiap check
# + cap jumlah key agar tidak leak memori.
_rl_store: dict[str, list[float]] = {}
_RL_MAX_KEYS = 10000


def _rl_check(key: str, limit: int, window_sec: int, message: str) -> None:
    now = time.time()
    lst = _rl_store.get(key, [])
    lst = [t for t in lst if now - t < window_sec]
    if len(lst) >= limit:
        raise HTTPException(status_code=429, detail=message)
    lst.append(now)
    _rl_store[key] = lst
    if len(_rl_store) > _RL_MAX_KEYS:
        expired = [k for k, v in _rl_store.items() if not v or (now - v[-1] > window_sec)]
        for k in expired[:1000]:
            _rl_store.pop(k, None)


def _rl_reset(key: str) -> None:
    _rl_store.pop(key, None)


def _client_ip(request: Request | None) -> str:
    try:
        if request is not None and request.client is not None:
            return request.client.host or "unknown"
    except Exception:
        pass
    return "unknown"


def _payload_expires_at_naive(payload: dict) -> Optional[datetime]:
    try:
        exp = payload.get("exp")
        if exp is None:
            return None
        # python-jose memberi timestamp int; bisa juga datetime.
        if isinstance(exp, (int, float)):
            return datetime.fromtimestamp(float(exp), tz=timezone.utc).replace(tzinfo=None)
        if isinstance(exp, datetime):
            return exp.astimezone(timezone.utc).replace(tzinfo=None) if exp.tzinfo else exp
    except Exception:
        pass
    return None


def _revoke_payload(db: Session, payload: dict, reason: str = "logout") -> bool:
    jti = payload.get("jti")
    if not jti:
        return False  # token lama tanpa jti: tidak ada yang dicabut (backward-compat)
    try:
        exists = db.query(models.RevokedToken).filter(models.RevokedToken.jti == jti).first()
        if exists:
            return False
        db.add(models.RevokedToken(
            jti=str(jti),
            user_id=str(payload.get("sub")) if payload.get("sub") else None,
            expires_at=_payload_expires_at_naive(payload),
            reason=reason,
        ))
        db.commit()
        return True
    except Exception:
        try:
            db.rollback()
        except Exception:
            pass
        return False


def _cleanup_expired_revoked(db: Session) -> None:
    try:
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        db.query(models.RevokedToken).filter(
            models.RevokedToken.expires_at.isnot(None),
            models.RevokedToken.expires_at < now_naive,
        ).delete(synchronize_session=False)
        db.commit()
    except Exception:
        try:
            db.rollback()
        except Exception:
            pass


@router.post("/send-otp")
def send_otp(
    payload: schemas.SendOTPRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    request: Request = None,
):
    email = str(payload.email).strip().lower()
    _rl_check(f"send-otp:email:{email}", 5, 3600, "Terlalu sering meminta OTP. Coba lagi dalam 1 jam.")
    _rl_check(f"send-otp:ip:{_client_ip(request)}", 20, 3600, "Terlalu banyak permintaan dari IP ini. Coba lagi nanti.")
    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    # Hapus OTP signup lama agar tidak menumpuk & tidak bisa dipakai ulang,
    # lalu buat OTP baru dengan CSPRNG.
    db.query(models.EmailVerification).filter(
        func.lower(models.EmailVerification.email) == email,
        models.EmailVerification.purpose == "signup",
    ).delete(synchronize_session=False)
    db.commit()

    otp_code = f"{secrets.randbelow(10**6):06d}"

    verification = models.EmailVerification(
        email=email,
        otp_code=otp_code,
        purpose="signup",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5)
    )
    db.add(verification)
    db.commit()

    background_tasks.add_task(send_otp_email, email, otp_code)

    return {"message": "OTP berhasil dikirim"}

@router.post("/forgot-password")
def forgot_password(
    payload: schemas.ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    request: Request = None,
):
    email = str(payload.email).strip().lower()
    _rl_check(f"forgot:email:{email}", 5, 3600, "Terlalu sering meminta reset. Coba lagi dalam 1 jam.")
    _rl_check(f"forgot:ip:{_client_ip(request)}", 20, 3600, "Terlalu banyak permintaan dari IP ini. Coba lagi nanti.")
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    # Jangan membocorkan apakah alamat email terdaftar.
    if user:
        otp_code = f"{secrets.randbelow(10**6):06d}"
        db.query(models.EmailVerification).filter(
            func.lower(models.EmailVerification.email) == email,
            models.EmailVerification.purpose == "password_reset",
        ).delete(synchronize_session=False)
        db.add(models.EmailVerification(
            email=email,
            otp_code=otp_code,
            purpose="password_reset",
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
        ))
        db.commit()
        background_tasks.add_task(send_otp_email, email, otp_code, "Reset Password")
    return {"message": "Jika email terdaftar, kode reset telah dikirim"}


@router.post("/reset-password")
def reset_password(payload: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    _rl_check(f"otp-verify:email:{email}", 10, 600, "Terlalu banyak percobaan OTP. Tunggu 10 menit.")
    if len(payload.new_password) < 6:
        raise HTTPException(status_code=422, detail="Password minimal 6 karakter")
    verification = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp.strip())
        .filter(models.EmailVerification.purpose == "password_reset")
        .first()
    )
    if not verification:
        raise HTTPException(status_code=400, detail="OTP reset tidak valid")
    _exp = verification.expires_at
    if _exp is not None and _exp.tzinfo is None:
        _exp = _exp.replace(tzinfo=timezone.utc)
    if _exp is not None and _exp < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="OTP reset sudah kedaluwarsa")
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="OTP reset tidak valid")
    user.password_hash = security.hash_password(payload.new_password)
    db.delete(verification)
    db.commit()
    _rl_reset(f"otp-verify:email:{email}")
    access_token = security.create_access_token({"sub": str(user.id)})
    refresh_token = security.create_refresh_token({"sub": str(user.id)})
    return {"message": "Password berhasil diubah", "access_token": access_token, "refresh_token": refresh_token}


@router.post("/verify-reset-otp")
def verify_reset_otp(payload: schemas.VerifyResetOtpRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    _rl_check(f"otp-verify:email:{email}", 10, 600, "Terlalu banyak percobaan OTP. Tunggu 10 menit.")
    verification = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp.strip())
        .filter(models.EmailVerification.purpose == "password_reset")
        .first()
    )
    if not verification:
        raise HTTPException(status_code=400, detail="OTP reset tidak valid atau sudah kedaluwarsa")
    _exp = verification.expires_at
    if _exp is not None and _exp.tzinfo is None:
        _exp = _exp.replace(tzinfo=timezone.utc)
    if _exp is not None and _exp < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="OTP reset tidak valid atau sudah kedaluwarsa")
    return {"message": "OTP valid"}

@router.post("/signup", response_model=schemas.TokenResponse)
def signup(payload: schemas.SignUpRequest, db: Session = Depends(get_db), request: Request = None):
    email = str(payload.email).strip().lower()
    _rl_check(f"otp-verify:email:{email}", 10, 600, "Terlalu banyak percobaan OTP. Tunggu 10 menit.")
    _rl_check(f"signup:ip:{_client_ip(request)}", 20, 3600, "Terlalu banyak pendaftaran dari IP ini. Coba lagi nanti.")
    if contains_emoji(payload.full_name):
        raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh mengandung emoji")
    clean_name = remove_emojis(payload.full_name).strip()
    if not clean_name:
        raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh kosong")

    # Cek email dulu SEBELUM hapus OTP, agar OTP tidak hangus saat signup gagal.
    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    otp_record = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp.strip())
        .filter(models.EmailVerification.purpose == "signup")
        .first()
    )
    if not otp_record:
        raise HTTPException(status_code=400, detail="OTP tidak valid")

    _exp = otp_record.expires_at
    if _exp is not None and _exp.tzinfo is None:
        _exp = _exp.replace(tzinfo=timezone.utc)
    if _exp is not None and _exp < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="OTP sudah kedaluwarsa")

    db.query(models.EmailVerification).filter(
        func.lower(models.EmailVerification.email) == email,
        models.EmailVerification.purpose == "signup",
    ).delete()

    user = models.User(
        full_name=clean_name,
        email=email,
        password_hash=security.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    _rl_reset(f"otp-verify:email:{email}")
    token = security.create_access_token({"sub": str(user.id)})
    refresh = security.create_refresh_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token, refresh_token=refresh)


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db), request: Request = None):
    email = str(payload.email).strip().lower()
    _rl_check(f"login:email:{email}", 10, 300, "Terlalu banyak percobaan login. Tunggu 5 menit.")
    _rl_check(f"login:ip:{_client_ip(request)}", 30, 300, "Terlalu banyak login dari IP ini. Tunggu 5 menit.")
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user or not security.verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email atau password salah")

    _rl_reset(f"login:email:{email}")
    # remember me -> 30 hari, else 7 hari default. Refresh mengikuti masa access
    # agar sesi non-remember tidak diperpanjang diam-diam menjadi 30 hari.
    expire = security.REMEMBER_ME_EXPIRE_MINUTES if payload.remember else security.ACCESS_TOKEN_EXPIRE_MINUTES
    token = security.create_access_token({"sub": str(user.id)}, expires_minutes=expire)
    refresh = security.create_refresh_token({"sub": str(user.id)}, expires_minutes=expire)
    return schemas.TokenResponse(access_token=token, refresh_token=refresh)


@router.post("/logout")
def logout(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    refresh_token: Optional[str] = Query(default=None, description="Refresh token untuk ikut dicabut"),
):
    # Cabut access jti saat ini agar token curian tidak bisa dipakai lagi.
    # Token lama tanpa jti: tidak ada yang dicabut, hanya hapus sisi client (backward-compat).
    try:
        if credentials is not None:
            payload = security.decode_access_token(credentials.credentials)
            if payload:
                _revoke_payload(db, payload, reason="logout")
    except Exception:
        pass
    # Cabut refresh juga bila dikirim (query ?refresh_token=...), agar sesi benar-benar mati.
    if refresh_token:
        try:
            rp = security.decode_access_token(refresh_token)
            if rp and str(rp.get("sub")) == str(current_user.id):
                _revoke_payload(db, rp, reason="logout")
        except Exception:
            pass
    _cleanup_expired_revoked(db)
    return {"message": "Logout berhasil, hapus token di sisi client"}


@router.post("/refresh", response_model=schemas.TokenResponse)
def refresh_session(
    payload: schemas.RefreshRequest,
    db: Session = Depends(get_db),
    request: Request = None,
):
    _rl_check(f"refresh:ip:{_client_ip(request)}", 30, 300, "Terlalu banyak refresh. Tunggu 5 menit.")
    data = security.decode_access_token(payload.refresh_token)
    if not data or "sub" not in data:
        raise HTTPException(status_code=401, detail="Refresh token tidak valid atau kadaluarsa, silakan login ulang")
    # Hanya refresh bertipe refresh yang boleh ditukar. Access lama tanpa typ
    # ditolak di sini (harus login ulang sekali untuk dapat pasangan baru).
    if data.get("typ") != "refresh":
        raise HTTPException(status_code=401, detail="Refresh token tidak valid atau kadaluarsa, silakan login ulang")
    # Cek denylist (sudah logout / sudah dirotasi).
    jti = data.get("jti")
    if jti and db.query(models.RevokedToken).filter(models.RevokedToken.jti == str(jti)).first():
        raise HTTPException(status_code=401, detail="Refresh token tidak valid atau kadaluarsa, silakan login ulang")
    user = db.query(models.User).filter(models.User.id == str(data["sub"])).first()
    if user is None:
        raise HTTPException(status_code=401, detail="Refresh token tidak valid atau kadaluarsa, silakan login ulang")
    # Rotasi sekali pakai: cabut refresh lama, terbitkan pasangan baru.
    if not _revoke_payload(db, data, reason="rotated"):
        # Refresh token sudah dipakai oleh request lain, atau revoke gagal.
        # Jangan menerbitkan token baru jika rotasi atomik tidak berhasil.
        raise HTTPException(status_code=401, detail="Refresh token tidak valid atau sudah digunakan, silakan login ulang")
    _cleanup_expired_revoked(db)
    new_access = security.create_access_token({"sub": str(user.id)})
    new_refresh = security.create_refresh_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=new_access, refresh_token=new_refresh)


@router.get("/me", response_model=schemas.UserOut)
def get_me(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=schemas.UserOut)
def update_me(
    payload: schemas.ProfileUpdateRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if payload.full_name is not None:
        if contains_emoji(payload.full_name):
            raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh mengandung emoji")
        clean_name = remove_emojis(payload.full_name).strip()
        if not clean_name:
            raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh kosong")
        current_user.full_name = clean_name

    if payload.email is not None:
        email = str(payload.email).strip().lower()
        existing_user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
        if existing_user and existing_user.id != current_user.id:
            raise HTTPException(status_code=400, detail="Email sudah terdaftar")
        current_user.email = email

    if payload.avatar_url is not None:
        current_user.avatar_url = payload.avatar_url

    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/change-password")
def change_password(
    payload: schemas.ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if not security.verify_password(payload.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Password lama Anda salah")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password baru minimal 6 karakter")

    current_user.password_hash = security.hash_password(payload.new_password)
    db.add(current_user)
    db.commit()
    return {"message": "Password berhasil diubah"}

