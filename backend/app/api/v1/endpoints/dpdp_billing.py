from typing import List
from fastapi import APIRouter, Depends, status
from supabase import Client
from app.api.deps import get_current_business_id, get_current_user, get_db
from app.schemas.auth import UserContext
from app.schemas.common import ApiResponse
from app.schemas.dpdp_billing import (
    DpdpConsentLogResponse,
    DpdpConsentStateResponse,
    DpdpConsentToggleRequest,
    DsrErasureRequest,
    DsrErasureResponse,
    DsrPortabilityPackageResponse,
    PlayPurchaseVerifyRequest,
    PlayRtdnWebhookPayload,
    SubscriptionStatusResponse,
)
from app.services.dpdp_billing_service import DpdpComplianceService, GooglePlayBillingService

router = APIRouter()


# --- DPDP Act 2023 Endpoints ---

@router.get("/dpdp/consents", response_model=ApiResponse[List[DpdpConsentStateResponse]], tags=["DPDP Privacy & Data Rights"])
async def list_dpdp_consents(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Lists active consent statuses for all statutory data processing purposes under DPDP Act 2023.
    """
    service = DpdpComplianceService(db)
    result = await service.get_consent_states(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/dpdp/consents/toggle", response_model=ApiResponse[DpdpConsentStateResponse], tags=["DPDP Privacy & Data Rights"])
async def toggle_dpdp_consent(
    payload: DpdpConsentToggleRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Grants or revokes consent for a data processing purpose and appends to the immutable SHA-256 audit trail.
    """
    service = DpdpComplianceService(db)
    result = await service.toggle_consent(business_id, payload.purpose_code, payload.is_granted)
    return ApiResponse(success=True, data=result)


@router.get("/dpdp/consents/audit-log", response_model=ApiResponse[List[DpdpConsentLogResponse]], tags=["DPDP Privacy & Data Rights"])
async def get_consent_audit_log(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves the tamper-proof cryptographic SHA-256 consent action audit trail.
    """
    service = DpdpComplianceService(db)
    result = await service.get_consent_audit_history(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/dpdp/dsr/export-portability", response_model=ApiResponse[DsrPortabilityPackageResponse], tags=["DPDP Privacy & Data Rights"])
async def export_data_portability(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Exports all tenant accounting ledgers, vouchers, and audit logs in structured JSON/ZIP archive.
    """
    service = DpdpComplianceService(db)
    result = await service.export_data_portability(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/dpdp/dsr/erasure", response_model=ApiResponse[DsrErasureResponse], tags=["DPDP Privacy & Data Rights"])
async def request_account_erasure(
    payload: DsrErasureRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Executes Right to Erasure / Pseudonymization while complying with Companies Act Section 128 (8-year audit retention).
    """
    service = DpdpComplianceService(db)
    result = await service.execute_section_128_erasure(business_id, payload.reason)
    return ApiResponse(success=True, data=result)


# --- Google Play Billing Endpoints ---

@router.post("/billing/verify-purchase", response_model=ApiResponse[SubscriptionStatusResponse], tags=["Monetization & Google Play Billing"])
async def verify_play_purchase(
    payload: PlayPurchaseVerifyRequest,
    user: UserContext = Depends(get_current_user),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Verifies Google Play In-App Purchase token and unlocks Pro / Enterprise tier features.
    """
    service = GooglePlayBillingService(db)
    result = await service.verify_purchase(user.user_id, business_id, payload)
    return ApiResponse(success=True, data=result)


@router.get("/billing/subscription-status", response_model=ApiResponse[SubscriptionStatusResponse], tags=["Monetization & Google Play Billing"])
async def get_subscription_status(
    user: UserContext = Depends(get_current_user),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns current active subscription tier (Free / Pro / Enterprise) and renewal dates.
    """
    service = GooglePlayBillingService(db)
    result = await service.get_subscription_status(user.user_id, business_id)
    return ApiResponse(success=True, data=result)


@router.post("/billing/google-play-rtdn", response_model=ApiResponse[dict], tags=["Monetization & Google Play Billing"])
async def receive_play_rtdn_notification(
    payload: PlayRtdnWebhookPayload,
    db: Client = Depends(get_db),
):
    """
    Real-Time Developer Notification (RTDN) webhook from Google Cloud Pub/Sub for automated renewal and cancellation sync.
    """
    service = GooglePlayBillingService(db)
    await service.handle_rtdn_event(payload.model_dump())
    return ApiResponse(success=True, data={"status": "RTDN event processed"})
