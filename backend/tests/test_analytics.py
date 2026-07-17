from datetime import date


def _create_tx(client, auth_headers, amount, type, category_id, counterparty=None):
    body = {
        "category_id": category_id,
        "amount": str(amount),
        "type": type,
        "transaction_date": str(date.today()),
    }
    if counterparty:
        body["counterparty_name"] = counterparty
    client.post("/api/v1/transactions/", headers=auth_headers, json=body)


def _get_category_id(client, auth_headers, type="expense"):
    resp = client.get("/api/v1/categories/", headers=auth_headers)
    return next(c["id"] for c in resp.json() if c["type"] == type)


def test_summary_empty(client, auth_headers):
    resp = client.get("/api/v1/analytics/summary", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["income"] == 0.0
    assert data["expense"] == 0.0
    assert data["balance"] == 0.0


def test_summary_with_data(client, auth_headers):
    cat_e = _get_category_id(client, auth_headers, "expense")
    cat_i = _get_category_id(client, auth_headers, "income")
    _create_tx(client, auth_headers, 50000, "expense", cat_e)
    _create_tx(client, auth_headers, 100000, "income", cat_i)

    resp = client.get("/api/v1/analytics/summary", headers=auth_headers)
    data = resp.json()
    assert data["expense"] == 50000.0
    assert data["income"] == 100000.0
    assert data["balance"] == 50000.0


def test_trends(client, auth_headers):
    resp = client.get("/api/v1/analytics/trends?months=6", headers=auth_headers)
    assert resp.status_code == 200
    assert "trends" in resp.json()


def test_by_category(client, auth_headers):
    cat_e = _get_category_id(client, auth_headers, "expense")
    _create_tx(client, auth_headers, 30000, "expense", cat_e)
    _create_tx(client, auth_headers, 20000, "expense", cat_e)

    resp = client.get("/api/v1/analytics/by-category?type=expense", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 50000.0
    assert len(data["categories"]) >= 1
    assert data["categories"][0]["ratio"] == 100.0


def test_counterparty_stats(client, auth_headers):
    cat_e = _get_category_id(client, auth_headers, "expense")
    cat_i = _get_category_id(client, auth_headers, "income")
    _create_tx(client, auth_headers, 50000, "expense", cat_e, "홍길동")
    _create_tx(client, auth_headers, 30000, "income", cat_i, "홍길동")

    resp = client.get("/api/v1/analytics/counterparty", headers=auth_headers)
    assert resp.status_code == 200
    people = resp.json()["counterparties"]
    assert len(people) == 1
    assert people[0]["name"] == "홍길동"
    assert people[0]["given"] == 50000.0
    assert people[0]["received"] == 30000.0
    assert people[0]["balance"] == 20000.0
