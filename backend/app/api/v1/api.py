from fastapi import APIRouter
from app.api.v1.endpoints import auth, health, masters, reports, vouchers

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["System Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication & Multi-Tenant Context"])
api_router.include_router(vouchers.router, prefix="/vouchers", tags=["Double-Entry Vouchers Engine"])
api_router.include_router(masters.router, prefix="/masters", tags=["Chart of Accounts & Ledgers"])
api_router.include_router(reports.router, prefix="/reports", tags=["Financial & Statutory Reports"])
