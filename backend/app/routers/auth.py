import random
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..deps import get_db, get_current_user
from ..utils.mail import send_otp_email
from ..utils.emoji_filter import contains_emoji, remove_emojis

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/send-otp")
def send_otp(payload: schemas.SendOTPRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    otp_code = str(random.randint(100000, 999999))

    verification = models.EmailVerification(
        email=email,
        otp_code=otp_code,
        purpose="signup",
        expires_at=datetime.utcnow() + timedelta(minutes=5)
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
):
    email = str(payload.email).strip().lower()
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    # Jangan membocorkan apakah alamat email terdaftar.
    if user:
        otp_code = str(random.randint(100000, 999999))
        db.query(models.EmailVerification).filter(
            func.lower(models.EmailVerification.email) == email,
            models.EmailVerification.purpose == "password_reset",
        ).delete(synchronize_session=False)
        db.add(models.EmailVerification(
            email=email,
            otp_code=otp_code,
            purpose="password_reset",
            expires_at=datetime.utcnow() + timedelta(minutes=5),
        ))
        db.commit()
        background_tasks.add_task(send_otp_email, email, otp_code, "Reset Password")
    return {"message": "Jika email terdaftar, kode reset telah dikirim"}


@router.post("/reset-password")
def reset_password(payload: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
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
    if verification.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="OTP reset sudah kedaluwarsa")
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user:
        raise HTTPException(status_code=400, detail="OTP reset tidak valid")
    user.password_hash = security.hash_password(payload.new_password)
    db.delete(verification)
    db.commit()
    access_token = security.create_access_token({"sub": str(user.id)})
    return {"message": "Password berhasil diubah", "access_token": access_token}


@router.post("/verify-reset-otp")
def verify_reset_otp(payload: schemas.VerifyResetOtpRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    verification = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp.strip())
        .filter(models.EmailVerification.purpose == "password_reset")
        .first()
    )
    if not verification or verification.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="OTP reset tidak valid atau sudah kedaluwarsa")
    return {"message": "OTP valid"}

@router.post("/signup", response_model=schemas.TokenResponse)
def signup(payload: schemas.SignUpRequest, db: Session = Depends(get_db)):
    if contains_emoji(payload.full_name):
        raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh mengandung emoji")
    clean_name = remove_emojis(payload.full_name).strip()
    if not clean_name:
        raise HTTPException(status_code=400, detail="Nama lengkap tidak boleh kosong")

    email = str(payload.email).strip().lower()
    otp_record = (
        db.query(models.EmailVerification)
        .filter(func.lower(models.EmailVerification.email) == email)
        .filter(models.EmailVerification.otp_code == payload.otp)
        .first()
    )
    if not otp_record:
        raise HTTPException(status_code=400, detail="OTP tidak valid")
    
    if otp_record.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="OTP sudah kedaluwarsa")
    
    db.query(models.EmailVerification).filter(func.lower(models.EmailVerification.email) == email).delete()

    existing = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email sudah terdaftar")

    user = models.User(
        full_name=clean_name,
        email=email,
        password_hash=security.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = security.create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)


@router.post("/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    email = str(payload.email).strip().lower()
    user = db.query(models.User).filter(func.lower(models.User.email) == email).first()
    if not user or not security.verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email atau password salah")

    # remember me -> 30 hari, else 7 hari default
    expire = security.REMEMBER_ME_EXPIRE_MINUTES if payload.remember else security.ACCESS_TOKEN_EXPIRE_MINUTES
    token = security.create_access_token({"sub": str(user.id)}, expires_minutes=expire)
    return schemas.TokenResponse(access_token=token)


@router.post("/logout")
def logout(current_user: models.User = Depends(get_current_user)):
    # JWT stateless: cukup instruksikan client hapus token yang tersimpan.
    return {"message": "Logout berhasil, hapus token di sisi client"}


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

