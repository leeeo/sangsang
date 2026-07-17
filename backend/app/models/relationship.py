"""
Relationship: 사용자 간 경조사/금전 관계 요약 테이블
거래가 생성/수정될 때마다 집계값을 업데이트해서 빠른 조회 지원
"""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDMixin


class Relationship(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "relationships"

    # 기록하는 사용자
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # 상대방 이름 (앱 사용자가 아닐 수 있으므로 이름으로 저장)
    counterparty_name: Mapped[str] = mapped_column(String(100), nullable=False)
    # 상대방이 앱 사용자인 경우 연결
    counterparty_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # 관계 유형 (가족, 친구, 직장동료 등)
    relationship_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    # 메모
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 집계 필드 (거래 생성/수정 시 업데이트)
    total_given: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    total_received: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    last_transaction_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped["User"] = relationship("User", foreign_keys=[user_id])
    counterparty: Mapped[Optional["User"]] = relationship("User", foreign_keys=[counterparty_id])

    __table_args__ = (
        UniqueConstraint("user_id", "counterparty_name", name="uq_user_counterparty_name"),
        Index("ix_relationships_user_id", "user_id"),
    )
