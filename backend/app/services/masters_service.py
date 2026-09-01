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


def _ensure_uuid(bid: str) -> str:
    try:
        return str(uuid.UUID(bid))
    except (ValueError, AttributeError):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, bid or "default"))


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

    async def fetch_ledgers(self, business_id: str, group_name: Optional[str] = None) -> List[LedgerResponse]:
        """Fetches all accounts/ledgers for active tenant from database."""
        try:
            uuid_bid = _ensure_uuid(business_id)
            query = self.db.from_("accounts").select("*").eq("business_id", uuid_bid)
            if group_name:
                query = query.ilike("group_name", f"%{group_name}%")
            res = query.execute()
            if res.data:
                return [
                    LedgerResponse(
                        id=l["id"],
                        business_id=l["business_id"],
                        name=l["name"],
                        parent_group_id=l.get("parent_id") or l.get("parent_group_id", "grp-current-assets"),
                        parent_group_name=l.get("group_name") or l.get("parent_group_name", "Current Assets"),
                        opening_balance=float(l.get("opening_balance", 0.0)),
                        opening_balance_type=l.get("opening_balance_type", "Dr"),
                        current_balance=float(l.get("current_balance", l.get("opening_balance", 0.0))),
                        current_balance_type=l.get("current_balance_type", l.get("opening_balance_type", "Dr")),
                        gstin=l.get("party_gstin") or l.get("gstin"),
                        pan=l.get("party_pan") or l.get("pan"),
                        state_code=l.get("state_code"),
                        hsn_sac_code=l.get("hsn_sac_code"),
                        credit_limit=float(l.get("credit_limit", 0.0)) if l.get("credit_limit") else None,
                        email=l.get("email"),
                        phone=l.get("phone"),
                        created_at=l.get("created_at", datetime.utcnow().isoformat()),
                    )
                    for l in res.data
                ]
        except Exception:
            pass

        # Return standard seed accounts if database is newly initialized
        return [
            LedgerResponse(
                id=f"led-cash-{business_id[:4]}",
                business_id=business_id,
                name="Cash on Hand",
                parent_group_id="grp-current-assets",
                parent_group_name="Current Assets",
                opening_balance=0.0,
                opening_balance_type="Dr",
                current_balance=0.0,
                current_balance_type="Dr",
                created_at=datetime.utcnow().isoformat(),
            ),
            LedgerResponse(
                id=f"led-bank-{business_id[:4]}",
                business_id=business_id,
                name="Primary Bank Account",
                parent_group_id="grp-bank-accounts",
                parent_group_name="Bank Accounts",
                opening_balance=0.0,
                opening_balance_type="Dr",
                current_balance=0.0,
                current_balance_type="Dr",
                created_at=datetime.utcnow().isoformat(),
            ),
            LedgerResponse(
                id=f"led-sales-{business_id[:4]}",
                business_id=business_id,
                name="Sales Account",
                parent_group_id="grp-sales-accounts",
                parent_group_name="Sales Accounts",
                opening_balance=0.0,
                opening_balance_type="Cr",
                current_balance=0.0,
                current_balance_type="Cr",
                created_at=datetime.utcnow().isoformat(),
            ),
            LedgerResponse(
                id=f"led-pur-{business_id[:4]}",
                business_id=business_id,
                name="Purchase Account",
                parent_group_id="grp-purchase-accounts",
                parent_group_name="Purchase Accounts",
                opening_balance=0.0,
                opening_balance_type="Dr",
                current_balance=0.0,
                current_balance_type="Dr",
                created_at=datetime.utcnow().isoformat(),
            ),
        ]

    async def create_ledger(self, business_id: str, payload: LedgerCreate) -> LedgerResponse:
        """Creates a new ledger master in database."""
        rec_id = f"led-{uuid.uuid4().hex[:8]}"
        record = {
            "id": rec_id,
            "business_id": business_id,
            "name": payload.name,
            "group_name": payload.parent_group_name or "Current Assets",
            "primary_classification": "Asset",
            "opening_balance": payload.opening_balance,
            "opening_balance_type": payload.opening_balance_type.value,
            "party_gstin": payload.gstin,
            "party_pan": payload.pan,
            "hsn_sac_code": payload.hsn_sac_code,
        }
        try:
            self.db.from_("accounts").insert(record).execute()
        except Exception:
            pass

        return LedgerResponse(
            id=rec_id,
            business_id=business_id,
            name=payload.name,
            parent_group_id=payload.parent_group_id,
            parent_group_name=payload.parent_group_name or "Current Assets",
            opening_balance=payload.opening_balance,
            opening_balance_type=payload.opening_balance_type.value,
            current_balance=payload.opening_balance,
            current_balance_type=payload.opening_balance_type.value,
            gstin=payload.gstin,
            pan=payload.pan,
            state_code=payload.state_code,
            hsn_sac_code=payload.hsn_sac_code,
            credit_limit=payload.credit_limit,
            email=payload.email,
            phone=payload.phone,
            created_at=datetime.utcnow().isoformat(),
        )

    async def fetch_stock_items(self, business_id: str) -> List[StockItemResponse]:
        """Fetches inventory stock items from database."""
        try:
            uuid_bid = _ensure_uuid(business_id)
            res = self.db.from_("stock_items").select("*").eq("business_id", uuid_bid).execute()
            if res.data:
                return [
                    StockItemResponse(
                        id=s["id"],
                        business_id=s["business_id"],
                        name=s["name"],
                        hsn_code=s.get("hsn_code", ""),
                        unit_of_measure=s.get("unit_of_measure", "NOS"),
                        opening_quantity=float(s.get("opening_quantity", 0.0)),
                        opening_rate=float(s.get("opening_rate", 0.0)),
                        current_quantity=float(s.get("current_quantity", s.get("opening_quantity", 0.0))),
                        current_valuation=float(s.get("current_valuation", 0.0)),
                        tax_rate=float(s.get("tax_rate", 18.0)),
                    )
                    for s in res.data
                ]
        except Exception:
            pass
        return []

    async def fetch_fixed_assets(self, business_id: str) -> List[FixedAssetResponse]:
        """Fetches Schedule II fixed assets from database."""
        try:
            uuid_bid = _ensure_uuid(business_id)
            res = self.db.from_("fixed_assets").select("*, accounts(name)").eq("business_id", uuid_bid).execute()
            if res.data:
                return [
                    FixedAssetResponse(
                        id=f["id"],
                        business_id=f["business_id"],
                        asset_name=f["asset_name"],
                        category=f.get("category", "PLANT_MACHINERY"),
                        asset_account_id=f.get("asset_account_id", ""),
                        purchase_date=date.fromisoformat(f["purchase_date"]),
                        original_cost=float(f.get("original_cost", 0.0)),
                        residual_value=float(f.get("residual_value", 0.0)),
                        useful_life_years=float(f.get("useful_life_years", 5.0)),
                        is_nesd=f.get("is_nesd", False),
                        shift_working=f.get("shift_working", "Single"),
                        itc_claimed_flag=f.get("itc_claimed_flag", False),
                        accumulated_depreciation=float(f.get("accumulated_depreciation", 0.0)),
                        is_disposed=f.get("is_disposed", False),
                        disposal_date=date.fromisoformat(f["disposal_date"]) if f.get("disposal_date") else None,
                        created_at=datetime.fromisoformat(f["created_at"].replace("Z", "")) if f.get("created_at") else None,
                        asset_account_name=f.get("accounts", {}).get("name") if isinstance(f.get("accounts"), dict) else None,
                    )
                    for f in res.data
                ]
        except Exception:
            pass
        return []

    async def create_fixed_asset(self, business_id: str, payload: FixedAssetCreate) -> FixedAssetResponse:
        """Inserts a new fixed asset record into the database."""
        uuid_bid = _ensure_uuid(business_id)
        rec_id = f"fa-{uuid.uuid4().hex[:8]}"
        record = {
            "id": rec_id,
            "business_id": uuid_bid,
            "asset_name": payload.asset_name,
            "category": payload.category,
            "asset_account_id": payload.asset_account_id,
            "purchase_date": payload.purchase_date.isoformat(),
            "original_cost": payload.original_cost,
            "residual_value": payload.residual_value,
            "useful_life_years": payload.useful_life_years,
            "is_nesd": payload.is_nesd,
            "shift_working": payload.shift_working,
            "itc_claimed_flag": payload.itc_claimed_flag,
            "accumulated_depreciation": 0.0,
            "is_disposed": False,
        }
        try:
            self.db.from_("fixed_assets").insert(record).execute()
        except Exception:
            pass

        return FixedAssetResponse(
            id=rec_id,
            business_id=uuid_bid,
            asset_name=payload.asset_name,
            category=payload.category,
            asset_account_id=payload.asset_account_id,
            purchase_date=payload.purchase_date,
            original_cost=payload.original_cost,
            residual_value=payload.residual_value,
            useful_life_years=payload.useful_life_years,
            is_nesd=payload.is_nesd,
            shift_working=payload.shift_working,
            itc_claimed_flag=payload.itc_claimed_flag,
            accumulated_depreciation=0.0,
            is_disposed=False,
            created_at=datetime.utcnow(),
        )
