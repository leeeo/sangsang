from datetime import date


def _get_category_id(client, auth_headers, type="expense"):
    resp = client.get("/api/v1/categories/", headers=auth_headers)
    categories = [c for c in resp.json() if c["type"] == type]
    return categories[0]["id"]


def test_create_transaction(client, auth_headers):
    category_id = _get_category_id(client, auth_headers)
    resp = client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": category_id,
        "amount": "50000",
        "type": "expense",
        "transaction_date": str(date.today()),
        "counterparty_name": "홍길동",
        "event_type": "wedding",
        "memo": "결혼 축의금",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["amount"] == "50000.00"
    assert data["counterparty_name"] == "홍길동"


def test_create_transaction_invalid_amount(client, auth_headers):
    category_id = _get_category_id(client, auth_headers)
    resp = client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": category_id,
        "amount": "-1000",
        "type": "expense",
        "transaction_date": str(date.today()),
    })
    assert resp.status_code == 422


def test_list_transactions(client, auth_headers):
    category_id = _get_category_id(client, auth_headers)
    # 거래 2개 생성
    for i in range(2):
        client.post("/api/v1/transactions/", headers=auth_headers, json={
            "category_id": category_id,
            "amount": str(10000 * (i + 1)),
            "type": "expense",
            "transaction_date": str(date.today()),
        })

    resp = client.get("/api/v1/transactions/", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2


def test_list_transactions_filter_by_type(client, auth_headers):
    cat_expense = _get_category_id(client, auth_headers, "expense")
    cat_income = _get_category_id(client, auth_headers, "income")

    client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": cat_expense, "amount": "10000",
        "type": "expense", "transaction_date": str(date.today()),
    })
    client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": cat_income, "amount": "20000",
        "type": "income", "transaction_date": str(date.today()),
    })

    resp = client.get("/api/v1/transactions/?type=expense", headers=auth_headers)
    assert resp.json()["total"] == 1


def test_delete_transaction(client, auth_headers):
    category_id = _get_category_id(client, auth_headers)
    create_resp = client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": category_id,
        "amount": "30000",
        "type": "expense",
        "transaction_date": str(date.today()),
    })
    tx_id = create_resp.json()["id"]

    del_resp = client.delete(f"/api/v1/transactions/{tx_id}", headers=auth_headers)
    assert del_resp.status_code == 204

    # soft delete 확인 - 목록에서 안 보여야 함
    list_resp = client.get("/api/v1/transactions/", headers=auth_headers)
    assert list_resp.json()["total"] == 0
