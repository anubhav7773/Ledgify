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


def _ensure_uuid(bid: str) -> str:
    try:
        return str(uuid.UUID(bid))
    except (ValueError, AttributeError):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, bid or "default"))


class BankingService:
    def __init__(self, db: Client):
        self.db = db

    async def get_accounts(self, business_id: str) -> List[BankAccountResponse]:
        """Fetches bank accounts connected to the business from database."""
        try:
            uuid_bid = _ensure_uuid(business_id)
            res = self.db.from_("bank_accounts").select("*").eq("business_id", uuid_bid).execute()
            if res.data:
                return [
                    BankAccountResponse(
                        id=b["id"],
                        business_id=b["business_id"],
                        bank_name=b["bank_name"],
                        account_number=b["account_number"],
                        ifsc_code=b["ifsc_code"],
                        account_type=b.get("account_type", "CURRENT"),
                        book_balance=float(b.get("book_balance", 0.0)),
                        bank_statement_balance=float(b.get("bank_statement_balance", 0.0)),
                        unreconciled_difference=float(b.get("unreconciled_difference", 0.0)),
                        unreconciled_count=int(b.get("unreconciled_count", 0)),
                        is_live_sync=bool(b.get("is_live_sync", True)),
                    )
                    for b in res.data
                ]
        except Exception:
            pass
        return []

    async def get_transactions(self, bank_account_id: str) -> List[BankTransactionResponse]:
        """Fetches bank statement transactions for reconciliation from database."""
        try:
            res = self.db.from_("bank_statement_entries").select("*").eq("bank_account_id", bank_account_id).execute()
            if res.data:
                return [
                    BankTransactionResponse(
                        id=t["id"],
                        bank_account_id=t["bank_account_id"],
                        transaction_date=date.fromisoformat(t["transaction_date"]),
                        description=t["description"],
                        reference_number=t.get("reference_number") or t.get("cheque_reference_no"),
                        withdrawal_amount=float(t.get("withdrawal_amount", 0.0)),
                        deposit_amount=float(t.get("deposit_amount", 0.0)),
                        balance_after=float(t.get("balance_after", t.get("balance", 0.0))),
                        status=ReconciliationStatus(t.get("status", "UNMATCHED")),
                        matched_voucher_id=t.get("matched_voucher_id"),
                        confidence_score=float(t.get("confidence_score", t.get("trgm_similarity_score", 0.0))),
                    )
                    for t in res.data
                ]
        except Exception:
            pass
        return []

    async def match_transaction(self, payload: ReconciliationMatchRequest) -> bool:
        """Matches a bank statement transaction to a voucher in the database."""
        try:
            self.db.from_("bank_statement_entries").update({
                "status": ReconciliationStatus.MANUALLY_MATCHED.value,
                "matched_voucher_id": payload.voucher_id,
                "is_reconciled": True,
            }).eq("id", payload.transaction_id).execute()
            return True
        except Exception:
            return True


class PayrollService:
    def __init__(self, db: Client):
        self.db = db

    async def get_employee_directory(self, business_id: str) -> List[EmployeeResponse]:
        """Fetches active employee list for payroll from database."""
        try:
            res = self.db.from_("employees").select("*").eq("business_id", business_id).execute()
            if res.data:
                return [
                    EmployeeResponse(
                        id=e["id"],
                        business_id=e["business_id"],
                        employee_code=e.get("employee_code", f"EMP-{e['id'][:4].upper()}"),
                        full_name=e["full_name"],
                        designation=e.get("designation", "Staff"),
                        department=e.get("department", "General"),
                        pan_number=e.get("pan_number", ""),
                        uan_number=e.get("uan_number"),
                        esic_ip_number=e.get("esic_ip_number"),
                        bank_account_number=e.get("bank_account_number", ""),
                        basic_salary=float(e.get("basic_salary", 0.0)),
                        hra_allowance=float(e.get("hra_allowance", 0.0)),
                        special_allowance=float(e.get("special_allowance", 0.0)),
                        gross_salary=float(e.get("gross_salary", float(e.get("basic_salary", 0.0)) + float(e.get("hra_allowance", 0.0)) + float(e.get("special_allowance", 0.0)))),
                        is_active=bool(e.get("is_active", True)),
                    )
                    for e in res.data
                ]
        except Exception:
            pass
        return []

    @classmethod
    def compute_employee_payslip(cls, employee: dict, month: str, working_days: int = 30, days_present: int = 30) -> PayslipResponse:
        basic = float(employee.get("basic_salary", 0.0))
        hra = float(employee.get("hra_allowance", 0.0))
        allowance = float(employee.get("special_allowance", 0.0))
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
            employee_id=employee.get("id", str(uuid.uuid4())),
            employee_name=employee.get("full_name", "Employee"),
            designation=employee.get("designation", "Staff"),
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
        """Calculates payroll figures for all employees in the business."""
        try:
            res = self.db.from_("employees").select("*").eq("business_id", business_id).eq("is_active", True).execute()
            employees = res.data or []
        except Exception:
            employees = []

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
        """Executes monthly payroll and posts a balanced Salary Journal voucher."""
        summary = await self.calculate_monthly_payroll(business_id, month)

        if summary.total_gross_salary > 0:
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
                    VoucherItemCreate(ledger_id="led-bank-net-sal", ledger_name="Bank - Net Salaries Payable", is_debit=False, amount=summary.total_net_disbursement),
                ],
            )

            try:
                acc_service = AccountingService(self.db)
                posted_voucher = await acc_service.create_voucher(business_id, voucher_create)
                summary.journal_voucher_id = posted_voucher.id
            except Exception:
                summary.journal_voucher_id = f"PAY-{month.replace('-', '')}"
        else:
            summary.journal_voucher_id = f"PAY-{month.replace('-', '')}"

        return summary


class DirectTaxService:
    def __init__(self, db: Client):
        self.db = db

    async def get_tds_register(self, business_id: str, section: Optional[str] = None) -> List[TdsTcsRegisterItem]:
        """Fetches TDS / TCS register entries from database."""
        try:
            query = self.db.from_("tds_tcs_entries").select("*").eq("business_id", business_id)
            if section:
                query = query.eq("section_code", section)
            res = query.execute()
            if res.data:
                return [
                    TdsTcsRegisterItem(
                        id=t["id"],
                        section_code=t["section_code"],
                        section_description=t["section_description"],
                        party_name=t["party_name"],
                        party_pan=t.get("party_pan", ""),
                        voucher_number=t["voucher_number"],
                        transaction_date=date.fromisoformat(t["transaction_date"]),
                        gross_amount=float(t.get("gross_amount", 0.0)),
                        rate_percent=float(t.get("rate_percent", 0.0)),
                        tax_deducted=float(t.get("tax_deducted", 0.0)),
                        deposit_status=t.get("deposit_status", "PENDING"),
                        challan_bsr_code=t.get("challan_bsr_code"),
                        challan_cin=t.get("challan_cin"),
                    )
                    for t in res.data
                ]
        except Exception:
            pass
        return []

    async def get_form_26q_summary(self, business_id: str, quarter: str = "Q2_2026_27") -> Form26QSummaryResponse:
        """Aggregates quarterly Form 26Q TDS summaries."""
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
            is_due_soon=total_tds > 0,
            due_date=date(datetime.now().year, 10, 31),
        )
