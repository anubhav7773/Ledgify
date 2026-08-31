from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field, model_validator
from app.core.exceptions import DoubleEntryDiscrepancyException


class VoucherTypeCategory(str, Enum):
    SALES = "Sales"
    PURCHASE = "Purchase"
    PAYMENT = "Payment"
    RECEIPT = "Receipt"
    CONTRA = "Contra"
    JOURNAL = "Journal"
    DEBIT_NOTE = "Debit Note"
    CREDIT_NOTE = "Credit Note"
    STOCK_JOURNAL = "Stock Journal"


class VoucherItemCreate(BaseModel):
    ledger_id: str
    ledger_name: Optional[str] = None
    is_debit: bool
    amount: float = Field(..., gt=0, description="Amount must be strictly positive")
    narration: Optional[str] = None
    hsn_sac_code: Optional[str] = None
    tax_rate: float = 0.0


class VoucherItemResponse(VoucherItemCreate):
    id: Optional[str] = None
    voucher_id: Optional[str] = None


class VoucherCreate(BaseModel):
    voucher_type: VoucherTypeCategory = VoucherTypeCategory.JOURNAL
    voucher_number: Optional[str] = None
    voucher_date: date = Field(default_factory=date.today)
    narration: Optional[str] = None
    reference_number: Optional[str] = None
    items: List[VoucherItemCreate] = Field(..., min_length=2, description="At least 2 line items are required for double-entry")

    @model_validator(mode="after")
    def validate_double_entry_balance(self) -> "VoucherCreate":
        total_debits = sum(item.amount for item in self.items if item.is_debit)
        total_credits = sum(item.amount for item in self.items if not item.is_debit)

        # Allow 0.01 tolerance for minor float rounding
        if abs(total_debits - total_credits) > 0.01:
            raise DoubleEntryDiscrepancyException(debit_sum=total_debits, credit_sum=total_credits)

        return self


class VoucherResponse(BaseModel):
    id: str
    business_id: str
    voucher_type: str
    voucher_number: str
    voucher_date: date
    narration: Optional[str] = None
    reference_number: Optional[str] = None
    total_amount: float
    items: List[VoucherItemResponse] = []
    created_at: Optional[datetime] = None


class VoucherFilterParams(BaseModel):
    voucher_type: Optional[str] = None
    from_date: Optional[date] = None
    to_date: Optional[date] = None
    search_query: Optional[str] = None
