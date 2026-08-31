from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class ReconciliationStatus(str, Enum):
    UNMATCHED = "UNMATCHED"
    AUTO_MATCHED = "AUTO_MATCHED"
    MANUALLY_MATCHED = "MANUALLY_MATCHED"


class BankAccountResponse(BaseModel):
    id: str
    business_id: str
    bank_name: str
    account_number: str
    ifsc_code: str
    account_type: str = "CURRENT"
    book_balance: float
    bank_statement_balance: float
    unreconciled_difference: float
    unreconciled_count: int
    is_live_sync: bool = False


class BankTransactionResponse(BaseModel):
    id: str
    bank_account_id: str
    transaction_date: date
    description: str
    reference_number: Optional[str] = None
    withdrawal_amount: float = 0.0  # Debit from bank
    deposit_amount: float = 0.0     # Credit to bank
    balance_after: float
    status: ReconciliationStatus = ReconciliationStatus.UNMATCHED
    matched_voucher_id: Optional[str] = None
    confidence_score: Optional[float] = None


class ReconciliationMatchRequest(BaseModel):
    transaction_id: str
    voucher_id: Optional[str] = None
    action_type: str = "MATCH"  # 'MATCH', 'CREATE_CONTRA', 'CREATE_PAYMENT'


class EmployeeResponse(BaseModel):
    id: str
    business_id: str
    employee_code: str
    full_name: str
    designation: str
    department: str
    pan_number: str
    uan_number: Optional[str] = None
    esic_ip_number: Optional[str] = None
    bank_account_number: str
    basic_salary: float
    hra_allowance: float
    special_allowance: float
    gross_salary: float
    is_active: bool = True


class PayslipResponse(BaseModel):
    employee_id: str
    employee_name: str
    designation: str
    month: str
    working_days: int
    days_present: int
    # Earnings
    basic: float
    hra: float
    allowances: float
    gross_earnings: float
    # Deductions
    epf_employee: float  # 12%
    esi_employee: float  # 0.75%
    professional_tax: float
    tds_deducted: float
    total_deductions: float
    # Net
    net_payable: float


class MonthlyPayrollSummaryResponse(BaseModel):
    month: str  # '2026-08'
    total_employees: int
    total_gross_salary: float
    total_epf: float
    total_esi: float
    total_professional_tax: float
    total_tds: float
    total_net_disbursement: float
    journal_voucher_id: Optional[str] = None
    payslips: List[PayslipResponse] = []


class TdsTcsRegisterItem(BaseModel):
    id: str
    section_code: str  # '194Q', '194C', '194J', '206C'
    section_description: str
    party_name: str
    party_pan: str
    voucher_number: str
    transaction_date: date
    gross_amount: float
    rate_percent: float
    tax_deducted: float
    deposit_status: str = "PENDING"  # 'PENDING', 'DEPOSITED'
    challan_bsr_code: Optional[str] = None
    challan_cin: Optional[str] = None


class Form26QSummaryResponse(BaseModel):
    quarter: str  # 'Q2_2026_27'
    financial_year: str = "2026-27"
    total_deductions_count: int
    total_gross_taxable: float
    total_tds_deducted: float
    total_tds_deposited: float
    pending_deposit_amount: float
    is_due_soon: bool = False
    due_date: date
