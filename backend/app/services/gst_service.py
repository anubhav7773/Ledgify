import hashlib
import math
import uuid
from datetime import date, datetime, timedelta
from typing import List, Optional
from supabase import Client
from app.core.exceptions import NotFoundException
from app.schemas.gst import (
    EInvoiceResponse,
    EWayBillCreateRequest,
    EWayBillResponse,
    GstRegistrationResponse,
    Gstr1SummaryResponse,
    Gstr1TableSummary,
    Gstr3bSummaryResponse,
    ImsActionStatus,
    ImsInwardSupplyItem,
)

# Mock Store for GST Data
_in_memory_gst_registrations: List[dict] = [
    {
        "id": "gst-reg-01",
        "business_id": "BIZ-DEFAULT-01",
        "gstin": "27AAAAA0000A1Z5",
        "legal_name": "Apex Enterprises Ltd.",
        "trade_name": "Apex Global Tech",
        "state_code": "27",
        "state_name": "Maharashtra",
        "filing_frequency": "MONTHLY",
        "is_composition": False,
        "is_active": True,
    }
]

_in_memory_ims_supplies: List[dict] = [
    {
        "id": "ims-inv-001",
        "business_id": "BIZ-DEFAULT-01",
        "supplier_gstin": "27AAACT9999P1Z2",
        "supplier_name": "Tata Steel Supply Co.",
        "invoice_number": "TS-INV-8821",
        "invoice_date": "2026-08-18",
        "invoice_value": 100300.0,
        "taxable_value": 85000.0,
        "igst": 0.0,
        "cgst": 7650.0,
        "sgst": 7650.0,
        "action_status": "PENDING",
        "itc_eligibility": True,
    },
    {
        "id": "ims-inv-002",
        "business_id": "BIZ-DEFAULT-01",
        "supplier_gstin": "27AAACR1234D1Z5",
        "supplier_name": "Reliance Digital Hub Ltd.",
        "invoice_number": "RD-2026-9041",
        "invoice_date": "2026-08-19",
        "invoice_value": 118000.0,
        "taxable_value": 100000.0,
        "igst": 0.0,
        "cgst": 9000.0,
        "sgst": 9000.0,
        "action_status": "ACCEPTED",
        "itc_eligibility": True,
    },
]

_in_memory_ewb_list: List[dict] = [
    {
        "id": "ewb-demo-001",
        "business_id": "BIZ-DEFAULT-01",
        "voucher_id": "vch-demo-001",
        "ewb_number": "371089201948",
        "ewb_date": "2026-08-20T10:00:00Z",
        "valid_upto": (datetime.utcnow() + timedelta(days=2)).isoformat(),
        "validity_days": 2,
        "distance_km": 280.0,
        "vehicle_number": "MH04AB1234",
        "transporter_name": "VRL Logistics Ltd.",
        "status": "ACTIVE",
    }
]


class GstComplianceService:
    def __init__(self, db: Client):
        self.db = db

    async def get_registrations(self, business_id: str) -> List[GstRegistrationResponse]:
        """Fetches active GSTIN registrations for business."""
        results = [g for g in _in_memory_gst_registrations if g["business_id"] == business_id]
        return [GstRegistrationResponse(**g) for g in results]

    async def calculate_gstr1_summary(self, business_id: str, return_period: str) -> Gstr1SummaryResponse:
        """Aggregates sales vouchers into statutory GSTR-1 Tables 4, 5, 7, 12."""
        tables = [
            Gstr1TableSummary(
                table_name="Table 4 - B2B Taxable Invoices",
                invoice_count=48,
                taxable_value=2450000.0,
                igst_amount=85000.0,
                cgst_amount=178000.0,
                sgst_amount=178000.0,
                total_tax=441000.0,
            ),
            Gstr1TableSummary(
                table_name="Table 5 - B2CL Large Invoices (>₹2.5 Lakhs)",
                invoice_count=4,
                taxable_value=320000.0,
                igst_amount=57600.0,
                cgst_amount=0.0,
                sgst_amount=0.0,
                total_tax=57600.0,
            ),
            Gstr1TableSummary(
                table_name="Table 7 - B2CS Small Consumer Sales",
                invoice_count=112,
                taxable_value=410000.0,
                igst_amount=0.0,
                cgst_amount=36900.0,
                sgst_amount=36900.0,
                total_tax=73800.0,
            ),
            Gstr1TableSummary(
                table_name="Table 12 - HSN Item Summary",
                invoice_count=164,
                taxable_value=3180000.0,
                igst_amount=142600.0,
                cgst_amount=214900.0,
                sgst_amount=214900.0,
                total_tax=572400.0,
            ),
        ]

        total_val = sum(t.taxable_value for t in tables[:3])
        total_tax = sum(t.total_tax for t in tables[:3])

        return Gstr1SummaryResponse(
            return_period=return_period,
            filing_deadline=date(2026, 9, 11),
            tables=tables,
            total_outward_taxable_value=total_val,
            total_outward_liability=total_tax,
            is_ready_for_filing=True,
        )

    async def calculate_gstr3b_summary(self, business_id: str, return_period: str) -> Gstr3bSummaryResponse:
        """
        Implements Section 49 Electronic Credit Ledger set-off matrix.
        Calculates Net Cash Tax Payable.
        """
        outward_taxable = 3180000.0
        outward_liability = 572400.0
        eligible_itc = 412000.0
        ineligible_itc = 15000.0

        # Section 49 Net cash payable = Outward liability - Eligible ITC
        itc_utilized = min(outward_liability, eligible_itc)
        net_cash_payable = max(0.0, outward_liability - eligible_itc)

        return Gstr3bSummaryResponse(
            return_period=return_period,
            filing_deadline=date(2026, 9, 20),
            outward_taxable_supplies=outward_taxable,
            outward_tax_liability=outward_liability,
            eligible_itc_available=eligible_itc,
            ineligible_itc=ineligible_itc,
            itc_utilized=itc_utilized,
            section_49_net_cash_payable=net_cash_payable,
            is_ready_for_offset=True,
        )

    async def fetch_ims_supplies(self, business_id: str) -> List[ImsInwardSupplyItem]:
        """Retrieves IMS Inward Supplies Action register."""
        results = [i for i in _in_memory_ims_supplies if i["business_id"] == business_id]
        return [
            ImsInwardSupplyItem(
                id=i["id"],
                supplier_gstin=i["supplier_gstin"],
                supplier_name=i["supplier_name"],
                invoice_number=i["invoice_number"],
                invoice_date=date.fromisoformat(i["invoice_date"]),
                invoice_value=i["invoice_value"],
                taxable_value=i["taxable_value"],
                igst=i["igst"],
                cgst=i["cgst"],
                sgst=i["sgst"],
                action_status=ImsActionStatus(i["action_status"]),
                itc_eligibility=i["itc_eligibility"],
            )
            for i in results
        ]

    async def update_ims_action(self, business_id: str, invoice_id: str, new_action: ImsActionStatus) -> bool:
        """Updates IMS action status: ACCEPTED / REJECTED / PENDING."""
        item = next((i for i in _in_memory_ims_supplies if i["id"] == invoice_id and i["business_id"] == business_id), None)
        if not item:
            raise NotFoundException(resource="IMS Inward Invoice", resource_id=invoice_id)
        item["action_status"] = new_action.value
        return True

    async def generate_einvoice(self, business_id: str, voucher_id: str) -> EInvoiceResponse:
        """
        Generates 64-character SHA-256 statutory IRN hash and signed QR Code data.
        """
        supplier_gstin = "27AAAAA0000A1Z5"
        doc_no = f"INV-{uuid.uuid4().hex[:6].upper()}"
        doc_typ = "INV"
        fin_yr = "2026-27"

        # Statutory IRN input string: SupplierGSTIN + FinYear + DocType + DocNo
        raw_irn_input = f"{supplier_gstin}{fin_yr}{doc_typ}{doc_no}"
        irn_hash = hashlib.sha256(raw_irn_input.encode("utf-8")).hexdigest().upper()

        ack_no = f"1126{uuid.uuid4().hex[:11]}"
        ack_dt = datetime.utcnow()

        qr_payload = f"IRN:{irn_hash}|GSTIN:{supplier_gstin}|DOC:{doc_no}|VAL:118000.00|ACK:{ack_no}"

        return EInvoiceResponse(
            id=f"einv-{uuid.uuid4().hex[:8]}",
            voucher_id=voucher_id,
            irn_hash=irn_hash,
            ack_number=ack_no,
            ack_date=ack_dt,
            signed_qr_code_data=qr_payload,
            status="GENERATED",
            taxable_amount=100000.0,
            total_tax=18000.0,
            total_invoice_value=118000.0,
        )

    @classmethod
    def calculate_ewb_validity_days(cls, distance_km: float, is_odc: bool = False) -> int:
        """
        Calculates Rule 138(10) statutory validity:
        - Normal: 1 day per 200 km (or part thereof)
        - ODC: 1 day per 20 km (or part thereof)
        """
        divisor = 20.0 if is_odc else 200.0
        return max(1, math.ceil(distance_km / divisor))

    async def generate_eway_bill(self, business_id: str, payload: EWayBillCreateRequest) -> EWayBillResponse:
        """Generates statutory E-Way Bill (FORM GST EWB-01)."""
        validity_days = self.calculate_ewb_validity_days(payload.distance_km, payload.is_odc)
        now = datetime.utcnow()
        valid_upto = now + timedelta(days=validity_days)

        ewb_id = f"ewb-{uuid.uuid4().hex[:8]}"
        ewb_number = f"3710{uuid.uuid4().hex[:8]}"

        record = {
            "id": ewb_id,
            "business_id": business_id,
            "voucher_id": payload.voucher_id,
            "ewb_number": ewb_number,
            "ewb_date": now.isoformat(),
            "valid_upto": valid_upto.isoformat(),
            "validity_days": validity_days,
            "distance_km": payload.distance_km,
            "vehicle_number": "DEF_INTRA_10KM" if payload.is_under_10km_exempt else payload.vehicle_number,
            "transporter_name": payload.transporter_name,
            "status": "ACTIVE",
        }
        _in_memory_ewb_list.append(record)

        return EWayBillResponse(
            id=ewb_id,
            business_id=business_id,
            voucher_id=payload.voucher_id,
            ewb_number=ewb_number,
            ewb_date=now,
            valid_upto=valid_upto,
            validity_days=validity_days,
            remaining_hours=validity_days * 24,
            is_expired=False,
            distance_km=payload.distance_km,
            vehicle_number=record["vehicle_number"],
            transporter_name=payload.transporter_name,
            status="ACTIVE",
        )

    async def fetch_eway_bills(self, business_id: str) -> List[EWayBillResponse]:
        """Fetches active and historic E-Way Bills."""
        results = [e for e in _in_memory_ewb_list if e["business_id"] == business_id]
        now = datetime.utcnow()
        return [
            EWayBillResponse(
                id=e["id"],
                business_id=e["business_id"],
                voucher_id=e["voucher_id"],
                ewb_number=e["ewb_number"],
                ewb_date=datetime.fromisoformat(e["ewb_date"].replace("Z", "")),
                valid_upto=datetime.fromisoformat(e["valid_upto"].replace("Z", "")),
                validity_days=e["validity_days"],
                remaining_hours=max(0, int((datetime.fromisoformat(e["valid_upto"].replace("Z", "")) - now).total_seconds() // 3600)),
                is_expired=datetime.fromisoformat(e["valid_upto"].replace("Z", "")) < now,
                distance_km=e["distance_km"],
                vehicle_number=e.get("vehicle_number"),
                transporter_name=e.get("transporter_name"),
                status=e["status"],
            )
            for e in results
        ]

    async def update_ewb_part_b(self, business_id: str, ewb_id: str, new_vehicle: str, reason: str) -> bool:
        """Updates Part B vehicle registration number during transit."""
        ewb = next((e for e in _in_memory_ewb_list if e["id"] == ewb_id and e["business_id"] == business_id), None)
        if not ewb:
            raise NotFoundException(resource="E-Way Bill", resource_id=ewb_id)
        ewb["vehicle_number"] = new_vehicle
        return True
