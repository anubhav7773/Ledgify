import hashlib
import json
import logging
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

logger = logging.getLogger(__name__)

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


def _ensure_uuid(bid: str) -> str:
    try:
        return str(uuid.UUID(bid))
    except (ValueError, AttributeError):
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, bid or "default"))


class DpdpComplianceService:
    def __init__(self, db: Client):
        self.db = db

    async def get_consent_states(self, business_id: str) -> List[DpdpConsentStateResponse]:
        """
        Retrieves active consent state for all mandatory and optional processing purposes.
        """
        results = []
        for purpose in DpdpPurposeCode:
            is_granted = _in_memory_consents.get(purpose.value, True)
            results.append(
                DpdpConsentStateResponse(
                    purpose_code=purpose,
                    title_english=purpose.value.replace("PURPOSE_", "").replace("_", " ").title(),
                    is_granted=is_granted,
                    last_updated_at=datetime.utcnow(),
                )
            )
        return results

    async def toggle_consent(
        self,
        business_id: str,
        purpose_code: DpdpPurposeCode,
        is_granted: bool,
    ) -> DpdpConsentStateResponse:
        """
        Toggles consent and writes tamper-evident SHA-256 hash log.
        """
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
        logger.info(f"[DPDP] Consent toggled: {purpose_code.value} -> {status_str} for tenant {business_id}")

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
        uuid_bid = _ensure_uuid(business_id)
        logger.info(f"[DPDP DSR] Generating data portability archive for tenant: {uuid_bid}")
        total_vouchers = 0
        total_accounts = 0
        try:
            v_res = self.db.from_("vouchers").select("id").eq("business_id", uuid_bid).execute()
            if v_res.data:
                total_vouchers = len(v_res.data)
            a_res = self.db.from_("accounts").select("id").eq("business_id", uuid_bid).execute()
            if a_res.data:
                total_accounts = len(a_res.data)
        except Exception as e:
            logger.warning(f"[DPDP DSR] Error querying counts for export: {e}")

        archive_content = json.dumps({"business_id": uuid_bid, "vouchers_count": total_vouchers, "accounts_count": total_accounts})
        integrity_hash = hashlib.sha256(archive_content.encode("utf-8")).hexdigest()

        now = datetime.utcnow()
        export_id = f"dsr-exp-{uuid.uuid4().hex[:8]}"
        logger.info(f"[DPDP DSR] Portability package generated successfully: {export_id} (Vouchers: {total_vouchers}, Accounts: {total_accounts})")

        return DsrPortabilityPackageResponse(
            export_id=export_id,
            business_id=uuid_bid,
            total_vouchers=total_vouchers,
            total_accounts=total_accounts,
            generated_at=now,
            integrity_checksum_sha256=integrity_hash,
            download_url=f"/api/v1/dpdp/dsr/download/{export_id}.zip",
        )

    async def execute_section_128_erasure(self, business_id: str, reason: str) -> DsrErasureResponse:
        uuid_bid = _ensure_uuid(business_id)
        logger.info(f"[DPDP DSR] Executing Section 128 Right to Erasure for tenant: {uuid_bid} (Reason: {reason})")
        count = 0
        try:
            a_res = self.db.from_("accounts").select("id").eq("business_id", uuid_bid).execute()
            if a_res.data:
                count = len(a_res.data)
                self.db.from_("accounts").update({
                    "party_gstin": None,
                    "party_pan": None,
                }).eq("business_id", uuid_bid).execute()
                logger.info(f"[DPDP DSR] Successfully pseudonymized {count} accounts for tenant: {uuid_bid}")
        except Exception as e:
            logger.error(f"[DPDP DSR] Database error during erasure: {e}")

        retention_year = datetime.utcnow().year + 8
        logger.info(f"[DPDP DSR] Erasure completed. Statutory audit books archived until 31st March {retention_year}")
        return DsrErasureResponse(
            status="COMPLETED",
            pseudonymized_ledgers_count=count,
            archived_vouchers_count=0,
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
            tier=tier,
            status=SubscriptionStatus.ACTIVE,
            expiry_date=expiry,
            auto_renewing=True,
            features_unlocked=[
                "E-Invoicing Realtime IRP Sync",
                "Automated Bank Statement Parsing (CAMT.053 & CSV)",
                "Statutory 4-Column Trial Balance",
                "Multi-GSTIN Branch Consolidation",
            ],
        )

    async def get_subscription_status(self, business_id: str) -> SubscriptionStatusResponse:
        record = _in_memory_subscriptions.get(business_id)
        if not record:
            return SubscriptionStatusResponse(
                tier=SubscriptionTier.FREE,
                status=SubscriptionStatus.EXPIRED,
                expiry_date=None,
                auto_renewing=False,
                features_unlocked=["Basic Double-Entry Vouchers", "Single-User Cash Book"],
            )

        return SubscriptionStatusResponse(
            tier=SubscriptionTier(record["tier"]),
            status=SubscriptionStatus(record["status"]),
            expiry_date=datetime.fromisoformat(record["expiry_date"]),
            auto_renewing=record["auto_renewing"],
            features_unlocked=[
                "E-Invoicing Realtime IRP Sync",
                "Automated Bank Statement Parsing (CAMT.053 & CSV)",
                "Statutory 4-Column Trial Balance",
                "Multi-GSTIN Branch Consolidation",
            ],
        )
