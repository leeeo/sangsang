"""관리자(superuser) 계정 생성 스크립트

사용법:
  대화형:  poetry run python scripts/create_superuser.py
  비대화형: poetry run python scripts/create_superuser.py \
              --email admin@example.com \
              --username admin \
              --password "SecurePass1!" \
              --full-name 관리자
"""
import argparse
import getpass
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.core.security import get_password_hash
from app.models.user import User


def _validate_password(password: str) -> None:
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")


def create_superuser(email: str, username: str, password: str, full_name: str = "관리자") -> None:
    _validate_password(password)
    db = SessionLocal()
    try:
        existing = db.query(User).filter(User.email == email).first()
        if existing:
            if not existing.is_superuser:
                existing.is_superuser = True
                db.commit()
                print(f"[OK] Granted superuser to existing user '{email}'")
            else:
                print(f"[!!] '{email}' is already a superuser")
            return

        if db.query(User).filter(User.username == username).first():
            print(f"[NG] Username '{username}' is already taken")
            sys.exit(1)

        user = User(
            email=email,
            username=username,
            full_name=full_name,
            hashed_password=get_password_hash(password),
            is_active=True,
            is_superuser=True,
        )
        db.add(user)
        db.commit()
        print(f"[OK] Superuser created: {email}")
    finally:
        db.close()


def _interactive() -> None:
    print("=== Create Sangbu-Sangjo Superuser ===")
    email = input("Email: ").strip()
    username = input("Username: ").strip()
    full_name = input("Full name (Enter for 'Admin'): ").strip() or "Admin"
    password = getpass.getpass("Password (min 8 chars): ")
    confirm = getpass.getpass("Confirm password: ")

    if password != confirm:
        print("[NG] Passwords do not match")
        sys.exit(1)

    create_superuser(email, username, password, full_name)


def _cli() -> None:
    parser = argparse.ArgumentParser(description="상부상조 superuser 생성")
    parser.add_argument("--email", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--full-name", default="관리자")
    args = parser.parse_args()
    create_superuser(args.email, args.username, args.password, args.full_name)


if __name__ == "__main__":
    # --email 인자가 있으면 비대화형 모드
    if "--email" in sys.argv:
        _cli()
    else:
        _interactive()
