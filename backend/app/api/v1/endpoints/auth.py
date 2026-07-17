import logging
import re
import secrets
import uuid as uuid_lib
from datetime import datetime, timedelta, timezone

import google.auth.transport.requests as google_requests
import google.oauth2.id_token as google_id_token

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, get_password_hash, verify_password
from app.core.limiter import limiter
from app.models.user import User
from app.schemas.auth import Token
from app.schemas.user import UserCreate, UserResponse

router = APIRouter()


class GoogleTokenRequest(BaseModel):
    id_token: str


class VerifyEmailRequest(BaseModel):
    token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


@router.post("/register", response_model=UserResponse, status_code=201)
@limiter.limit("10/minute")
def register(request: Request, user_in: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user_in.email).first():
        raise HTTPException(status_code=400, detail="이미 사용 중인 이메일입니다")
    if db.query(User).filter(User.username == user_in.username).first():
        raise HTTPException(status_code=400, detail="이미 사용 중인 사용자명입니다")

    verify_token = secrets.token_urlsafe(32)
    user = User(
        email=user_in.email,
        username=user_in.username,
        full_name=user_in.full_name,
        phone=user_in.phone,
        hashed_password=get_password_hash(user_in.password),
        email_verified=False,
        email_verify_token=verify_token,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    # TODO: 실제 운영 시 이메일 발송으로 교체
    logger.warning(
        "EMAIL VERIFY TOKEN (dev only): email=%s token=%s", user.email, verify_token
    )
    return user


@router.post("/verify-email", status_code=200)
def verify_email(body: VerifyEmailRequest, db: Session = Depends(get_db)):
    """이메일 인증 토큰 확인."""
    user = db.query(User).filter(
        User.email_verify_token == body.token,
        User.deleted_at.is_(None),
    ).first()
    if not user:
        raise HTTPException(status_code=400, detail="유효하지 않은 인증 토큰입니다")
    user.email_verified = True
    user.email_verify_token = None
    db.commit()
    return {"message": "이메일 인증이 완료되었습니다"}


@router.post("/google", response_model=Token)
@limiter.limit("20/minute")
def google_login(request: Request, body: GoogleTokenRequest, db: Session = Depends(get_db)):
    """Google ID 토큰을 검증하고 JWT를 발급한다.

    클라이언트(Flutter/웹)에서 google_sign_in으로 얻은 idToken을 전달하면
    백엔드가 Google 공개키로 서명을 검증한 뒤, 신규 사용자는 자동 생성한다.

    GOOGLE_CLIENT_ID가 설정되지 않은 경우 개발/테스트 환경에서만 임시로 허용한다.
    """
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=503,
            detail=(
                "Google OAuth가 설정되지 않았습니다. "
                ".env에 GOOGLE_CLIENT_ID를 설정하세요. "
                "발급: https://console.cloud.google.com/apis/credentials"
            ),
        )

    try:
        idinfo = google_id_token.verify_oauth2_token(
            body.id_token,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Google 토큰 검증 실패: {e}")

    google_id = idinfo["sub"]
    email = idinfo.get("email", "")
    full_name = idinfo.get("name")

    # 기존 구글 계정 사용자 조회
    user = db.query(User).filter(User.google_id == google_id).first()

    if user is None:
        # 같은 이메일로 기존 이메일/비밀번호 계정이 있으면 연동
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.google_id = google_id
            db.commit()
        else:
            # 신규 가입 - username은 이메일 앞부분 + 랜덤 suffix
            base_username = re.sub(r"[^a-z0-9]", "", email.split("@")[0].lower()) or "user"
            username = base_username
            # 충돌 방지
            if db.query(User).filter(User.username == username).first():
                username = f"{base_username}_{uuid_lib.uuid4().hex[:6]}"

            user = User(
                email=email,
                username=username,
                full_name=full_name,
                google_id=google_id,
                hashed_password=None,
            )
            db.add(user)
            db.commit()
            db.refresh(user)

    if not user.is_active:
        raise HTTPException(status_code=400, detail="비활성화된 계정입니다")

    return Token(access_token=create_access_token(str(user.id)))


@router.post("/login", response_model=Token)
@limiter.limit("20/minute")
def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="이메일 또는 비밀번호가 올바르지 않습니다",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(status_code=400, detail="비활성화된 계정입니다")
    return Token(access_token=create_access_token(str(user.id)))


@router.post("/forgot-password", status_code=200)
@limiter.limit("5/minute")
def forgot_password(request: Request, body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """비밀번호 재설정 토큰 발급.

    보안상 이메일 존재 여부와 무관하게 동일한 응답을 반환한다.
    실제 운영 시 이메일로 토큰을 발송해야 한다.
    현재는 서버 로그에 토큰을 출력한다 (개발/테스트용).
    """
    user = db.query(User).filter(User.email == body.email, User.deleted_at.is_(None)).first()
    if user and user.hashed_password:  # 구글 전용 계정은 비밀번호 재설정 불필요
        token = secrets.token_urlsafe(32)
        user.password_reset_token = token
        user.password_reset_expires = datetime.now(timezone.utc) + timedelta(hours=1)
        db.commit()
        # TODO: 실제 운영 시 이메일 발송으로 교체
        # send_reset_email(user.email, token)
        logger.warning(
            "PASSWORD RESET TOKEN (dev only - replace with email): "
            "email=%s token=%s", user.email, token
        )
    return {"message": "입력한 이메일로 재설정 링크를 발송했습니다"}


@router.post("/reset-password", status_code=200)
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    """토큰으로 비밀번호 재설정."""
    if len(body.new_password) < 8:
        raise HTTPException(status_code=422, detail="비밀번호는 8자 이상이어야 합니다")

    user = db.query(User).filter(
        User.password_reset_token == body.token,
        User.deleted_at.is_(None),
    ).first()

    if not user or not user.password_reset_expires:
        raise HTTPException(status_code=400, detail="유효하지 않은 토큰입니다")

    if datetime.now(timezone.utc) > user.password_reset_expires:
        user.password_reset_token = None
        user.password_reset_expires = None
        db.commit()
        raise HTTPException(status_code=400, detail="만료된 토큰입니다. 다시 요청해주세요")

    user.hashed_password = get_password_hash(body.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None
    db.commit()
    return {"message": "비밀번호가 변경되었습니다"}
