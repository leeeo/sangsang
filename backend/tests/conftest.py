"""테스트 공통 픽스처"""
import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.database import get_db
from app.core.limiter import limiter
from app.db.seed import seed_categories
from app.models.base import Base

# 테스트 전용 인메모리 SQLite - StaticPool로 모든 연결이 동일한 메모리 DB 공유
from sqlalchemy.pool import StaticPool

TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

@event.listens_for(engine, "connect")
def enable_fk(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def make_test_app():
    """lifespan 없는 테스트 전용 앱 (rate limit 비활성화)"""
    test_app = FastAPI(title="Test App")
    test_app.add_middleware(
        CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
    )
    # 테스트 환경에서 rate limit 비활성화
    limiter.enabled = False
    test_app.state.limiter = limiter
    test_app.include_router(api_router, prefix=settings.API_V1_STR)
    return test_app


@pytest.fixture(scope="function")
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    seed_categories(session)
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db):
    test_app = make_test_app()

    def override_get_db():
        yield db

    test_app.dependency_overrides[get_db] = override_get_db
    with TestClient(test_app) as c:
        yield c


@pytest.fixture
def registered_user(client):
    resp = client.post("/api/v1/auth/register", json={
        "email": "user@test.com",
        "username": "testuser",
        "password": "password123",
        "full_name": "Test User",
    })
    assert resp.status_code == 201
    return resp.json()


@pytest.fixture
def auth_headers(client, registered_user):
    resp = client.post("/api/v1/auth/login", data={
        "username": "user@test.com",
        "password": "password123",
    })
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def superuser(client, db):
    from app.models.user import User
    from app.core.security import get_password_hash
    user = User(
        email="admin@test.com",
        username="adminuser",
        hashed_password=get_password_hash("admin1234"),
        full_name="Admin",
        is_active=True,
        is_superuser=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def admin_headers(client, superuser):
    resp = client.post("/api/v1/auth/login", data={
        "username": "admin@test.com",
        "password": "admin1234",
    })
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
