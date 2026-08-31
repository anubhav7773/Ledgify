from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from supabase import Client
from app.api.deps import get_current_business_id, get_db
from app.schemas.common import ApiResponse
from app.schemas.gst import (
    EInvoiceGenerateRequest,
    EInvoiceResponse,
    EWayBillCreateRequest,
    EWayBillPartBUpdateRequest,
    EWayBillResponse,
    GstRegistrationResponse,
    Gstr1SummaryResponse,
    Gstr3bSummaryResponse,
    ImsActionUpdateRequest,
    ImsInwardSupplyItem,
)
from app.services.gst_service import GstComplianceService

router = APIRouter()


@router.get("/registrations", response_model=ApiResponse[List[GstRegistrationResponse]])
async def list_gst_registrations(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Lists all state-wise GSTIN registrations for the current business entity.
    """
    service = GstComplianceService(db)
    result = await service.get_registrations(business_id)
    return ApiResponse(success=True, data=result)


@router.get("/gstr1-summary", response_model=ApiResponse[Gstr1SummaryResponse])
async def get_gstr1_summary(
    return_period: str = Query("082026", description="MMYYYY format"),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns statutory GSTR-1 Outward Supply Summary (Tables 4, 5, 7, 12).
    """
    service = GstComplianceService(db)
    result = await service.calculate_gstr1_summary(business_id, return_period)
    return ApiResponse(success=True, data=result)


@router.get("/gstr3b-summary", response_model=ApiResponse[Gstr3bSummaryResponse])
async def get_gstr3b_summary(
    return_period: str = Query("082026", description="MMYYYY format"),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Returns statutory GSTR-3B Summary with Section 49 Electronic Credit Ledger Net Cash Offset.
    """
    service = GstComplianceService(db)
    result = await service.calculate_gstr3b_summary(business_id, return_period)
    return ApiResponse(success=True, data=result)


@router.get("/ims-portal", response_model=ApiResponse[List[ImsInwardSupplyItem]])
async def get_ims_inward_supplies(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves the Invoice Management System (IMS) inward supply register for ITC verification.
    """
    service = GstComplianceService(db)
    result = await service.fetch_ims_supplies(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/ims-portal/action", response_model=ApiResponse[dict])
async def update_ims_invoice_action(
    payload: ImsActionUpdateRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Updates the IMS action status (ACCEPTED / REJECTED / PENDING) for an inward supply invoice.
    """
    service = GstComplianceService(db)
    await service.update_ims_action(business_id, payload.invoice_id, payload.action_status)
    return ApiResponse(success=True, data={"message": f"Invoice {payload.invoice_id} status updated to {payload.action_status.value}."})


@router.post("/einvoice/generate", response_model=ApiResponse[EInvoiceResponse], status_code=status.HTTP_201_CREATED)
async def generate_statutory_einvoice(
    payload: EInvoiceGenerateRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Generates 64-character SHA-256 statutory IRN hash and Signed 2D QR Code data.
    """
    service = GstComplianceService(db)
    result = await service.generate_einvoice(business_id, payload.voucher_id)
    return ApiResponse(success=True, data=result)


@router.get("/eway-bills", response_model=ApiResponse[List[EWayBillResponse]])
async def list_eway_bills(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Lists active, expiring, and historic E-Way Bills with real-time countdown tracking.
    """
    service = GstComplianceService(db)
    result = await service.fetch_eway_bills(business_id)
    return ApiResponse(success=True, data=result)


@router.post("/eway-bills", response_model=ApiResponse[EWayBillResponse], status_code=status.HTTP_201_CREATED)
async def generate_eway_bill(
    payload: EWayBillCreateRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Generates statutory FORM GST EWB-01 applying Rule 138(10) distance validity calculations.
    """
    service = GstComplianceService(db)
    result = await service.generate_eway_bill(business_id, payload)
    return ApiResponse(success=True, data=result)


@router.post("/eway-bills/{ewb_id}/update-part-b", response_model=ApiResponse[dict])
async def update_eway_bill_part_b(
    ewb_id: str,
    payload: EWayBillPartBUpdateRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Updates Part B road vehicle registration number for an active transit movement.
    """
    service = GstComplianceService(db)
    await service.update_ewb_part_b(business_id, ewb_id, payload.new_vehicle_number, payload.reason)
    return ApiResponse(success=True, data={"message": f"E-Way Bill {ewb_id} Part B updated with vehicle {payload.new_vehicle_number}."})
