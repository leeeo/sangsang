import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, field_validator


class TransactionCreate(BaseModel):
    category_id: uuid.UUID
    amount: Decimal
    type: Literal["income", "expense"]
    transaction_date: date
    counterparty_name: Optional[str] = None
    memo: Optional[str] = None
    event_type: Optional[str] = None

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("금액은 0보다 커야 합니다")
        return v


class TransactionUpdate(BaseModel):
    category_id: Optional[uuid.UUID] = None
    amount: Optional[Decimal] = None
    type: Optional[Literal["income", "expense"]] = None
    transaction_date: Optional[date] = None
    counterparty_name: Optional[str] = None
    memo: Optional[str] = None
    event_type: Optional[str] = None


class TransactionResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID
    category_id: uuid.UUID
    amount: Decimal
    type: str
    transaction_date: date
    counterparty_name: Optional[str]
    memo: Optional[str]
    event_type: Optional[str]
    created_at: datetime


class TransactionListResponse(BaseModel):
    items: list[TransactionResponse]
    total: int
    skip: int
    limit: int
