import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.v1.deps import get_current_user
from app.core.database import get_db
from app.models.relationship import Relationship
from app.models.user import User
from app.schemas.relationship import RelationshipCreate, RelationshipResponse, RelationshipUpdate

router = APIRouter()


@router.get("/", response_model=list[RelationshipResponse])
def list_relationships(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(Relationship)
        .filter(Relationship.user_id == current_user.id)
        .order_by(Relationship.last_transaction_date.desc().nullslast())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/", response_model=RelationshipResponse, status_code=201)
def create_relationship(
    rel_in: RelationshipCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing = db.query(Relationship).filter(
        Relationship.user_id == current_user.id,
        Relationship.counterparty_name == rel_in.counterparty_name,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 등록된 상대방입니다")

    rel = Relationship(**rel_in.model_dump(), user_id=current_user.id)
    db.add(rel)
    db.commit()
    db.refresh(rel)
    return rel


@router.get("/{rel_id}", response_model=RelationshipResponse)
def get_relationship(
    rel_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rel = db.query(Relationship).filter(
        Relationship.id == rel_id,
        Relationship.user_id == current_user.id,
    ).first()
    if not rel:
        raise HTTPException(status_code=404, detail="관계를 찾을 수 없습니다")
    return rel


@router.patch("/{rel_id}", response_model=RelationshipResponse)
def update_relationship(
    rel_id: uuid.UUID,
    rel_in: RelationshipUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rel = db.query(Relationship).filter(
        Relationship.id == rel_id,
        Relationship.user_id == current_user.id,
    ).first()
    if not rel:
        raise HTTPException(status_code=404, detail="관계를 찾을 수 없습니다")

    for field, value in rel_in.model_dump(exclude_unset=True).items():
        setattr(rel, field, value)
    db.commit()
    db.refresh(rel)
    return rel


@router.delete("/{rel_id}", status_code=204)
def delete_relationship(
    rel_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rel = db.query(Relationship).filter(
        Relationship.id == rel_id,
        Relationship.user_id == current_user.id,
    ).first()
    if not rel:
        raise HTTPException(status_code=404, detail="관계를 찾을 수 없습니다")
    db.delete(rel)
    db.commit()
