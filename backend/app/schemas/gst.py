from datetime import date, datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class ImsActionStatus(str, Enum):
    PENDING = "PENDING"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"


class GstRegistrationResponse(BaseModel):
    id: str
    business_id: str
    gstin: str
    legal_name: str
    trade_name: Optional[str] = None
    state_code: str
    state_name: str
    filing_frequency: str = "MONTHLY"
    is_composition: bool = False
    is_active: bool = True


class Gstr1TableSummary(BaseModel):
    table_name: str  # 'Table 4 - B2B', 'Table 5 - B2CL', 'Table 7 - B2CS', 'Table 12 - HSN'
    invoice_count: int
    taxable_value: float
    igst_amount: float = 0.0
    cgst_amount: float = 0.0
    sgst_amount: float = 0.0
    cess_amount: float = 0.0
    total_tax: float


class Gstr1SummaryResponse(BaseModel):
    return_period: str  # e.g. '082026'
    filing_deadline: date
    tables: List[Gstr1TableSummary] = []
    total_outward_taxable_value: float
    total_outward_liability: float
    is_ready_for_filing: bool = True


class Gstr3bSummaryResponse(BaseModel):
    return_period: str
    filing_deadline: date
    outward_taxable_supplies: float
    outward_tax_liability: float
    eligible_itc_available: float
    ineligible_itc: float = 0.0
    section_49_net_cash_payable: float
    itc_utilized: float
    is_ready_for_offset: bool = True


class ImsInwardSupplyItem(BaseModel):
    id: str
    supplier_gstin: str
    supplier_name: str
    invoice_number: str
    invoice_date: date
    invoice_value: float
    taxable_value: float
    igst: float = 0.0
    cgst: float = 0.0
    sgst: float = 0.0
    action_status: ImsActionStatus = ImsActionStatus.PENDING
    itc_eligibility: bool = True


class ImsActionUpdateRequest(BaseModel):
    invoice_id: str
    action_status: ImsActionStatus


class EInvoiceGenerateRequest(BaseModel):
    voucher_id: str


class EInvoiceResponse(BaseModel):
    id: str
    voucher_id: str
    irn_hash: str = Field(..., min_length=64, max_length=64, description="64-character SHA-256 statutory IRN")
    ack_number: str
    ack_date: datetime
    signed_qr_code_data: str
    status: str = "GENERATED"
    taxable_amount: float
    total_tax: float
    total_invoice_value: float


class EWayBillCreateRequest(BaseModel):
    voucher_id: str
    distance_km: float = Field(..., gt=0, description="Road distance in KM")
    is_odc: bool = False  # Over Dimensional Cargo (20 km/day)
    is_under_10km_exempt: bool = False
    vehicle_number: Optional[str] = None
    transporter_id: Optional[str] = None
    transporter_name: Optional[str] = None


class EWayBillResponse(BaseModel):
    id: str
    business_id: str
    voucher_id: str
    ewb_number: str
    ewb_date: datetime
    valid_upto: datetime
    validity_days: int
    remaining_hours: int
    is_expired: bool
    distance_km: float
    vehicle_number: Optional[str] = None
    transporter_name: Optional[str] = None
    status: str = "ACTIVE"  # 'ACTIVE', 'CANCELLED', 'EXTENDED'


class EWayBillPartBUpdateRequest(BaseModel):
    new_vehicle_number: str = Field(..., min_length=4)
    reason: str = "Transshipment / Vehicle Break-down"
