"""Relationship API + 거래 연동 집계 테스트"""
from datetime import date


def _get_expense_category(client, auth_headers):
    resp = client.get("/api/v1/categories/", headers=auth_headers)
    cats = [c for c in resp.json() if c["type"] == "expense"]
    return cats[0]["id"]


def _create_tx(client, auth_headers, cat_id, amount, counterparty="홍길동", tx_type="expense"):
    resp = client.post("/api/v1/transactions/", headers=auth_headers, json={
        "category_id": cat_id,
        "amount": str(amount),
        "type": tx_type,
        "transaction_date": str(date.today()),
        "counterparty_name": counterparty,
    })
    assert resp.status_code == 201
    return resp.json()


# ── Relationship CRUD ──────────────────────────────────────────────────────────

def test_create_relationship(client, auth_headers):
    resp = client.post("/api/v1/relationships/", headers=auth_headers, json={
        "counterparty_name": "김철수",
        "relationship_type": "친구",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["counterparty_name"] == "김철수"
    assert data["relationship_type"] == "친구"


def test_create_duplicate_relationship(client, auth_headers):
    payload = {"counterparty_name": "중복테스트"}
    client.post("/api/v1/relationships/", headers=auth_headers, json=payload)
    resp = client.post("/api/v1/relationships/", headers=auth_headers, json=payload)
    assert resp.status_code == 400


def test_list_relationships(client, auth_headers):
    for name in ["A", "B", "C"]:
        client.post("/api/v1/relationships/", headers=auth_headers, json={"counterparty_name": name})
    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    assert resp.status_code == 200
    assert len(resp.json()) == 3


def test_update_relationship(client, auth_headers):
    create = client.post("/api/v1/relationships/", headers=auth_headers, json={"counterparty_name": "업데이트대상"})
    rel_id = create.json()["id"]
    resp = client.patch(f"/api/v1/relationships/{rel_id}", headers=auth_headers, json={"notes": "메모추가"})
    assert resp.status_code == 200
    assert resp.json()["notes"] == "메모추가"


def test_counterparty_name_max_length(client, auth_headers):
    resp = client.post("/api/v1/relationships/", headers=auth_headers, json={
        "counterparty_name": "x" * 101,
    })
    assert resp.status_code == 422


# ── 거래 생성 시 집계 자동 업데이트 ────────────────────────────────────────────

def test_relationship_aggregate_on_create(client, auth_headers):
    cat_id = _get_expense_category(client, auth_headers)
    _create_tx(client, auth_headers, cat_id, 50000, "홍길동", "expense")

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rels = resp.json()
    rel = next((r for r in rels if r["counterparty_name"] == "홍길동"), None)
    assert rel is not None
    assert float(rel["total_given"]) == 50000.0
    assert float(rel["total_received"]) == 0.0
    assert float(rel["balance"]) == 50000.0


def test_relationship_aggregate_income(client, auth_headers):
    cats = client.get("/api/v1/categories/", headers=auth_headers).json()
    cat_id = next(c["id"] for c in cats if c["type"] == "income")
    _create_tx(client, auth_headers, cat_id, 30000, "박영희", "income")

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rel = next(r for r in resp.json() if r["counterparty_name"] == "박영희")
    assert float(rel["total_received"]) == 30000.0
    assert float(rel["balance"]) == -30000.0


def test_relationship_aggregate_on_delete(client, auth_headers):
    cat_id = _get_expense_category(client, auth_headers)
    tx = _create_tx(client, auth_headers, cat_id, 100000, "삭제테스트")

    # 삭제
    client.delete(f"/api/v1/transactions/{tx['id']}", headers=auth_headers)

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rel = next((r for r in resp.json() if r["counterparty_name"] == "삭제테스트"), None)
    # 관계 레코드는 남지만 집계가 0으로 복구됨
    if rel:
        assert float(rel["total_given"]) == 0.0


def test_relationship_aggregate_on_update_amount(client, auth_headers):
    """거래 금액 수정 시 집계 재조정 확인"""
    cat_id = _get_expense_category(client, auth_headers)
    tx = _create_tx(client, auth_headers, cat_id, 50000, "수정테스트금액")

    # 금액 수정: 50000 → 80000
    client.patch(f"/api/v1/transactions/{tx['id']}", headers=auth_headers,
                 json={"amount": "80000"})

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rel = next(r for r in resp.json() if r["counterparty_name"] == "수정테스트금액")
    assert float(rel["total_given"]) == 80000.0


def test_relationship_aggregate_on_update_type(client, auth_headers):
    """거래 유형 수정 시 집계 재조정 확인 (expense → income)"""
    cats = client.get("/api/v1/categories/", headers=auth_headers).json()
    exp_cat = next(c["id"] for c in cats if c["type"] == "expense")
    inc_cat = next(c["id"] for c in cats if c["type"] == "income")

    tx = _create_tx(client, auth_headers, exp_cat, 30000, "수정테스트유형", "expense")

    # expense → income 으로 변경
    client.patch(f"/api/v1/transactions/{tx['id']}", headers=auth_headers,
                 json={"type": "income", "category_id": inc_cat})

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rel = next(r for r in resp.json() if r["counterparty_name"] == "수정테스트유형")
    # total_given은 0으로 돌아오고, total_received가 증가해야 함
    assert float(rel["total_given"]) == 0.0
    assert float(rel["total_received"]) == 30000.0


def test_relationship_aggregate_on_update_counterparty(client, auth_headers):
    """상대방 이름 수정 시 기존 관계 집계 차감, 새 관계 집계 증가"""
    cat_id = _get_expense_category(client, auth_headers)
    tx = _create_tx(client, auth_headers, cat_id, 40000, "변경전이름")

    client.patch(f"/api/v1/transactions/{tx['id']}", headers=auth_headers,
                 json={"counterparty_name": "변경후이름"})

    resp = client.get("/api/v1/relationships/", headers=auth_headers)
    rels = {r["counterparty_name"]: r for r in resp.json()}

    # 기존 이름 집계 0으로 복구
    if "변경전이름" in rels:
        assert float(rels["변경전이름"]["total_given"]) == 0.0
    # 새 이름에 집계 증가
    assert float(rels["변경후이름"]["total_given"]) == 40000.0
