from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class InvoiceLineItemExtracted(BaseModel):
    description: str
    hsn_code: Optional[str] = None
    quantity: float = 1.0
    unit: str = "NOS"
    rate: float = 0.0
    tax_rate: float = 18.0
    tax_amount: float = 0.0
    total_amount: float


class VendorDetailsExtracted(BaseModel):
    name: str
    trade_name: Optional[str] = None
    gstin: Optional[str] = None
    pan: Optional[str] = None
    address: Optional[str] = None
    state_code: Optional[str] = None


class InvoiceOcrResult(BaseModel):
    invoice_number: str
    invoice_date: date = Field(default_factory=date.today)
    due_date: Optional[date] = None
    vendor: VendorDetailsExtracted
    line_items: List[InvoiceLineItemExtracted] = []
    subtotal: float
    cgst_amount: float = 0.0
    sgst_amount: float = 0.0
    igst_amount: float = 0.0
    total_tax: float
    total_amount: float
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    inferred_voucher_type: str = "Purchase"
    raw_text: Optional[str] = None


class VoiceVoucherResult(BaseModel):
    transcript: str
    inferred_voucher_type: str = "Payment"
    debit_ledger_name: str
    credit_ledger_name: str
    amount: float
    narration: str
    confidence_score: float = Field(..., ge=0.0, le=1.0)


class AiDraftModel(BaseModel):
    id: str
    business_id: str
    document_type: str  # 'RECEIPT_OCR', 'VOICE_VOUCHER', 'E_INVOICE_JSON'
    source_filename: Optional[str] = None
    parsed_payload: dict
    confidence_score: float
    status: str = "PENDING_REVIEW"  # 'PENDING_REVIEW', 'APPROVED', 'DISMISSED'
    created_at: datetime = Field(default_factory=datetime.utcnow)


class FuzzyMatchRequest(BaseModel):
    query_text: str
    candidate_ledgers: Optional[List[str]] = None
    threshold: float = 65.0


class FuzzyMatchCandidate(BaseModel):
    ledger_id: str
    ledger_name: str
    similarity_score: float  # 0 to 100
    is_exact_match: bool = False


class FuzzyMatchResponse(BaseModel):
    query: str
    best_match: Optional[FuzzyMatchCandidate] = None
    candidates: List[FuzzyMatchCandidate] = []
