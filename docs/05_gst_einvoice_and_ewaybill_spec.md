# 05_gst_einvoice_and_ewaybill_spec.md — Indian GST Engine, E-Invoicing (FORM GST INV-01) & E-Way Bill Pipeline

## 1. Overview & Statutory Framework
Ledgify features a full-stack Indian GST compliance engine compliant with the CGST/SGST/IGST Acts 2017 and Invoice Registration Portal (IRP) standards.
Key statutory mechanics implemented:
1. **Intra-State vs. Inter-State Engine:** Automated determination of $(CGST + SGST)$ vs. $IGST$ based on Supplier Location vs. Place of Supply (POS).
2. **E-Invoice Payload Generation:** Constructing validated FORM GST INV-01 (Version 1.1) JSON payloads with 16-character alphanumeric invoice numbers.
3. **Mandatory HSN Digit Validation:** Enforcing 4-digit ($AATO \le 5\text{ Cr}$) and 6-digit ($AATO > 5\text{ Cr}$) HSN codes for B2B transactions.
4. **E-Way Bill Logistics Engine:** Generating FORM GST EWB-01 payloads for consignments $> ₹50,000$, with updated 1-day-per-200km validity tracking and $<10\text{km}$ intra-state Part B exemptions.
5. **ITC Disallowance Engine (Section 17(5)):** Automated blocking and segregation of ineligible Input Tax Credit.
6. **Statutory GSTR & IMS Mappings:** GSTR-1 table-wise aggregation, GSTR-3B summary computations, and Inward Supplies Management (IMS) reconciliation.

---

## 2. Tax Calculation Engine & Place of Supply (POS) Logic

### 2.1 Intra-State vs. Inter-State Rules
- **Intra-State Supply ($CGST + SGST$):** Triggered when `Supplier.StateCode == Buyer.PlaceOfSupply`.
  $$\text{CGST Amount} = \text{Taxable Value} \times \left( \frac{\text{GST Rate}}{2} \right)$$
  $$\text{SGST Amount} = \text{Taxable Value} \times \left( \frac{\text{GST Rate}}{2} \right)$$
- **Inter-State Supply ($IGST$):** Triggered when `Supplier.StateCode != Buyer.PlaceOfSupply` or supply category is `EXPWP`, `SEZWP`, or `DEXP`.
  $$\text{IGST Amount} = \text{Taxable Value} \times \text{GST Rate}$$
- **Rounding Rules:** Individual line-item tax amounts and assessable values are rounded to **2 decimal places** (half-up). Overall final invoice values are rounded to the nearest whole rupee with rounding adjustments recorded in `RndOffAmt`.

### 2.2 Dart Implementation of Tax Split Logic
```dart
class GstTaxEngine {
  static GstSplitResult calculateTax({
    required int supplierStateCode,
    required int placeOfSupplyStateCode,
    required double taxableValue,
    required double gstRate, // e.g., 18.0
    required String supplyCategory, // B2B, B2C, SEZWP, EXPWP, etc.
  }) {
    final bool isInterState = (supplierStateCode != placeOfSupplyStateCode) ||
        supplyCategory == 'EXPWP' ||
        supplyCategory == 'SEZWP';

    if (isInterState) {
      final double igst = double.parse((taxableValue * (gstRate / 100)).toStringAsFixed(2));
      return GstSplitResult(
        cgst: 0.00,
        sgst: 0.00,
        igst: igst,
        cess: 0.00,
        totalTax: igst,
        totalAmount: double.parse((taxableValue + igst).toStringAsFixed(2)),
      );
    } else {
      final double halfRate = gstRate / 2;
      final double cgst = double.parse((taxableValue * (halfRate / 100)).toStringAsFixed(2));
      final double sgst = double.parse((taxableValue * (halfRate / 100)).toStringAsFixed(2));
      return GstSplitResult(
        cgst: cgst,
        sgst: sgst,
        igst: 0.00,
        cess: 0.00,
        totalTax: double.parse((cgst + sgst).toStringAsFixed(2)),
        totalAmount: double.parse((taxableValue + cgst + sgst).toStringAsFixed(2)),
      );
    }
  }
}

class GstSplitResult {
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double totalTax;
  final double totalAmount;

  GstSplitResult({
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.totalTax,
    required this.totalAmount,
  });
}
3. E-Invoice JSON Payload Generator (FORM GST INV-01 Version 1.1)All B2B e-invoices are structured into standard IRP JSON payloads. Document numbers must strictly conform to regex ^[a-zA-Z0-9/-]{1,16}$.  JSON{
  "Version": "1.1",
  "TranDtls": {
    "TaxSch": "GST",
    "SupTyp": "B2B",
    "RegRev": "N",
    "EcmGstin": null,
    "IgstOnIntra": "N"
  },
  "DocDtls": {
    "Typ": "INV",
    "No": "INV-2026-0042",
    "Dt": "31/08/2026"
  },
  "SellerDtls": {
    "Gstin": "09AAAAA0000A1Z5",
    "LglNm": "Acme Industrial Traders",
    "TrdNm": "Acme Traders",
    "Addr1": "Plot 42, Transport Nagar",
    "Loc": "Lucknow",
    "Pin": 226012,
    "Stcd": "09"
  },
  "BuyerDtls": {
    "Gstin": "27BBBBB0000B1Z2",
    "LglNm": "Bharat Enterprise Private Limited",
    "TrdNm": "Bharat Ent",
    "Pos": "27",
    "Addr1": "MIDC Industrial Area, Andheri East",
    "Loc": "Mumbai",
    "Pin": 400093,
    "Stcd": "27"
  },
  "ItemList": [
    {
      "SlNo": "1",
      "PrdDesc": "Steel Ball Bearings 10mm",
      "IsServc": "N",
      "HsnCd": "84821010",
      "Qty": 100.00,
      "Unit": "NOS",
      "UnitPrice": 250.000,
      "TotAmt": 25000.00,
      "Discount": 0.00,
      "PreTaxVal": 25000.00,
      "AssAmt": 25000.00,
      "GstRt": 18.000,
      "IgstAmt": 4500.00,
      "CgstAmt": 0.00,
      "SgstAmt": 0.00,
      "CesRt": 0.000,
      "CesAmt": 0.00,
      "TotItemVal": 29500.00
    }
  ],
  "ValDtls": {
    "AssVal": 25000.00,
    "CgstVal": 0.00,
    "SgstVal": 0.00,
    "IgstVal": 4500.00,
    "CesVal": 0.00,
    "RndOffAmt": 0.00,
    "TotInvVal": 29500.00
  }
}
4. E-Way Bill Logistics Engine (FORM GST EWB-01)4.1 Validity Period Rules (Rule 138(10))Standard Cargo: 1 Day per 200 km (or part thereof).  Over Dimensional Cargo (ODC): 1 Day per 20 km.  Calculation Formula:$$\text{Validity Days} = \max\left(1, \left\lceil \frac{\text{Distance in KM}}{200.0} \right\rceil\right)$$4.2 Part B & Consignment ThresholdsThreshold: Mandatory for goods consignments where Total Value $> ₹50,000$ (or any value for inter-State Job Work and Handicraft goods).  $<10\text{km}$ Intra-State Exemption: Updating vehicle details (Part B) is optional if the movement is within the same state from the consignor's premises to the transporter's hub for distances $< 10\text{ km}$.  SQLCREATE OR REPLACE FUNCTION public.calculate_ewb_validity_days(distance_km NUMERIC, is_odc BOOLEAN DEFAULT FALSE)
RETURNS INTEGER LANGUAGE plpgsql IMMUTABLE AS $$ BEGIN     IF is_odc THEN         RETURN GREATEST(1, CEIL(distance_km / 20.0)::INTEGER);     ELSE         RETURN GREATEST(1, CEIL(distance_km / 200.0)::INTEGER);     END IF; END; $$;
5. Input Tax Credit (ITC) Engine & Blocked Categories (Section 17(5))The accounting pipeline automatically evaluates incoming expenses and flags ineligible ITC under Section 17(5) of the CGST Act[cite: 1, 2]:Category CodeDescriptionStatutory RuleAutomated Accounting TreatmentSEC17_5_AMotor vehicles ($\le 13$ seats)Blocked unless used for commercial transport/trainingExpensed to Asset/Cost; no ITC ledger posting  SEC17_5_BFood, catering, club, healthBlocked unless inward supply is used to make same category supplyFull amount routed to Expense ledger; zero ITC  SEC17_5_CWorks Contract for Immovable PropertyBlocked unless input service for further works contractTax capitalized to building/construction account  SEC17_5_DSelf-construction of Immovable PropertyBlocked even when used in course of businessTax added to asset capitalization value  SEC17_5_HLost, stolen, destroyed, written-off, giftsBlockedReversal of previously availed ITC via GSTR-3B Table 4(B)  SEC16_2Unpaid supplier invoices $> 180$ daysRule 37 reversal requirementAutomatic tax alert; liability added with interest  6. GSTR Returns & Inward Supplies Management (IMS) Mapping6.1 GSTR-1 Mapping StructureTable 4 (B2B): Taxable supplies to registered recipients (includes 4A standard, 4B reverse charge, 4C e-commerce).  Table 5 (B2CL): Inter-State supplies to unregistered persons with invoice value $> ₹2,50,000$[cite: 1, 2].Table 7 (B2CS): Intra-State supplies to unregistered persons and Inter-State supplies $\le ₹2,50,000$ (consolidated by rate and state)[cite: 1, 2].Table 12 (HSN): HSN-wise summary of outward supplies (HSN, UQC, Quantity, Taxable Value, Tax amounts)[cite: 1, 2].Table 13: Document issue summary (Total invoices issued, cancelled, and net active).  6.2 GSTR-3B Auto-Drafting EngineTable 3.1(a): Aggregated taxable outward supplies from Sales vouchers.  Table 3.1(d): Inward supplies liable to reverse charge ($RCM$).  Table 4(A)(5): All Other ITC auto-populated from valid Purchase vouchers[cite: 2].Table 4(B): ITC reversals (Rule 37 180-day failure, Rule 42/43, and Section 17(5))[cite: 2].Table 4(D): Ineligible ITC reporting under Section 17(5)[cite: 2].6.3 Inward Supplies Management (IMS) ActionsThe gstr_returns_ims table tracks supplier invoices ingested from the GST portal[cite: 1, 2]:ACCEPTED: Confirms inward invoice; eligible ITC flows directly to GSTR-2B and GSTR-3B Table 4(A)[cite: 1, 2].REJECTED: Discards fraudulent/incorrect supplier invoice; removes ITC entitlement from current period[cite: 1, 2].PENDING: Holds invoice in suspense; allows deferred ITC claim in subsequent tax periods[cite: 1, 2].