import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user
from app.core.database import get_db
from app.models.relationship import Relationship
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.transaction import (
    TransactionCreate,
    TransactionListResponse,
    TransactionResponse,
    TransactionUpdate,
)

router = APIRouter()


def _update_relationship(
    db: Session,
    user_id: uuid.UUID,
    counterparty_name: Optional[str],
    amount: Decimal,
    tx_type: str,
    tx_date: date,
    delta: int = 1,  # +1 추가, -1 취소
) -> None:
    """counterparty_name이 있는 거래가 생성/삭제될 때 Relationship 집계를 갱신한다."""
    if not counterparty_name:
        return
    rel = db.query(Relationship).filter(
        Relationship.user_id == user_id,
        Relationship.counterparty_name == counterparty_name,
    ).first()
    if rel is None:
        if delta < 0:
            return  # 관계 없으면 취소 무시
        rel = Relationship(user_id=user_id, counterparty_name=counterparty_name)
        db.add(rel)

    change = amount * delta
    if tx_type == "expense":
        new_val = (rel.total_given or Decimal(0)) + change
        rel.total_given = max(Decimal(0), new_val)
    else:
        new_val = (rel.total_received or Decimal(0)) + change
        rel.total_received = max(Decimal(0), new_val)

    if delta > 0:
        tx_dt = datetime.combine(tx_date, datetime.min.time())
        last = rel.last_transaction_date
        # DB가 offset-aware로 반환하는 경우를 대비해 naive로 정규화
        if last is not None and last.tzinfo is not None:
            last = last.replace(tzinfo=None)
        if last is None or tx_dt > last:
            rel.last_transaction_date = tx_dt


@router.get("/", response_model=TransactionListResponse)
def list_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    tx_type: Optional[str] = Query(None, alias="type"),
    category_id: Optional[uuid.UUID] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(Transaction).filter(
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
    )
    if tx_type:
        q = q.filter(Transaction.type == tx_type)
    if category_id:
        q = q.filter(Transaction.category_id == category_id)
    if start_date:
        q = q.filter(Transaction.transaction_date >= start_date)
    if end_date:
        q = q.filter(Transaction.transaction_date <= end_date)

    total = q.count()
    items = q.order_by(Transaction.transaction_date.desc()).offset(skip).limit(limit).all()
    return TransactionListResponse(items=items, total=total, skip=skip, limit=limit)


@router.post("/", response_model=TransactionResponse, status_code=201)
def create_transaction(
    transaction_in: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transaction = Transaction(**transaction_in.model_dump(), user_id=current_user.id)
    db.add(transaction)
    _update_relationship(
        db, current_user.id,
        transaction_in.counterparty_name,
        transaction_in.amount,
        transaction_in.type,
        transaction_in.transaction_date,
        delta=1,
    )
    db.commit()
    db.refresh(transaction)
    return transaction


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
    ).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="거래를 찾을 수 없습니다")
    return transaction


@router.patch("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(
    transaction_id: uuid.UUID,
    transaction_in: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
    ).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="거래를 찾을 수 없습니다")

    update_data = transaction_in.model_dump(exclude_unset=True)
    affects_relationship = any(
        k in update_data for k in ("amount", "type", "counterparty_name", "transaction_date")
    )

    if affects_relationship:
        # 수정 전 값으로 집계 차감
        _update_relationship(
            db, current_user.id,
            transaction.counterparty_name,
            transaction.amount,
            transaction.type,
            transaction.transaction_date,
            delta=-1,
        )

    for field, value in update_data.items():
        setattr(transaction, field, value)

    if affects_relationship:
        # 수정 후 값으로 집계 증가
        _update_relationship(
            db, current_user.id,
            transaction.counterparty_name,
            transaction.amount,
            transaction.type,
            transaction.transaction_date,
            delta=1,
        )

    db.commit()
    db.refresh(transaction)
    return transaction


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(
    transaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id,
        Transaction.deleted_at.is_(None),
    ).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="거래를 찾을 수 없습니다")
    _update_relationship(
        db, current_user.id,
        transaction.counterparty_name,
        transaction.amount,
        transaction.type,
        transaction.transaction_date,
        delta=-1,
    )
    transaction.deleted_at = datetime.now(timezone.utc)
    db.commit()
