import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field, computed_field


class RelationshipCreate(BaseModel):
    counterparty_name: str = Field(..., min_length=1, max_length=100)
    relationship_type: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None


class RelationshipUpdate(BaseModel):
    relationship_type: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None


class RelationshipResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: uuid.UUID
    user_id: uuid.UUID
    counterparty_name: str
    counterparty_id: Optional[uuid.UUID]
    relationship_type: Optional[str]
    notes: Optional[str]
    total_given: Decimal
    total_received: Decimal
    last_transaction_date: Optional[datetime]
    created_at: datetime

    @computed_field
    @property
    def balance(self) -> Decimal:
        """양수: 내가 더 줌 / 음수: 내가 더 받음"""
        return self.total_given - self.total_received
