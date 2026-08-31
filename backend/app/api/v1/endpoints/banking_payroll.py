from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel
from supabase import Client
from app.api.deps import get_current_business_id, get_db
from app.schemas.banking_payroll import (
    BankAccountResponse,
    BankTransactionResponse,
    EmployeeResponse,
    Form26QSummaryResponse,
    MonthlyPayrollSummaryResponse,
    ReconciliationMatchRequest,
    TdsTcsRegisterItem,
)
from app.schemas.common import ApiResponse
from app.services.banking_payroll_service import BankingService, DirectTaxService, PayrollService

router = APIRouter()


class PayrollRunMonthRequest(BaseModel):
    month: str = "2026-08"


# --- Banking & BRS Endpoints ---

@router.get("/banking/accounts", response_model=ApiResponse[List[BankAccountResponse]], tags=["Banking & BRS"])
async def list_bank_accounts(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Lists bank accounts with book balance vs statement balance and unreconciled difference.
    """
    service = BankingService(db)
    result = await service.get_accounts(business_id)
    return ApiResponse(success=True, data=result)


@router.get("/banking/accounts/{account_id}/transactions", response_model=ApiResponse[List[BankTransactionResponse]], tags=["Banking & BRS"])
async def list_bank_transactions(
    account_id: str,
    db: Client = Depends(get_db),
):
    """
    Retrieves bank statement transactions with auto-match / unmatched status.
    """
    service = BankingService(db)
    result = await service.get_transactions(account_id)
    return ApiResponse(success=True, data=result)


@router.post("/banking/reconcile-match", response_model=ApiResponse[dict], tags=["Banking & BRS"])
async def match_reconciliation_item(
    payload: ReconciliationMatchRequest,
    db: Client = Depends(get_db),
):
    """
    Reconciles a bank statement entry by matching it with a voucher.
    """
    service = BankingService(db)
    await service.match_transaction(payload)
    return ApiResponse(success=True, data={"message": f"Transaction {payload.transaction_id} reconciled successfully."})


# --- Payroll Engine Endpoints ---

@router.get("/payroll/employees", response_model=ApiResponse[List[EmployeeResponse]], tags=["Payroll & Human Resources"])
async def list_employee_directory(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves the staff employee directory with wage breakdowns and statutory IDs (UAN/ESIC).
    """
    service = PayrollService(db)
    result = await service.get_employee_directory(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/payroll/calculate-run", response_model=ApiResponse[MonthlyPayrollSummaryResponse], tags=["Payroll & Human Resources"])
async def calculate_monthly_payroll(
    payload: PayrollRunMonthRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Dry-run computes monthly payroll: EPF (12%), ESI (0.75%), Professional Tax, TDS, and Net Pay.
    """
    service = PayrollService(db)
    result = await service.calculate_monthly_payroll(business_id, payload.month)
    return ApiResponse(success=True, data=result)


@router.post("/payroll/execute-run", response_model=ApiResponse[MonthlyPayrollSummaryResponse], status_code=status.HTTP_201_CREATED, tags=["Payroll & Human Resources"])
async def execute_monthly_payroll(
    payload: PayrollRunMonthRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Executes payroll run and atomically posts the balanced Salary Journal Voucher into accounting books.
    """
    service = PayrollService(db)
    result = await service.execute_and_post_payroll_journal(business_id, payload.month)
    return ApiResponse(success=True, data=result)


# --- Direct Tax (TDS/TCS) Endpoints ---

@router.get("/direct-tax/tds-register", response_model=ApiResponse[List[TdsTcsRegisterItem]], tags=["Direct Tax (TDS/TCS)"])
async def get_tds_register(
    section: Optional[str] = Query(None, description="e.g. 194Q, 194C, 194J, 206C"),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves statutory TDS & TCS deduction register with challan BSR/CIN details.
    """
    service = DirectTaxService(db)
    result = await service.get_tds_register(business_id, section)
    return ApiResponse(success=True, data=result)


@router.get("/direct-tax/form-26q-summary", response_model=ApiResponse[Form26QSummaryResponse], tags=["Direct Tax (TDS/TCS)"])
async def get_form_26q_summary(
    quarter: str = Query("Q2_2026_27"),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Generates quarterly Form 26Q e-TDS summary with total deductions and pending challan payments.
    """
    service = DirectTaxService(db)
    result = await service.get_form_26q_summary(business_id, quarter)
    return ApiResponse(success=True, data=result)
