from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class DpdpPurposeCode(str, Enum):
    PURPOSE_DOUBLE_ENTRY = "PURPOSE_DOUBLE_ENTRY"
    PURPOSE_DOCUMENT_OCR = "PURPOSE_DOCUMENT_OCR"
    PURPOSE_VOICE_COMMAND = "PURPOSE_VOICE_COMMAND"
    PURPOSE_STATUTORY_E_INVOICE = "PURPOSE_STATUTORY_E_INVOICE"
    PURPOSE_BANKING_RECONCILIATION = "PURPOSE_BANKING_RECONCILIATION"


class DpdpConsentToggleRequest(BaseModel):
    purpose_code: DpdpPurposeCode
    is_granted: bool


class DpdpConsentStateResponse(BaseModel):
    purpose_code: DpdpPurposeCode
    title_english: str
    is_granted: bool
    last_updated_at: datetime


class DpdpConsentLogResponse(BaseModel):
    id: str
    purpose_code: str
    consent_status: str  # 'GRANTED', 'REVOKED'
    granted_at: datetime
    consent_payload_hash: str  # SHA-256 hash


class DsrPortabilityPackageResponse(BaseModel):
    export_id: str
    business_id: str
    total_vouchers: int
    total_accounts: int
    generated_at: datetime
    integrity_checksum_sha256: str
    download_url: str


class DsrErasureRequest(BaseModel):
    reason: str = "Account closure and data principal erasure request"


class DsrErasureResponse(BaseModel):
    status: str = "COMPLETED"
    pseudonymized_ledgers_count: int
    archived_vouchers_count: int
    statutory_retention_until: str  # 8 years under Section 128
    message: str


class SubscriptionTier(str, Enum):
    FREE = "FREE"
    PRO = "PRO"
    ENTERPRISE = "ENTERPRISE"


class SubscriptionStatus(str, Enum):
    ACTIVE = "ACTIVE"
    IN_GRACE_PERIOD = "IN_GRACE_PERIOD"
    ON_HOLD = "ON_HOLD"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class PlayPurchaseVerifyRequest(BaseModel):
    purchase_token: str
    product_id: str  # 'ledgify_pro_monthly', 'ledgify_pro_annual', etc.
    order_id: Optional[str] = None
    package_name: str = "com.asiverticals.ledgify"


class SubscriptionStatusResponse(BaseModel):
    user_id: str
    business_id: str
    tier: SubscriptionTier = SubscriptionTier.PRO
    status: SubscriptionStatus = SubscriptionStatus.ACTIVE
    is_pro_or_enterprise: bool = True
    expiry_date: datetime
    auto_renewing: bool = True
    grace_period_until: Optional[datetime] = None


class PlayRtdnWebhookPayload(BaseModel):
    version: str = "1.0"
    package_name: str = "com.asiverticals.ledgify"
    event_time_millis: str
    subscription_notification: Optional[dict] = None
    test_notification: Optional[dict] = None
