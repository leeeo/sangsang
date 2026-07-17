from fastapi import APIRouter

from app.api.v1.endpoints import admin, analytics, auth, categories, relationships, transactions, users

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["인증"])
api_router.include_router(users.router, prefix="/users", tags=["사용자"])
api_router.include_router(transactions.router, prefix="/transactions", tags=["거래"])
api_router.include_router(categories.router, prefix="/categories", tags=["카테고리"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["분석"])
api_router.include_router(relationships.router, prefix="/relationships", tags=["관계"])
api_router.include_router(admin.router, prefix="/admin", tags=["관리자"])
