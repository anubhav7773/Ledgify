import hashlib
import json
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from supabase import Client
from app.core.exceptions import NotFoundException
from app.schemas.dpdp_billing import (
    DpdpConsentLogResponse,
    DpdpConsentStateResponse,
    DpdpPurposeCode,
    DsrErasureResponse,
    DsrPortabilityPackageResponse,
    PlayPurchaseVerifyRequest,
    SubscriptionStatus,
    SubscriptionStatusResponse,
    SubscriptionTier,
)
from app.services.accounting_service import _in_memory_vouchers
from app.services.masters_service import _in_memory_ledgers

# In-memory DPDP state store
_in_memory_consents: Dict[str, bool] = {
    DpdpPurposeCode.PURPOSE_DOUBLE_ENTRY.value: True,
    DpdpPurposeCode.PURPOSE_DOCUMENT_OCR.value: True,
    DpdpPurposeCode.PURPOSE_VOICE_COMMAND.value: True,
    DpdpPurposeCode.PURPOSE_STATUTORY_E_INVOICE.value: True,
    DpdpPurposeCode.PURPOSE_BANKING_RECONCILIATION.value: True,
}

_in_memory_consent_logs: List[dict] = [
    {
        "id": "log-001",
        "purpose_code": DpdpPurposeCode.PURPOSE_DOUBLE_ENTRY.value,
        "consent_status": "GRANTED",
        "granted_at": "2026-08-01T10:00:00Z",
        "consent_payload_hash": hashlib.sha256(b"CONSENT_INITIAL_GRANTED_DOUBLE_ENTRY").hexdigest(),
    }
]

_in_memory_subscriptions: Dict[str, dict] = {
    "BIZ-DEFAULT-01": {
        "user_id": "dev-user-mock-uuid-001",
        "business_id": "BIZ-DEFAULT-01",
        "tier": SubscriptionTier.PRO.value,
        "status": SubscriptionStatus.ACTIVE.value,
        "expiry_date": (datetime.utcnow() + timedelta(days=365)).isoformat(),
        "auto_renewing": True,
        "grace_period_until": None,
    }
}


class DpdpComplianceService:
    def __init__(self, db: Client):
        self.db = db

    async def get_consent_states(self, business_id: str) -> List[DpdpConsentStateResponse]:
        titles = {
            DpdpPurposeCode.PURPOSE_DOUBLE_ENTRY: "Core Double-Entry Ledger Maintenance",
            DpdpPurposeCode.PURPOSE_DOCUMENT_OCR: "AI Bill Scanner & Document Parsing",
            DpdpPurposeCode.PURPOSE_VOICE_COMMAND: "Voice Voucher Audio Comprehension",
            DpdpPurposeCode.PURPOSE_STATUTORY_E_INVOICE: "NIC E-Invoice & E-Way Bill Auto-Registration",
            DpdpPurposeCode.PURPOSE_BANKING_RECONCILIATION: "Bank Statement Transaction Ingestion & BRS",
        }

        now = datetime.utcnow()
        return [
            DpdpConsentStateResponse(
                purpose_code=purpose,
                title_english=titles.get(purpose, purpose.value),
                is_granted=_in_memory_consents.get(purpose.value, False),
                last_updated_at=now,
            )
            for purpose in DpdpPurposeCode
        ]

    async def toggle_consent(self, business_id: str, purpose_code: DpdpPurposeCode, is_granted: bool) -> DpdpConsentStateResponse:
        _in_memory_consents[purpose_code.value] = is_granted

        # Compute immutable SHA-256 hash
        now = datetime.utcnow()
        status_str = "GRANTED" if is_granted else "REVOKED"
        payload_raw = f"{business_id}|{purpose_code.value}|{status_str}|{now.isoformat()}"
        sha_hash = hashlib.sha256(payload_raw.encode("utf-8")).hexdigest()

        log_record = {
            "id": f"log-{uuid.uuid4().hex[:8]}",
            "purpose_code": purpose_code.value,
            "consent_status": status_str,
            "granted_at": now.isoformat(),
            "consent_payload_hash": sha_hash,
        }
        _in_memory_consent_logs.insert(0, log_record)

        return DpdpConsentStateResponse(
            purpose_code=purpose_code,
            title_english=purpose_code.value.replace("PURPOSE_", "").replace("_", " ").title(),
            is_granted=is_granted,
            last_updated_at=now,
        )

    async def get_consent_audit_history(self, business_id: str) -> List[DpdpConsentLogResponse]:
        return [
            DpdpConsentLogResponse(
                id=log["id"],
                purpose_code=log["purpose_code"],
                consent_status=log["consent_status"],
                granted_at=datetime.fromisoformat(log["granted_at"].replace("Z", "")),
                consent_payload_hash=log["consent_payload_hash"],
            )
            for log in _in_memory_consent_logs
        ]

    async def export_data_portability(self, business_id: str) -> DsrPortabilityPackageResponse:
        vouchers = [v for v in _in_memory_vouchers if v["business_id"] == business_id]
        accounts = [l for l in _in_memory_ledgers if l["business_id"] == business_id]

        archive_content = json.dumps({"vouchers": vouchers, "accounts": accounts})
        integrity_hash = hashlib.sha256(archive_content.encode("utf-8")).hexdigest()

        now = datetime.utcnow()
        export_id = f"dsr-exp-{uuid.uuid4().hex[:8]}"

        return DsrPortabilityPackageResponse(
            export_id=export_id,
            business_id=business_id,
            total_vouchers=len(vouchers),
            total_accounts=len(accounts),
            generated_at=now,
            integrity_checksum_sha256=integrity_hash,
            download_url=f"/api/v1/dpdp/dsr/download/{export_id}.zip",
        )

    async def execute_section_128_erasure(self, business_id: str, reason: str) -> DsrErasureResponse:
        # Pseudonymize party ledger names while preserving amounts for 8-year statutory audit
        ledgers = [l for l in _in_memory_ledgers if l["business_id"] == business_id]
        for l in ledgers:
            if "Debtors" in l.get("parent_group_name", "") or "Creditors" in l.get("parent_group_name", ""):
                l["name"] = f"Pseudonymized Party #{l['id'][-4:]}"
                l["gstin"] = None
                l["pan"] = None
                l["email"] = None
                l["phone"] = None

        retention_year = datetime.utcnow().year + 8
        return DsrErasureResponse(
            status="COMPLETED",
            pseudonymized_ledgers_count=len(ledgers),
            archived_vouchers_count=len(_in_memory_vouchers),
            statutory_retention_until=f"31st March {retention_year} (Companies Act Section 128)",
            message="Data principal personally identifiable information pseudonymized. Statutory books archived for 8-year mandatory audit retention.",
        )


class GooglePlayBillingService:
    def __init__(self, db: Client):
        self.db = db

    async def verify_purchase(
        self,
        user_id: str,
        business_id: str,
        payload: PlayPurchaseVerifyRequest,
    ) -> SubscriptionStatusResponse:
        tier = SubscriptionTier.PRO
        if "enterprise" in payload.product_id.lower():
            tier = SubscriptionTier.ENTERPRISE

        expiry = datetime.utcnow() + timedelta(days=365)

        sub_record = {
            "user_id": user_id,
            "business_id": business_id,
            "tier": tier.value,
            "status": SubscriptionStatus.ACTIVE.value,
            "expiry_date": expiry.isoformat(),
            "auto_renewing": True,
            "grace_period_until": None,
        }
        _in_memory_subscriptions[business_id] = sub_record

        return SubscriptionStatusResponse(
            user_id=user_id,
            business_id=business_id,
            tier=tier,
            status=SubscriptionStatus.ACTIVE,
            is_pro_or_enterprise=True,
            expiry_date=expiry,
            auto_renewing=True,
        )

    async def get_subscription_status(self, user_id: str, business_id: str) -> SubscriptionStatusResponse:
        sub = _in_memory_subscriptions.get(business_id)
        if not sub:
            expiry = datetime.utcnow() + timedelta(days=365)
            return SubscriptionStatusResponse(
                user_id=user_id,
                business_id=business_id,
                tier=SubscriptionTier.PRO,
                status=SubscriptionStatus.ACTIVE,
                is_pro_or_enterprise=True,
                expiry_date=expiry,
                auto_renewing=True,
            )

        return SubscriptionStatusResponse(
            user_id=sub["user_id"],
            business_id=sub["business_id"],
            tier=SubscriptionTier(sub["tier"]),
            status=SubscriptionStatus(sub["status"]),
            is_pro_or_enterprise=sub["tier"] in [SubscriptionTier.PRO.value, SubscriptionTier.ENTERPRISE.value],
            expiry_date=datetime.fromisoformat(sub["expiry_date"].replace("Z", "")),
            auto_renewing=sub.get("auto_renewing", True),
        )

    async def handle_rtdn_event(self, event_payload: dict) -> bool:
        # Process Google Play developer event
        return True
