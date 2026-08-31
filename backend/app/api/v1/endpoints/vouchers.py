from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from supabase import Client
from app.api.deps import get_current_business_id, get_current_user, get_db
from app.schemas.accounting import (
    VoucherCreate,
    VoucherFilterParams,
    VoucherResponse,
)
from app.schemas.auth import UserContext
from app.schemas.common import ApiResponse
from app.services.accounting_service import AccountingService

router = APIRouter()


@router.post("", response_model=ApiResponse[VoucherResponse], status_code=status.HTTP_201_CREATED)
async def create_voucher(
    payload: VoucherCreate,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Creates a new double-entry voucher entry.
    Validates strictly that sum of debits equals sum of credits.
    """
    service = AccountingService(db)
    result = await service.create_voucher(business_id, payload)
    return ApiResponse(success=True, data=result)


@router.get("", response_model=ApiResponse[List[VoucherResponse]])
async def list_vouchers(
    voucher_type: Optional[str] = Query(None, description="Filter by type: Sales, Purchase, Payment, etc."),
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves filtered vouchers for the active business context.
    """
    service = AccountingService(db)
    filters = VoucherFilterParams(
        voucher_type=voucher_type,
        from_date=from_date,
        to_date=to_date,
        search_query=search,
    )
    results = await service.fetch_vouchers(business_id, filters, page=page, page_size=page_size)
    return ApiResponse(success=True, data=results)


@router.get("/{voucher_id}", response_model=ApiResponse[VoucherResponse])
async def get_voucher(
    voucher_id: str,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves a single voucher with full line-item breakdowns.
    """
    service = AccountingService(db)
    result = await service.get_voucher_by_id(business_id, voucher_id)
    return ApiResponse(success=True, data=result)
