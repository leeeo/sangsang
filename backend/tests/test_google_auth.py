"""Google OAuth 엔드포인트 테스트 (google.oauth2 mock)"""
from unittest.mock import MagicMock, patch


def _mock_idinfo(sub="google-123", email="google@test.com", name="Google User"):
    return {"sub": sub, "email": email, "name": name}


def test_google_login_no_client_id(client):
    """GOOGLE_CLIENT_ID 미설정 시 503 반환"""
    resp = client.post("/api/v1/auth/google", json={"id_token": "fake-token"})
    assert resp.status_code == 503


_PATCH_VERIFY = "app.api.v1.endpoints.auth.google_id_token.verify_oauth2_token"
_PATCH_CLIENT_ID = "app.core.config.settings.GOOGLE_CLIENT_ID"


def test_google_login_new_user(client):
    """신규 구글 사용자 → 자동 가입 후 JWT 발급"""
    with patch(_PATCH_CLIENT_ID, "test-client-id"), \
         patch(_PATCH_VERIFY, return_value=_mock_idinfo()):
        resp = client.post("/api/v1/auth/google", json={"id_token": "valid-token"})

    assert resp.status_code == 200
    assert "access_token" in resp.json()


def test_google_login_existing_email_user(client, registered_user):
    """같은 이메일의 기존 이메일/비밀번호 계정 → google_id 연동"""
    with patch(_PATCH_CLIENT_ID, "test-client-id"), \
         patch(_PATCH_VERIFY, return_value=_mock_idinfo(email="user@test.com")):
        resp = client.post("/api/v1/auth/google", json={"id_token": "valid-token"})

    assert resp.status_code == 200
    token = resp.json()["access_token"]
    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["email"] == "user@test.com"


def test_google_login_repeat(client):
    """같은 구글 계정 재로그인 → 항상 성공"""
    idinfo = _mock_idinfo()
    with patch(_PATCH_CLIENT_ID, "test-client-id"), \
         patch(_PATCH_VERIFY, return_value=idinfo):
        r1 = client.post("/api/v1/auth/google", json={"id_token": "t"})
        r2 = client.post("/api/v1/auth/google", json={"id_token": "t"})

    assert r1.status_code == 200
    assert r2.status_code == 200


def test_google_login_invalid_token(client):
    """잘못된 토큰 → 401"""
    with patch(_PATCH_CLIENT_ID, "test-client-id"), \
         patch(_PATCH_VERIFY, side_effect=ValueError("bad token")):
        resp = client.post("/api/v1/auth/google", json={"id_token": "bad"})

    assert resp.status_code == 401
