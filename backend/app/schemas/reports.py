from datetime import date
from typing import List, Optional
from pydantic import BaseModel


class TrialBalanceItem(BaseModel):
    ledger_id: str
    ledger_name: str
    group_name: str
    opening_debit: float = 0.0
    opening_credit: float = 0.0
    transactions_debit: float = 0.0
    transactions_credit: float = 0.0
    closing_debit: float = 0.0
    closing_credit: float = 0.0


class TrialBalanceResponse(BaseModel):
    items: List[TrialBalanceItem] = []
    total_opening_debit: float
    total_opening_credit: float
    total_transactions_debit: float
    total_transactions_credit: float
    total_closing_debit: float
    total_closing_credit: float
    is_balanced: bool = True
    discrepancy: float = 0.0
    from_date: date
    to_date: date


class PnLLineItem(BaseModel):
    title: str
    amount: float
    percentage_of_revenue: Optional[float] = None
    sub_items: List["PnLLineItem"] = []


class ProfitAndLossResponse(BaseModel):
    revenue_from_operations: float
    other_income: float
    total_revenue: float
    cost_of_materials_consumed: float
    employee_benefit_expenses: float
    finance_costs: float
    depreciation_and_amortization: float
    other_expenses: float
    total_expenses: float
    gross_profit: float
    net_profit_before_tax: float
    net_profit_after_tax: float
    from_date: date
    to_date: date


class BalanceSheetScheduleItem(BaseModel):
    schedule_name: str
    schedule_number: str
    amount: float
    previous_year_amount: Optional[float] = 0.0


class BalanceSheetResponse(BaseModel):
    # Equities & Liabilities
    shareholders_funds: float
    non_current_liabilities: float
    current_liabilities: float
    total_equity_and_liabilities: float

    # Assets
    non_current_assets: float
    current_assets: float
    total_assets: float

    is_balanced: bool = True
    as_on_date: date


class DayBookEntryResponse(BaseModel):
    id: str
    voucher_number: str
    voucher_type: str
    voucher_date: date
    particulars: str
    debit_amount: float
    credit_amount: float
    narration: Optional[str] = None
