def test_register_success(client):
    resp = client.post("/api/v1/auth/register", json={
        "email": "new@test.com",
        "username": "newuser",
        "password": "password123",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["email"] == "new@test.com"
    assert "id" in data
    assert "hashed_password" not in data


def test_register_duplicate_email(client, registered_user):
    resp = client.post("/api/v1/auth/register", json={
        "email": "user@test.com",
        "username": "other",
        "password": "password123",
    })
    assert resp.status_code == 400
    assert "이메일" in resp.json()["detail"]


def test_login_success(client, registered_user):
    resp = client.post("/api/v1/auth/login", data={
        "username": "user@test.com",
        "password": "password123",
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()
    assert resp.json()["token_type"] == "bearer"


def test_login_wrong_password(client, registered_user):
    resp = client.post("/api/v1/auth/login", data={
        "username": "user@test.com",
        "password": "wrongpassword",
    })
    assert resp.status_code == 401


def test_get_me(client, auth_headers):
    resp = client.get("/api/v1/users/me", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "user@test.com"


def test_get_me_unauthorized(client):
    resp = client.get("/api/v1/users/me")
    assert resp.status_code == 401
