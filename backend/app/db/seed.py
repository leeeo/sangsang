"""시스템 카테고리 초기 데이터"""
from sqlalchemy.orm import Session

from app.models.category import Category

SYSTEM_CATEGORIES = [
    # 경조사 (expense)
    {"name": "결혼 축의금", "type": "expense", "icon": "💍", "color": "#FF6B9D"},
    {"name": "장례 조의금", "type": "expense", "icon": "🕯️", "color": "#6B7280"},
    {"name": "돌잔치", "type": "expense", "icon": "🎂", "color": "#F59E0B"},
    {"name": "생일 선물", "type": "expense", "icon": "🎁", "color": "#8B5CF6"},
    {"name": "집들이 선물", "type": "expense", "icon": "🏠", "color": "#10B981"},
    # 모임 (expense)
    {"name": "계모임", "type": "expense", "icon": "🤝", "color": "#3B82F6"},
    {"name": "동창회비", "type": "expense", "icon": "🎓", "color": "#6366F1"},
    {"name": "회식", "type": "expense", "icon": "🍽️", "color": "#EF4444"},
    # 대여/차용 (expense)
    {"name": "빌려준 돈", "type": "expense", "icon": "💸", "color": "#F97316"},
    # 경조사 (income)
    {"name": "결혼 축의금 수령", "type": "income", "icon": "💍", "color": "#FF6B9D"},
    {"name": "생일 용돈", "type": "income", "icon": "🎂", "color": "#F59E0B"},
    # 모임 (income)
    {"name": "계모임 수령", "type": "income", "icon": "🤝", "color": "#3B82F6"},
    # 대여 (income)
    {"name": "빌려준 돈 회수", "type": "income", "icon": "💰", "color": "#10B981"},
    # 기타
    {"name": "기타 지출", "type": "expense", "icon": "📦", "color": "#9CA3AF"},
    {"name": "기타 수입", "type": "income", "icon": "📦", "color": "#9CA3AF"},
]


def seed_categories(db: Session) -> None:
    existing = db.query(Category).filter(Category.is_system == True).count()
    if existing > 0:
        return

    for data in SYSTEM_CATEGORIES:
        category = Category(
            name=data["name"],
            type=data["type"],
            icon=data["icon"],
            color=data["color"],
            is_system=True,
            user_id=None,
        )
        db.add(category)

    db.commit()
    print(f"[seed] 시스템 카테고리 {len(SYSTEM_CATEGORIES)}개 생성 완료")
