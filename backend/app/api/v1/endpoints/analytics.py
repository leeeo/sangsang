from datetime import date, timedelta
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user
from app.core.database import get_db
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User

router = APIRouter()


@router.get("/summary")
def get_summary(
    year: int = Query(default=None),
    month: int = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """이번 달 혹은 특정 월 수입/지출 요약"""
    today = date.today()
    year = year or today.year
    month = month or today.month

    q = db.query(
        Transaction.type,
        func.sum(Transaction.amount).label("total"),
        func.count(Transaction.id).label("count"),
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
        extract("year", Transaction.transaction_date) == year,
        extract("month", Transaction.transaction_date) == month,
    ).group_by(Transaction.type)

    rows = {r.type: {"total": float(r.total), "count": r.count} for r in q.all()}

    income = rows.get("income", {"total": 0.0, "count": 0})
    expense = rows.get("expense", {"total": 0.0, "count": 0})

    return {
        "year": year,
        "month": month,
        "income": income["total"],
        "expense": expense["total"],
        "balance": income["total"] - expense["total"],
        "income_count": income["count"],
        "expense_count": expense["count"],
    }


@router.get("/trends")
def get_trends(
    months: int = Query(default=6, ge=1, le=24),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """최근 N개월 월별 수입/지출 트렌드"""
    today = date.today()
    start = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
    # months-1 개월 더 앞으로
    for _ in range(months - 1):
        start = (start - timedelta(days=1)).replace(day=1)

    rows = db.query(
        extract("year", Transaction.transaction_date).label("year"),
        extract("month", Transaction.transaction_date).label("month"),
        Transaction.type,
        func.sum(Transaction.amount).label("total"),
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
        Transaction.transaction_date >= start,
    ).group_by("year", "month", Transaction.type).order_by("year", "month").all()

    # {(year, month): {income: x, expense: y}} 로 변환
    buckets: dict = {}
    for r in rows:
        key = (int(r.year), int(r.month))
        if key not in buckets:
            buckets[key] = {"year": int(r.year), "month": int(r.month), "income": 0.0, "expense": 0.0}
        buckets[key][r.type] = float(r.total)

    return {"trends": sorted(buckets.values(), key=lambda x: (x["year"], x["month"]))}


@router.get("/by-category")
def get_by_category(
    year: int = Query(default=None),
    month: int = Query(default=None),
    tx_type: str = Query(default="expense", alias="type"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """카테고리별 지출/수입 분석"""
    today = date.today()
    year = year or today.year
    month = month or today.month

    rows = db.query(
        Category.id,
        Category.name,
        Category.color,
        func.sum(Transaction.amount).label("total"),
        func.count(Transaction.id).label("count"),
    ).join(Transaction, Transaction.category_id == Category.id).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
        Transaction.type == tx_type,
        extract("year", Transaction.transaction_date) == year,
        extract("month", Transaction.transaction_date) == month,
    ).group_by(Category.id, Category.name, Category.color).order_by(func.sum(Transaction.amount).desc()).all()

    total = sum(float(r.total) for r in rows)

    return {
        "year": year,
        "month": month,
        "type": tx_type,
        "total": total,
        "categories": [
            {
                "id": str(r.id),
                "name": r.name,
                "color": r.color,
                "total": float(r.total),
                "count": r.count,
                "ratio": round(float(r.total) / total * 100, 1) if total else 0,
            }
            for r in rows
        ],
    }


@router.get("/counterparty")
def get_counterparty_stats(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """상대방(counterparty)별 거래 통계 - 경조사 관계 파악용"""
    rows = db.query(
        Transaction.counterparty_name,
        Transaction.type,
        func.sum(Transaction.amount).label("total"),
        func.count(Transaction.id).label("count"),
        func.max(Transaction.transaction_date).label("last_date"),
    ).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
        Transaction.counterparty_name.isnot(None),
    ).group_by(Transaction.counterparty_name, Transaction.type).all()

    # 이름별로 집계
    people: dict = {}
    for r in rows:
        name = r.counterparty_name
        if name not in people:
            people[name] = {"name": name, "given": 0.0, "received": 0.0, "count": 0, "last_date": None}
        if r.type == "expense":
            people[name]["given"] += float(r.total)
        else:
            people[name]["received"] += float(r.total)
        people[name]["count"] += r.count
        r_date = str(r.last_date) if r.last_date else None
        if r_date and (people[name]["last_date"] is None or r_date > people[name]["last_date"]):
            people[name]["last_date"] = r_date

    result = sorted(people.values(), key=lambda x: x["given"] + x["received"], reverse=True)[:limit]
    for p in result:
        p["balance"] = p["given"] - p["received"]

    return {"counterparties": result}
