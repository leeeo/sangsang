"""관리자 API 테스트"""


def test_stats_requires_superuser(client, auth_headers):
    resp = client.get("/api/v1/admin/stats", headers=auth_headers)
    assert resp.status_code == 403


def test_stats_ok(client, admin_headers):
    resp = client.get("/api/v1/admin/stats", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "users" in data
    assert "transactions" in data
    assert "monthly_signups" in data


def test_list_users(client, admin_headers, registered_user):
    resp = client.get("/api/v1/admin/users", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    assert any(u["email"] == "user@test.com" for u in data["items"])


def test_list_users_search(client, admin_headers, registered_user):
    resp = client.get("/api/v1/admin/users?search=testuser", headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json()["total"] == 1


def test_update_user_active(client, admin_headers, registered_user):
    user_id = registered_user["id"]
    resp = client.patch(f"/api/v1/admin/users/{user_id}", headers=admin_headers, json={"is_active": False})
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False


def test_delete_user(client, admin_headers, registered_user):
    user_id = registered_user["id"]
    resp = client.delete(f"/api/v1/admin/users/{user_id}", headers=admin_headers)
    assert resp.status_code == 204

    # 삭제 후 목록에서 사라짐
    resp = client.get("/api/v1/admin/users?search=user@test.com", headers=admin_headers)
    assert resp.json()["total"] == 0


def test_list_transactions_admin(client, admin_headers, auth_headers):
    resp = client.get("/api/v1/admin/transactions", headers=admin_headers)
    assert resp.status_code == 200
    assert "items" in resp.json()


def test_system_category_crud(client, admin_headers):
    # 생성
    resp = client.post("/api/v1/admin/categories", headers=admin_headers, json={
        "name": "테스트카테고리", "type": "expense", "icon": "🧪", "color": "#ff0000",
    })
    assert resp.status_code == 201
    cat_id = resp.json()["id"]

    # 수정
    resp = client.patch(f"/api/v1/admin/categories/{cat_id}", headers=admin_headers, json={"name": "수정됨"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "수정됨"

    # 삭제
    resp = client.delete(f"/api/v1/admin/categories/{cat_id}", headers=admin_headers)
    assert resp.status_code == 204
