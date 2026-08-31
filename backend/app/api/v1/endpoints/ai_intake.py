from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from pydantic import BaseModel
from supabase import Client
from app.api.deps import get_current_business_id, get_db
from app.schemas.accounting import VoucherResponse
from app.schemas.ai_intake import (
    AiDraftModel,
    FuzzyMatchRequest,
    FuzzyMatchResponse,
    InvoiceOcrResult,
    VoiceVoucherResult,
)
from app.schemas.common import ApiResponse
from app.services.ai_service import GeminiAiService
from app.services.fuzzy_matching_service import FuzzyMatchingService

router = APIRouter()


class VoiceTextRequest(BaseModel):
    transcript_text: str


@router.post("/scan-receipt", response_model=ApiResponse[InvoiceOcrResult])
async def scan_receipt_invoice(
    file: UploadFile = File(...),
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Multimodal Invoice Receipt Scanner (Gemini 1.5 Pro):
    Extracts line items, vendor GSTIN, CGST/SGST/IGST tax breakdowns with confidence scoring.
    """
    file_bytes = await file.read()
    service = GeminiAiService(db)
    result = await service.parse_invoice_document(
        file_bytes=file_bytes,
        filename=file.filename or "receipt.jpg",
        mime_type=file.content_type or "image/jpeg",
        business_id=business_id,
    )
    return ApiResponse(success=True, data=result)


@router.post("/voice-voucher", response_model=ApiResponse[VoiceVoucherResult])
async def parse_voice_voucher(
    payload: VoiceTextRequest,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Voice-to-Voucher Comprehension:
    Converts transcribed voice commands into Debit/Credit double-entry line items.
    """
    service = GeminiAiService(db)
    result = await service.parse_voice_voucher(
        transcript_text=payload.transcript_text,
        business_id=business_id,
    )
    return ApiResponse(success=True, data=result)


@router.get("/drafts", response_model=ApiResponse[List[AiDraftModel]])
async def list_ai_drafts(
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Retrieves the queue of unverified AI drafts pending accountant review.
    """
    service = GeminiAiService(db)
    drafts = await service.fetch_drafts_queue(business_id)
    return ApiResponse(success=True, data=drafts)


@router.post("/drafts/{draft_id}/approve", response_model=ApiResponse[VoucherResponse])
async def approve_ai_draft(
    draft_id: str,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Approves and officially posts an AI draft into the double-entry accounting ledger.
    """
    service = GeminiAiService(db)
    voucher = await service.approve_draft(business_id, draft_id)
    return ApiResponse(success=True, data=voucher)


@router.delete("/drafts/{draft_id}", response_model=ApiResponse[dict])
async def dismiss_ai_draft(
    draft_id: str,
    business_id: str = Depends(get_current_business_id),
    db: Client = Depends(get_db),
):
    """
    Dismisses an unneeded or inaccurate AI draft.
    """
    service = GeminiAiService(db)
    await service.dismiss_draft(business_id, draft_id)
    return ApiResponse(success=True, data={"message": f"Draft {draft_id} dismissed successfully."})


@router.post("/fuzzy-match-ledger", response_model=ApiResponse[FuzzyMatchResponse])
async def match_vendor_entity(
    payload: FuzzyMatchRequest,
    business_id: str = Depends(get_current_business_id),
):
    """
    RapidFuzz & Trigram entity matcher mapping OCR vendor names to known ledger accounts.
    """
    result = FuzzyMatchingService.match_vendor_to_ledger(
        query=payload.query_text,
        business_id=business_id,
        threshold=payload.threshold,
    )
    return ApiResponse(success=True, data=result)
