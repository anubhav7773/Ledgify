import uuid
from datetime import date, datetime
from typing import List, Optional
from supabase import Client
from app.core.exceptions import NotFoundException
from app.schemas.accounting import VoucherCreate, VoucherItemCreate, VoucherTypeCategory
from app.schemas.banking_payroll import (
    BankAccountResponse,
    BankTransactionResponse,
    EmployeeResponse,
    Form26QSummaryResponse,
    MonthlyPayrollSummaryResponse,
    PayslipResponse,
    ReconciliationMatchRequest,
    ReconciliationStatus,
    TdsTcsRegisterItem,
)
from app.services.accounting_service import AccountingService

# Mock Store
_in_memory_bank_accounts: List[dict] = [
    {
        "id": "bnk-hdfc-01",
        "business_id": "BIZ-DEFAULT-01",
        "bank_name": "HDFC Bank Ltd.",
        "account_number": "50200012345678",
        "ifsc_code": "HDFC0000240",
        "account_type": "CURRENT",
        "book_balance": 820000.0,
        "bank_statement_balance": 875000.0,
        "unreconciled_difference": 55000.0,
        "unreconciled_count": 3,
        "is_live_sync": True,
    }
]

_in_memory_bank_txs: List[dict] = [
    {
        "id": "tx-001",
        "bank_account_id": "bnk-hdfc-01",
        "transaction_date": "2026-08-19",
        "description": "NEFT CR-BHARAT ELECTRONICS LTD-SETTLEMENT",
        "reference_number": "N1234567890",
        "withdrawal_amount": 0.0,
        "deposit_amount": 118000.0,
        "balance_after": 875000.0,
        "status": "AUTO_MATCHED",
        "matched_voucher_id": "vch-demo-001",
        "confidence_score": 0.98,
    },
    {
        "id": "tx-002",
        "bank_account_id": "bnk-hdfc-01",
        "transaction_date": "2026-08-20",
        "description": "ACH DR-TATA TELESERVICES-BILL PAYMENT",
        "reference_number": "ACH998822",
        "withdrawal_amount": 4500.0,
        "deposit_amount": 0.0,
        "balance_after": 870500.0,
        "status": "UNMATCHED",
        "matched_voucher_id": None,
        "confidence_score": 0.0,
    },
    {
        "id": "tx-003",
        "bank_account_id": "bnk-hdfc-01",
        "transaction_date": "2026-08-21",
        "description": "UPI/428901234891/OFFICE CHAI NASHTA",
        "reference_number": "UPI428901234",
        "withdrawal_amount": 650.0,
        "deposit_amount": 0.0,
        "balance_after": 869850.0,
        "status": "UNMATCHED",
        "matched_voucher_id": None,
        "confidence_score": 0.0,
    },
]

_in_memory_employees: List[dict] = [
    {
        "id": "emp-01",
        "business_id": "BIZ-DEFAULT-01",
        "employee_code": "EMP-001",
        "full_name": "Aarav Sharma",
        "designation": "Senior Financial Controller",
        "department": "Finance & Accounts",
        "pan_number": "ABCPS1234A",
        "uan_number": "100982348910",
        "esic_ip_number": "3129847192",
        "bank_account_number": "501002348912",
        "basic_salary": 45000.0,
        "hra_allowance": 18000.0,
        "special_allowance": 12000.0,
        "gross_salary": 75000.0,
        "is_active": True,
    },
    {
        "id": "emp-02",
        "business_id": "BIZ-DEFAULT-01",
        "employee_code": "EMP-002",
        "full_name": "Priya Patel",
        "designation": "GST Compliance Specialist",
        "department": "Taxation",
        "pan_number": "ABCPP5678B",
        "uan_number": "100982348911",
        "esic_ip_number": None,
        "bank_account_number": "501002348913",
        "basic_salary": 35000.0,
        "hra_allowance": 14000.0,
        "special_allowance": 11000.0,
        "gross_salary": 60000.0,
        "is_active": True,
    },
]

_in_memory_tds_register: List[dict] = [
    {
        "id": "tds-001",
        "business_id": "BIZ-DEFAULT-01",
        "section_code": "194Q",
        "section_description": "TDS on Purchase of Goods (>₹50L)",
        "party_name": "Tata Steel Supply Co.",
        "party_pan": "AAACT9999P",
        "voucher_number": "PUR-2026-089",
        "transaction_date": "2026-08-15",
        "gross_amount": 5500000.0,
        "rate_percent": 0.1,
        "tax_deducted": 5500.0,
        "deposit_status": "DEPOSITED",
        "challan_bsr_code": "0290124",
        "challan_cin": "02901241508202600123",
    },
    {
        "id": "tds-002",
        "business_id": "BIZ-DEFAULT-01",
        "section_code": "194J",
        "section_description": "TDS on Professional/Technical Fees",
        "party_name": "Kedia & Associates Chartered Accountants",
        "party_pan": "AABFK4567M",
        "voucher_number": "JRN-2026-012",
        "transaction_date": "2026-08-18",
        "gross_amount": 100000.0,
        "rate_percent": 10.0,
        "tax_deducted": 10000.0,
        "deposit_status": "PENDING",
        "challan_bsr_code": None,
        "challan_cin": None,
    },
]


class BankingService:
    def __init__(self, db: Client):
        self.db = db

    async def get_accounts(self, business_id: str) -> List[BankAccountResponse]:
        results = [b for b in _in_memory_bank_accounts if b["business_id"] == business_id]
        return [BankAccountResponse(**b) for b in results]

    async def get_transactions(self, bank_account_id: str) -> List[BankTransactionResponse]:
        results = [t for t in _in_memory_bank_txs if t["bank_account_id"] == bank_account_id]
        return [
            BankTransactionResponse(
                id=t["id"],
                bank_account_id=t["bank_account_id"],
                transaction_date=date.fromisoformat(t["transaction_date"]),
                description=t["description"],
                reference_number=t.get("reference_number"),
                withdrawal_amount=t["withdrawal_amount"],
                deposit_amount=t["deposit_amount"],
                balance_after=t["balance_after"],
                status=ReconciliationStatus(t["status"]),
                matched_voucher_id=t.get("matched_voucher_id"),
                confidence_score=t.get("confidence_score"),
            )
            for t in results
        ]

    async def match_transaction(self, payload: ReconciliationMatchRequest) -> bool:
        tx = next((t for t in _in_memory_bank_txs if t["id"] == payload.transaction_id), None)
        if not tx:
            raise NotFoundException(resource="Bank Transaction", resource_id=payload.transaction_id)

        tx["status"] = ReconciliationStatus.MANUALLY_MATCHED.value
        tx["matched_voucher_id"] = payload.voucher_id or f"vch-auto-{uuid.uuid4().hex[:6]}"
        return True


class PayrollService:
    def __init__(self, db: Client):
        self.db = db

    async def get_employee_directory(self, business_id: str) -> List[EmployeeResponse]:
        results = [e for e in _in_memory_employees if e["business_id"] == business_id]
        return [EmployeeResponse(**e) for e in results]

    @classmethod
    def compute_employee_payslip(cls, employee: dict, month: str, working_days: int = 30, days_present: int = 30) -> PayslipResponse:
        basic = employee["basic_salary"]
        hra = employee["hra_allowance"]
        allowance = employee["special_allowance"]
        gross = basic + hra + allowance

        # Statutory Deductions
        # EPF: 12% of Basic (Wage ceiling ₹15k => max ₹1800, or actual on basic)
        epf = round(min(basic * 0.12, 1800.0), 2)
        # ESI: 0.75% of Gross if gross <= 21,000
        esi = round(gross * 0.0075, 2) if gross <= 21000.0 else 0.0
        # Professional Tax (Maharashtra standard)
        pt = 200.0 if gross > 10000.0 else 0.0
        # TDS approximation
        tds = round(gross * 0.05, 2) if gross > 50000.0 else 0.0

        total_ded = epf + esi + pt + tds
        net = gross - total_ded

        return PayslipResponse(
            employee_id=employee["id"],
            employee_name=employee["full_name"],
            designation=employee["designation"],
            month=month,
            working_days=working_days,
            days_present=days_present,
            basic=basic,
            hra=hra,
            allowances=allowance,
            gross_earnings=gross,
            epf_employee=epf,
            esi_employee=esi,
            professional_tax=pt,
            tds_deducted=tds,
            total_deductions=total_ded,
            net_payable=net,
        )

    async def calculate_monthly_payroll(self, business_id: str, month: str) -> MonthlyPayrollSummaryResponse:
        employees = [e for e in _in_memory_employees if e["business_id"] == business_id]
        payslips = [self.compute_employee_payslip(emp, month) for emp in employees]

        total_gross = sum(p.gross_earnings for p in payslips)
        total_epf = sum(p.epf_employee for p in payslips)
        total_esi = sum(p.esi_employee for p in payslips)
        total_pt = sum(p.professional_tax for p in payslips)
        total_tds = sum(p.tds_deducted for p in payslips)
        total_net = sum(p.net_payable for p in payslips)

        return MonthlyPayrollSummaryResponse(
            month=month,
            total_employees=len(employees),
            total_gross_salary=total_gross,
            total_epf=total_epf,
            total_esi=total_esi,
            total_professional_tax=total_pt,
            total_tds=total_tds,
            total_net_disbursement=total_net,
            payslips=payslips,
        )

    async def execute_and_post_payroll_journal(self, business_id: str, month: str) -> MonthlyPayrollSummaryResponse:
        summary = await self.calculate_monthly_payroll(business_id, month)

        # Create balanced Salary Journal Voucher
        # Dr: Staff Salary & Wages (Gross)
        # Cr: EPF Payable, PT Payable, TDS Payable, Net Salary Payable Bank
        voucher_create = VoucherCreate(
            voucher_type=VoucherTypeCategory.JOURNAL,
            voucher_number=f"PAY-{month.replace('-', '')}",
            voucher_date=date.today(),
            narration=f"Monthly Payroll execution for {month} ({summary.total_employees} staff)",
            items=[
                VoucherItemCreate(ledger_id="led-sal-exp", ledger_name="Staff Salary Expense", is_debit=True, amount=summary.total_gross_salary),
                VoucherItemCreate(ledger_id="led-epf-pay", ledger_name="EPF Payable A/c", is_debit=False, amount=summary.total_epf),
                VoucherItemCreate(ledger_id="led-pt-pay", ledger_name="Professional Tax Payable A/c", is_debit=False, amount=summary.total_professional_tax),
                VoucherItemCreate(ledger_id="led-tds-sal-pay", ledger_name="TDS on Salaries (Sec 192) Payable", is_debit=False, amount=summary.total_tds),
                VoucherItemCreate(ledger_id="led-bank-net-sal", ledger_name="HDFC Bank - Net Salaries Payable", is_debit=False, amount=summary.total_net_disbursement),
            ],
        )

        acc_service = AccountingService(self.db)
        posted_voucher = await acc_service.create_voucher(business_id, voucher_create)
        summary.journal_voucher_id = posted_voucher.id

        return summary


class DirectTaxService:
    def __init__(self, db: Client):
        self.db = db

    async def get_tds_register(self, business_id: str, section: Optional[str] = None) -> List[TdsTcsRegisterItem]:
        results = [t for t in _in_memory_tds_register if t["business_id"] == business_id]
        if section:
            results = [t for t in results if t["section_code"] == section]

        return [
            TdsTcsRegisterItem(
                id=t["id"],
                section_code=t["section_code"],
                section_description=t["section_description"],
                party_name=t["party_name"],
                party_pan=t["party_pan"],
                voucher_number=t["voucher_number"],
                transaction_date=date.fromisoformat(t["transaction_date"]),
                gross_amount=t["gross_amount"],
                rate_percent=t["rate_percent"],
                tax_deducted=t["tax_deducted"],
                deposit_status=t["deposit_status"],
                challan_bsr_code=t.get("challan_bsr_code"),
                challan_cin=t.get("challan_cin"),
            )
            for t in results
        ]

    async def get_form_26q_summary(self, business_id: str, quarter: str = "Q2_2026_27") -> Form26QSummaryResponse:
        register = await self.get_tds_register(business_id)

        total_gross = sum(r.gross_amount for r in register)
        total_tds = sum(r.tax_deducted for r in register)
        total_dep = sum(r.tax_deducted for r in register if r.deposit_status == "DEPOSITED")
        pending = total_tds - total_dep

        return Form26QSummaryResponse(
            quarter=quarter,
            financial_year="2026-27",
            total_deductions_count=len(register),
            total_gross_taxable=total_gross,
            total_tds_deducted=total_tds,
            total_tds_deposited=total_dep,
            pending_deposit_amount=pending,
            is_due_soon=True,
            due_date=date(2026, 10, 31),
        )
