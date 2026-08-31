from typing import List
from fastapi import APIRouter, Depends, status
from supabase import Client
from app.api.deps import get_current_business_id, get_db
from app.schemas.common import ApiResponse
from app.schemas.masters import (
    AccountGroupResponse,
    LedgerCreate,
    LedgerResponse,
    StockItemResponse,
)
from app.services.masters_service import MastersService

router = APIRouter()


@router.get("/chart-of-accounts", response_model=ApiResponse[List[AccountGroupResponse]])
async def get_chart_of_accounts(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns the complete 28 Tally primary group hierarchy with nested sub-groups.
    """
    service = MastersService(db)
    result = await service.get_chart_of_accounts(business_id)
    return ApiResponse(success=True, data=result)


@router.get("/ledgers", response_model=ApiResponse[List[LedgerResponse]])
async def list_ledgers(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves all active ledgers with current balances and GSTIN metadata.
    """
    service = MastersService(db)
    result = await service.fetch_ledgers(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/ledgers", response_model=ApiResponse[LedgerResponse], status_code=status.HTTP_201_CREATED)
async def create_ledger(
    payload: LedgerCreate,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Creates a new ledger master linked to a parent account group.
    """
    service = MastersService(db)
    result = await service.create_ledger(business_id, payload)
    return ApiResponse(success=True, data=result)


@router.get("/stock-items", response_model=ApiResponse[List[StockItemResponse]])
async def list_stock_items(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves inventory stock items with current valuation and HSN codes.
    """
    service = MastersService(db)
    result = await service.fetch_stock_items(business_id)
    return ApiResponse(success=True, data=result)
