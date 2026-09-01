from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from supabase import Client
from app.api.deps import get_current_business_id, get_db
from app.schemas.common import ApiResponse
from app.schemas.reports import (
    BalanceSheetResponse,
    DashboardKpisResponse,
    DayBookEntryResponse,
    ProfitAndLossResponse,
    TrialBalanceResponse,
)
from app.services.reports_service import ReportsService

router = APIRouter()


@router.get("/dashboard-kpis", response_model=ApiResponse[DashboardKpisResponse])
async def get_dashboard_kpis(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns real-time executive dashboard KPIs, liquidity ratios, and 30-day forward cash flow runway.
    """
    service = ReportsService(db)
    result = await service.get_dashboard_kpis(business_id)
    return ApiResponse(success=True, data=result)


@router.get("/trial-balance", response_model=ApiResponse[TrialBalanceResponse])
async def get_trial_balance(
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns multi-column Trial Balance report with Opening, Transactions, and Closing Dr/Cr checksums.
    """
    service = ReportsService(db)
    f_date = from_date or date(date.today().year, 4, 1)
    t_date = to_date or date.today()
    result = await service.get_trial_balance(business_id, f_date, t_date)
    return ApiResponse(success=True, data=result)


@router.get("/profit-and-loss", response_model=ApiResponse[ProfitAndLossResponse])
async def get_profit_and_loss(
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns Schedule III Profit & Loss Account with Gross Profit, EBITDA, and Net Profit after Tax.
    """
    service = ReportsService(db)
    f_date = from_date or date(date.today().year, 4, 1)
    t_date = to_date or date.today()
    result = await service.get_profit_and_loss(business_id, f_date, t_date)
    return ApiResponse(success=True, data=result)


@router.get("/balance-sheet", response_model=ApiResponse[BalanceSheetResponse])
async def get_balance_sheet(
    as_on_date: Optional[date] = Query(None),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns Schedule III Balance Sheet ensuring Equities & Liabilities match Assets.
    """
    service = ReportsService(db)
    target_date = as_on_date or date.today()
    result = await service.get_balance_sheet(business_id, target_date)
    return ApiResponse(success=True, data=result)


@router.get("/day-book", response_model=ApiResponse[List[DayBookEntryResponse]])
async def get_day_book(
    target_date: Optional[date] = Query(None),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns chronological Day Book stream of double-entry transactions.
    """
    service = ReportsService(db)
    t_date = target_date or date.today()
    result = await service.get_day_book(business_id, t_date)
    return ApiResponse(success=True, data=result)
