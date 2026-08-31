import uuid
from datetime import datetime
from typing import List
from supabase import Client
from app.schemas.masters import (
    AccountGroupResponse,
    BalanceType,
    LedgerCreate,
    LedgerResponse,
    PrimaryGroupCategory,
    StockItemCreate,
    StockItemResponse,
)

# Mock Store for Ledgers
_in_memory_ledgers: List[dict] = [
    {
        "id": "led-cash-01",
        "business_id": "BIZ-DEFAULT-01",
        "name": "Cash on Hand",
        "parent_group_id": "grp-current-assets",
        "parent_group_name": "Current Assets",
        "opening_balance": 50000.0,
        "opening_balance_type": "Dr",
        "current_balance": 125000.0,
        "current_balance_type": "Dr",
    },
    {
        "id": "led-hdfc-01",
        "business_id": "BIZ-DEFAULT-01",
        "name": "HDFC Current Account (A/c 50200012345678)",
        "parent_group_id": "grp-bank-accounts",
        "parent_group_name": "Bank Accounts",
        "opening_balance": 450000.0,
        "opening_balance_type": "Dr",
        "current_balance": 875000.0,
        "current_balance_type": "Dr",
    },
    {
        "id": "led-sales-01",
        "business_id": "BIZ-DEFAULT-01",
        "name": "Domestic GST Sales @ 18%",
        "parent_group_id": "grp-sales-accounts",
        "parent_group_name": "Sales Accounts",
        "opening_balance": 0.0,
        "opening_balance_type": "Cr",
        "current_balance": 2450000.0,
        "current_balance_type": "Cr",
    },
    {
        "id": "led-debtor-01",
        "business_id": "BIZ-DEFAULT-01",
        "name": "Bharat Electronics Ltd.",
        "parent_group_id": "grp-sundry-debtors",
        "parent_group_name": "Sundry Debtors",
        "opening_balance": 120000.0,
        "opening_balance_type": "Dr",
        "current_balance": 238000.0,
        "current_balance_type": "Dr",
        "gstin": "27AAACB1234D1Z5",
    },
]

_in_memory_stock: List[dict] = [
    {
        "id": "stk-01",
        "business_id": "BIZ-DEFAULT-01",
        "name": "Solar Inverter 5kVA Hybrid",
        "hsn_code": "85044090",
        "unit_of_measure": "NOS",
        "opening_quantity": 25.0,
        "opening_rate": 45000.0,
        "current_quantity": 18.0,
        "current_valuation": 810000.0,
        "tax_rate": 18.0,
    }
]


class MastersService:
    def __init__(self, db: Client):
        self.db = db

    async def get_chart_of_accounts(self, business_id: str) -> List[AccountGroupResponse]:
        """Returns standard hierarchical 28 Tally primary groups."""
        return [
            AccountGroupResponse(
                id="grp-assets",
                name="Assets",
                primary_category=PrimaryGroupCategory.ASSETS,
                sub_groups=[
                    AccountGroupResponse(
                        id="grp-current-assets",
                        name="Current Assets",
                        primary_category=PrimaryGroupCategory.ASSETS,
                        parent_group_id="grp-assets",
                        sub_groups=[
                            AccountGroupResponse(id="grp-bank-accounts", name="Bank Accounts", primary_category=PrimaryGroupCategory.ASSETS, parent_group_id="grp-current-assets"),
                            AccountGroupResponse(id="grp-sundry-debtors", name="Sundry Debtors", primary_category=PrimaryGroupCategory.ASSETS, parent_group_id="grp-current-assets"),
                            AccountGroupResponse(id="grp-cash-in-hand", name="Cash-in-Hand", primary_category=PrimaryGroupCategory.ASSETS, parent_group_id="grp-current-assets"),
                        ],
                    ),
                    AccountGroupResponse(
                        id="grp-fixed-assets",
                        name="Fixed Assets",
                        primary_category=PrimaryGroupCategory.ASSETS,
                        parent_group_id="grp-assets",
                    ),
                ],
            ),
            AccountGroupResponse(
                id="grp-liabilities",
                name="Liabilities",
                primary_category=PrimaryGroupCategory.LIABILITIES,
                sub_groups=[
                    AccountGroupResponse(
                        id="grp-capital-account",
                        name="Capital Account",
                        primary_category=PrimaryGroupCategory.LIABILITIES,
                        parent_group_id="grp-liabilities",
                    ),
                    AccountGroupResponse(
                        id="grp-current-liabilities",
                        name="Current Liabilities",
                        primary_category=PrimaryGroupCategory.LIABILITIES,
                        parent_group_id="grp-liabilities",
                        sub_groups=[
                            AccountGroupResponse(id="grp-sundry-creditors", name="Sundry Creditors", primary_category=PrimaryGroupCategory.LIABILITIES, parent_group_id="grp-current-liabilities"),
                            AccountGroupResponse(id="grp-duties-and-taxes", name="Duties & Taxes", primary_category=PrimaryGroupCategory.LIABILITIES, parent_group_id="grp-current-liabilities"),
                        ],
                    ),
                ],
            ),
            AccountGroupResponse(
                id="grp-income",
                name="Income",
                primary_category=PrimaryGroupCategory.INCOME,
                sub_groups=[
                    AccountGroupResponse(id="grp-sales-accounts", name="Sales Accounts", primary_category=PrimaryGroupCategory.INCOME, parent_group_id="grp-income"),
                    AccountGroupResponse(id="grp-direct-incomes", name="Direct Incomes", primary_category=PrimaryGroupCategory.INCOME, parent_group_id="grp-income"),
                ],
            ),
            AccountGroupResponse(
                id="grp-expenses",
                name="Expenses",
                primary_category=PrimaryGroupCategory.EXPENSES,
                sub_groups=[
                    AccountGroupResponse(id="grp-purchase-accounts", name="Purchase Accounts", primary_category=PrimaryGroupCategory.EXPENSES, parent_group_id="grp-expenses"),
                    AccountGroupResponse(id="grp-indirect-expenses", name="Indirect Expenses", primary_category=PrimaryGroupCategory.EXPENSES, parent_group_id="grp-expenses"),
                ],
            ),
        ]

    async def fetch_ledgers(self, business_id: str) -> List[LedgerResponse]:
        """Fetches all ledgers for active tenant."""
        results = [l for l in _in_memory_ledgers if l["business_id"] == business_id]
        return [LedgerResponse(**l) for l in results]

    async def create_ledger(self, business_id: str, payload: LedgerCreate) -> LedgerResponse:
        """Creates a new ledger master."""
        record = {
            "id": f"led-{uuid.uuid4().hex[:8]}",
            "business_id": business_id,
            "name": payload.name,
            "parent_group_id": payload.parent_group_id,
            "parent_group_name": payload.parent_group_name or "Current Assets",
            "opening_balance": payload.opening_balance,
            "opening_balance_type": payload.opening_balance_type.value,
            "current_balance": payload.opening_balance,
            "current_balance_type": payload.opening_balance_type.value,
            "gstin": payload.gstin,
            "pan": payload.pan,
            "state_code": payload.state_code,
            "hsn_sac_code": payload.hsn_sac_code,
            "credit_limit": payload.credit_limit,
            "email": payload.email,
            "phone": payload.phone,
            "created_at": datetime.utcnow().isoformat(),
        }
        _in_memory_ledgers.append(record)
        return LedgerResponse(**record)

    async def fetch_stock_items(self, business_id: str) -> List[StockItemResponse]:
        """Fetches inventory stock items."""
        results = [s for s in _in_memory_stock if s["business_id"] == business_id]
        return [StockItemResponse(**s) for s in results]
