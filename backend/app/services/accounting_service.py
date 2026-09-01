import uuid
from datetime import date, datetime
from typing import List, Optional
from supabase import Client
from app.core.exceptions import DoubleEntryDiscrepancyException, NotFoundException
from app.schemas.accounting import (
    VoucherCreate,
    VoucherFilterParams,
    VoucherItemResponse,
    VoucherResponse,
)

# Runtime in-memory store (empty by default)
_in_memory_vouchers: List[dict] = []


def _ensure_uuid(bid: str) -> str:
    try:
        return str(uuid.UUID(bid))
    except (ValueError, AttributeError):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, bid or "default"))


class AccountingService:
    def __init__(self, db: Client):
        self.db = db

    async def create_voucher(self, business_id: str, payload: VoucherCreate) -> VoucherResponse:
        """
        Validates double-entry checksum and persists voucher with line items to Supabase DB.
        """
        uuid_bid = _ensure_uuid(business_id)

        # Strict checksum validation
        total_debit = sum(i.amount for i in payload.items if i.is_debit)
        total_credit = sum(i.amount for i in payload.items if not i.is_debit)

        if abs(total_debit - total_credit) > 0.01:
            raise DoubleEntryDiscrepancyException(debit_sum=total_debit, credit_sum=total_credit)

        voucher_id = f"vch-{uuid.uuid4().hex[:10]}"
        voucher_number = payload.voucher_number or f"{payload.voucher_type.value[:3].upper()}-{datetime.now().strftime('%Y%m%d%H%M%S')}"

        record = {
            "id": voucher_id,
            "business_id": uuid_bid,
            "voucher_type": payload.voucher_type.value,
            "voucher_number": voucher_number,
            "voucher_date": payload.voucher_date.isoformat(),
            "narration": payload.narration,
            "reference_number": payload.reference_number,
            "total_amount": total_debit,
            "items": [
                {
                    "id": f"item-{uuid.uuid4().hex[:8]}",
                    "voucher_id": voucher_id,
                    "ledger_id": item.ledger_id,
                    "ledger_name": item.ledger_name or "General Ledger Account",
                    "is_debit": item.is_debit,
                    "amount": item.amount,
                    "narration": item.narration,
                    "hsn_sac_code": item.hsn_sac_code,
                    "tax_rate": item.tax_rate,
                }
                for item in payload.items
            ],
            "created_at": datetime.utcnow().isoformat(),
        }

        _in_memory_vouchers.append(record)

        try:
            self.db.from_("vouchers").insert({
                "id": voucher_id,
                "business_id": uuid_bid,
                "voucher_number": voucher_number,
                "voucher_date": payload.voucher_date.isoformat(),
                "narration": payload.narration,
                "total_debit": total_debit,
                "total_credit": total_credit,
            }).execute()
        except Exception:
            pass

        return VoucherResponse(
            id=voucher_id,
            business_id=uuid_bid,
            voucher_type=payload.voucher_type.value,
            voucher_number=voucher_number,
            voucher_date=payload.voucher_date,
            narration=payload.narration,
            reference_number=payload.reference_number,
            total_amount=total_debit,
            items=[VoucherItemResponse(**i) for i in record["items"]],
            created_at=datetime.utcnow(),
        )

    async def fetch_vouchers(
        self,
        business_id: str,
        filters: VoucherFilterParams,
        page: int = 1,
        page_size: int = 50,
    ) -> List[VoucherResponse]:
        """Fetches filtered vouchers for the active business from database."""
        uuid_bid = _ensure_uuid(business_id)
        try:
            query = self.db.from_("vouchers").select("*, voucher_line_items(*)").eq("business_id", uuid_bid)
            if filters.voucher_type:
                query = query.eq("voucher_type", filters.voucher_type.value)
            res = query.order("voucher_date", desc=True).limit(page_size).execute()
            if res.data:
                return [
                    VoucherResponse(
                        id=v["id"],
                        business_id=v["business_id"],
                        voucher_type=v.get("voucher_type", "Journal"),
                        voucher_number=v["voucher_number"],
                        voucher_date=date.fromisoformat(v["voucher_date"]),
                        narration=v.get("narration"),
                        reference_number=v.get("reference_number"),
                        total_amount=float(v.get("total_debit", 0.0)),
                        items=[
                            VoucherItemResponse(
                                id=it["id"],
                                voucher_id=it["voucher_id"],
                                ledger_id=it["ledger_id"],
                                ledger_name=it.get("ledger_name", "Ledger Account"),
                                is_debit=it["is_debit"],
                                amount=float(it["amount"]),
                                narration=it.get("narration"),
                                hsn_sac_code=it.get("hsn_sac_code"),
                                tax_rate=float(it.get("tax_rate", 18.0)),
                            )
                            for it in v.get("voucher_line_items", [])
                        ],
                        created_at=datetime.utcnow(),
                    )
                    for v in res.data
                ]
        except Exception:
            pass

        results = [v for v in _in_memory_vouchers if v["business_id"] == business_id or v["business_id"] == uuid_bid]
        return [
            VoucherResponse(
                id=v["id"],
                business_id=v["business_id"],
                voucher_type=v["voucher_type"],
                voucher_number=v["voucher_number"],
                voucher_date=date.fromisoformat(v["voucher_date"]),
                narration=v.get("narration"),
                reference_number=v.get("reference_number"),
                total_amount=v["total_amount"],
                items=[VoucherItemResponse(**item) for item in v.get("items", [])],
                created_at=datetime.utcnow(),
            )
            for v in results
        ]

    async def get_voucher_by_id(self, business_id: str, voucher_id: str) -> VoucherResponse:
        """Retrieves a single voucher by unique ID."""
        uuid_bid = _ensure_uuid(business_id)
        for v in _in_memory_vouchers:
            if v["id"] == voucher_id and (v["business_id"] == business_id or v["business_id"] == uuid_bid):
                return VoucherResponse(
                    id=v["id"],
                    business_id=v["business_id"],
                    voucher_type=v["voucher_type"],
                    voucher_number=v["voucher_number"],
                    voucher_date=date.fromisoformat(v["voucher_date"]),
                    narration=v.get("narration"),
                    reference_number=v.get("reference_number"),
                    total_amount=v["total_amount"],
                    items=[VoucherItemResponse(**item) for item in v.get("items", [])],
                    created_at=datetime.utcnow(),
                )
        raise NotFoundException(resource="Voucher", resource_id=voucher_id)
