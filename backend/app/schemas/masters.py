from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class BalanceType(str, Enum):
    DEBIT = "Dr"
    CREDIT = "Cr"


class PrimaryGroupCategory(str, Enum):
    ASSETS = "Assets"
    LIABILITIES = "Liabilities"
    INCOME = "Income"
    EXPENSES = "Expenses"


class AccountGroupResponse(BaseModel):
    id: str
    name: str
    primary_category: PrimaryGroupCategory
    parent_group_id: Optional[str] = None
    sub_groups: List["AccountGroupResponse"] = []


class LedgerCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    parent_group_id: str
    parent_group_name: Optional[str] = None
    opening_balance: float = 0.0
    opening_balance_type: BalanceType = BalanceType.DEBIT
    gstin: Optional[str] = None
    pan: Optional[str] = None
    state_code: Optional[str] = None
    hsn_sac_code: Optional[str] = None
    credit_limit: Optional[float] = None
    email: Optional[str] = None
    phone: Optional[str] = None


class LedgerResponse(LedgerCreate):
    id: str
    business_id: str
    current_balance: float = 0.0
    current_balance_type: BalanceType = BalanceType.DEBIT
    created_at: Optional[datetime] = None


class StockItemCreate(BaseModel):
    name: str = Field(..., min_length=2)
    hsn_code: Optional[str] = None
    unit_of_measure: str = "NOS"
    opening_quantity: float = 0.0
    opening_rate: float = 0.0
    tax_rate: float = 18.0


class StockItemResponse(StockItemCreate):
    id: str
    business_id: str
    current_quantity: float = 0.0
    current_valuation: float = 0.0
