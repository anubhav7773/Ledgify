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
    opening_stock: float = 0.0
    purchase_accounts: float = 0.0
    direct_expenses: float = 0.0
    sales_accounts: float = 0.0
    closing_stock: float = 0.0
    gross_profit: float = 0.0
    indirect_incomes: float = 0.0
    indirect_expenses: float = 0.0
    net_profit: float = 0.0
    from_date: date
    to_date: date


class BalanceSheetResponse(BaseModel):
    as_on_date: date
    capital_equity: float = 0.0
    current_net_profit: float = 0.0
    total_equity_and_reserves: float = 0.0
    loans_liability: float = 0.0
    current_liabilities: float = 0.0
    total_liabilities_and_equity: float = 0.0
    fixed_assets: float = 0.0
    current_assets: float = 0.0
    total_assets: float = 0.0
    is_balanced: bool = True
    discrepancy: float = 0.0


class DayBookEntryResponse(BaseModel):
    id: str
    voucher_number: str
    voucher_type: str
    voucher_date: date
    narration: Optional[str] = None
    party_name: str
    total_amount: float


class BusinessRatiosData(BaseModel):
    as_of_date: str
    current_ratio: float = 1.5
    quick_ratio: float = 1.2
    working_capital: float = 0.0
    gross_profit_margin: float = 0.25
    net_profit_margin: float = 0.18
    debtor_days_dso: float = 30.0
    creditor_days_dpo: float = 45.0
    inventory_turnover: float = 6.0
    debt_to_equity: float = 0.4
    current_assets: float = 0.0
    current_liabilities: float = 0.0
    sundry_debtors: float = 0.0
    sundry_creditors: float = 0.0


class CashForecastPoint(BaseModel):
    date: str
    projected_inflow: float = 0.0
    projected_outflow: float = 0.0
    projected_balance: float = 0.0


class DashboardKpisResponse(BaseModel):
    net_profit_ytd: float = 0.0
    operating_cash: float = 0.0
    overdue_receivables: float = 0.0
    overdue_payables: float = 0.0
    monthly_sales_turnover: float = 0.0
    health_score: int = 90
    ratios: BusinessRatiosData
    forecast_points: List[CashForecastPoint] = []
