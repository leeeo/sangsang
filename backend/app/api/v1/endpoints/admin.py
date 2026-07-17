"""관리자 전용 API - is_superuser=True 인 사용자만 접근 가능"""
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import extract, func, Integer
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_superuser, get_db
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.category import CategoryCreate, CategoryResponse, CategoryUpdate
from app.schemas.user import UserResponse

router = APIRouter()


# ─────────────────────────────────────────────
# 서비스 전체 통계
# ─────────────────────────────────────────────

@router.get("/stats")
def get_stats(
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """서비스 전체 현황 통계"""
    total_users = db.query(func.count(User.id)).filter(User.deleted_at.is_(None)).scalar()
    active_users = db.query(func.count(User.id)).filter(
        User.is_active == True, User.deleted_at.is_(None)
    ).scalar()

    tx_stats = db.query(
        Transaction.type,
        func.count(Transaction.id).label("count"),
        func.sum(Transaction.amount).label("total"),
    ).filter(Transaction.deleted_at.is_(None)).group_by(Transaction.type).all()

    income = next((r for r in tx_stats if r.type == "income"), None)
    expense = next((r for r in tx_stats if r.type == "expense"), None)

    # 월별 신규 가입 (최근 6개월)
    today = date.today()
    six_months_ago = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
    for _ in range(5):
        six_months_ago = (six_months_ago - timedelta(days=1)).replace(day=1)

    monthly_signups = db.query(
        extract("year", User.created_at).label("year"),
        extract("month", User.created_at).label("month"),
        func.count(User.id).label("count"),
    ).filter(User.created_at >= six_months_ago).group_by("year", "month").order_by("year", "month").all()

    return {
        "users": {
            "total": total_users,
            "active": active_users,
            "inactive": total_users - active_users,
        },
        "transactions": {
            "income_count": income.count if income else 0,
            "income_total": float(income.total) if income and income.total else 0.0,
            "expense_count": expense.count if expense else 0,
            "expense_total": float(expense.total) if expense and expense.total else 0.0,
        },
        "monthly_signups": [
            {"year": int(r.year), "month": int(r.month), "count": r.count}
            for r in monthly_signups
        ],
    }


# ─────────────────────────────────────────────
# 사용자 관리
# ─────────────────────────────────────────────

@router.get("/users", response_model=dict)
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    is_active: Optional[bool] = None,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """전체 사용자 목록"""
    q = db.query(User).filter(User.deleted_at.is_(None))
    if search:
        q = q.filter(
            (User.email.ilike(f"%{search}%")) | (User.username.ilike(f"%{search}%")) | (User.full_name.ilike(f"%{search}%"))
        )
    if is_active is not None:
        q = q.filter(User.is_active == is_active)

    total = q.count()
    users = q.order_by(User.created_at.desc()).offset(skip).limit(limit).all()

    return {
        "items": [
            {
                "id": str(u.id),
                "email": u.email,
                "username": u.username,
                "full_name": u.full_name,
                "is_active": u.is_active,
                "is_superuser": u.is_superuser,
                "created_at": u.created_at.isoformat(),
                "tx_count": db.query(func.count(Transaction.id)).filter(
                    Transaction.user_id == u.id, Transaction.deleted_at.is_(None)
                ).scalar(),
            }
            for u in users
        ],
        "total": total,
        "skip": skip,
        "limit": limit,
    }


@router.get("/users/{user_id}")
def get_user(
    user_id: uuid.UUID,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """사용자 상세 + 최근 거래"""
    user = db.query(User).filter(User.id == user_id, User.deleted_at.is_(None)).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")

    recent_tx = db.query(Transaction).filter(
        Transaction.user_id == user_id, Transaction.deleted_at.is_(None)
    ).order_by(Transaction.transaction_date.desc()).limit(10).all()

    return {
        "id": str(user.id),
        "email": user.email,
        "username": user.username,
        "full_name": user.full_name,
        "phone": user.phone,
        "is_active": user.is_active,
        "is_superuser": user.is_superuser,
        "created_at": user.created_at.isoformat(),
        "recent_transactions": [
            {
                "id": str(t.id),
                "amount": str(t.amount),
                "type": t.type,
                "transaction_date": str(t.transaction_date),
                "counterparty_name": t.counterparty_name,
                "memo": t.memo,
            }
            for t in recent_tx
        ],
    }


@router.patch("/users/{user_id}")
def update_user(
    user_id: uuid.UUID,
    body: dict,
    current_admin: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """사용자 활성/비활성, superuser 권한 변경"""
    user = db.query(User).filter(User.id == user_id, User.deleted_at.is_(None)).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    if user.id == current_admin.id:
        raise HTTPException(status_code=400, detail="자기 자신은 수정할 수 없습니다")

    allowed = {"is_active", "is_superuser"}
    for key, value in body.items():
        if key in allowed:
            setattr(user, key, value)

    db.commit()
    db.refresh(user)
    return {"id": str(user.id), "is_active": user.is_active, "is_superuser": user.is_superuser}


@router.delete("/users/{user_id}", status_code=204)
def delete_user(
    user_id: uuid.UUID,
    current_admin: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """사용자 소프트 삭제"""
    user = db.query(User).filter(User.id == user_id, User.deleted_at.is_(None)).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    if user.id == current_admin.id:
        raise HTTPException(status_code=400, detail="자기 자신은 삭제할 수 없습니다")

    user.deleted_at = datetime.now(timezone.utc)
    user.is_active = False
    db.commit()


# ─────────────────────────────────────────────
# 전체 거래 조회
# ─────────────────────────────────────────────

@router.get("/transactions")
def list_all_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user_id: Optional[uuid.UUID] = None,
    type: Optional[str] = None,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """전체 사용자 거래 조회"""
    q = db.query(Transaction).filter(Transaction.deleted_at.is_(None))
    if user_id:
        q = q.filter(Transaction.user_id == user_id)
    if type:
        q = q.filter(Transaction.type == type)

    total = q.count()
    items = q.order_by(Transaction.transaction_date.desc()).offset(skip).limit(limit).all()

    return {
        "items": [
            {
                "id": str(t.id),
                "user_id": str(t.user_id),
                "amount": str(t.amount),
                "type": t.type,
                "transaction_date": str(t.transaction_date),
                "counterparty_name": t.counterparty_name,
                "memo": t.memo,
                "event_type": t.event_type,
            }
            for t in items
        ],
        "total": total,
    }


@router.delete("/transactions/{transaction_id}", status_code=204)
def delete_transaction_admin(
    transaction_id: uuid.UUID,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """관리자: 특정 거래 소프트 삭제"""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.deleted_at.is_(None),
    ).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="거래를 찾을 수 없습니다")
    transaction.deleted_at = datetime.now(timezone.utc)
    db.commit()


# ─────────────────────────────────────────────
# 시스템 카테고리 관리
# ─────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryResponse])
def list_system_categories(
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    return db.query(Category).filter(Category.is_system == True).all()


@router.post("/categories", response_model=CategoryResponse, status_code=201)
def create_system_category(
    category_in: CategoryCreate,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    category = Category(**category_in.model_dump(), is_system=True, user_id=None)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.patch("/categories/{category_id}", response_model=CategoryResponse)
def update_system_category(
    category_id: uuid.UUID,
    category_in: CategoryUpdate,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    category = db.query(Category).filter(
        Category.id == category_id, Category.is_system == True
    ).first()
    if not category:
        raise HTTPException(status_code=404, detail="시스템 카테고리를 찾을 수 없습니다")
    for field, value in category_in.model_dump(exclude_unset=True).items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category


@router.delete("/categories/{category_id}", status_code=204)
def delete_system_category(
    category_id: uuid.UUID,
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    category = db.query(Category).filter(
        Category.id == category_id, Category.is_system == True
    ).first()
    if not category:
        raise HTTPException(status_code=404, detail="시스템 카테고리를 찾을 수 없습니다")

    from sqlalchemy import func as sa_func
    tx_count = db.query(sa_func.count(Transaction.id)).filter(
        Transaction.category_id == category_id,
        Transaction.deleted_at.is_(None),
    ).scalar()
    if tx_count > 0:
        raise HTTPException(
            status_code=409,
            detail=f"거래 {tx_count}건이 이 카테고리를 사용 중입니다.",
        )

    db.delete(category)
    db.commit()


# ─────────────────────────────────────────────
# 서비스 전체 분석 (관리자용)
# ─────────────────────────────────────────────

@router.get("/analytics/trends")
def get_admin_trends(
    months: int = Query(default=6, ge=1, le=24),
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """서비스 전체 월별 수입/지출 트렌드"""
    today = date.today()
    start = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
    for _ in range(months - 1):
        start = (start - timedelta(days=1)).replace(day=1)

    rows = db.query(
        extract("year", Transaction.transaction_date).label("year"),
        extract("month", Transaction.transaction_date).label("month"),
        Transaction.type,
        func.sum(Transaction.amount).label("total"),
        func.count(Transaction.id).label("count"),
    ).filter(
        Transaction.deleted_at.is_(None),
        Transaction.transaction_date >= start,
    ).group_by("year", "month", Transaction.type).order_by("year", "month").all()

    buckets: dict = {}
    for r in rows:
        key = (int(r.year), int(r.month))
        if key not in buckets:
            buckets[key] = {"year": int(r.year), "month": int(r.month), "income": 0.0, "expense": 0.0, "income_count": 0, "expense_count": 0}
        buckets[key][r.type] = float(r.total)
        buckets[key][f"{r.type}_count"] = r.count

    return {"trends": sorted(buckets.values(), key=lambda x: (x["year"], x["month"]))}


@router.get("/analytics/by-category")
def get_admin_by_category(
    year: Optional[int] = None,
    month: Optional[int] = None,
    tx_type: str = Query(default="expense", alias="type"),
    _: User = Depends(get_current_superuser),
    db: Session = Depends(get_db),
):
    """서비스 전체 카테고리별 지출/수입 분석"""
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
