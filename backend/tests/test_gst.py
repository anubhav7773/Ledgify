from fastapi.testclient import TestClient
from app.services.gst_service import GstComplianceService


def test_list_gst_registrations(client: TestClient):
    """Verifies listing of active GSTINs."""
    response = client.get("/api/v1/gst/registrations")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["data"]) >= 1
    assert data["data"][0]["state_code"] == "27"


def test_gstr1_summary_calculation(client: TestClient):
    """Verifies GSTR-1 outward table generation (Tables 4, 5, 7, 12)."""
    response = client.get("/api/v1/gst/gstr1-summary?return_period=082026")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    gstr1 = data["data"]
    assert len(gstr1["tables"]) == 4
    assert gstr1["total_outward_taxable_value"] > 0
    assert gstr1["total_outward_liability"] > 0


def test_gstr3b_section_49_net_cash_offset(client: TestClient):
    """Verifies GSTR-3B Section 49 Electronic Credit Ledger set-off."""
    response = client.get("/api/v1/gst/gstr3b-summary?return_period=082026")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    gstr3b = data["data"]
    assert gstr3b["outward_tax_liability"] > 0
    assert gstr3b["eligible_itc_available"] > 0
    assert gstr3b["section_49_net_cash_payable"] == (
        gstr3b["outward_tax_liability"] - gstr3b["eligible_itc_available"]
    )


def test_ims_portal_review_and_action(client: TestClient):
    """Verifies IMS portal inward supplies retrieval and action update."""
    list_res = client.get("/api/v1/gst/ims-portal")
    assert list_res.status_code == 200
    supplies = list_res.json()["data"]
    assert len(supplies) >= 1

    inv_id = supplies[0]["id"]

    # Accept the supplier invoice
    action_payload = {"invoice_id": inv_id, "action_status": "ACCEPTED"}
    action_res = client.post("/api/v1/gst/ims-portal/action", json=action_payload)
    assert action_res.status_code == 200
    assert action_res.json()["success"] is True


def test_generate_einvoice_irn_hash(client: TestClient):
    """Verifies 64-character SHA-256 statutory IRN hash and Signed QR code generation."""
    payload = {"voucher_id": "vch-demo-001"}
    response = client.post("/api/v1/gst/einvoice/generate", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["success"] is True
    einv = data["data"]
    assert len(einv["irn_hash"]) == 64
    assert einv["signed_qr_code_data"].startswith("IRN:")
    assert einv["status"] == "GENERATED"


def test_rule_138_validity_calculation():
    """Verifies Rule 138(10) distance validity formula."""
    # Normal Cargo (200 km/day)
    assert GstComplianceService.calculate_ewb_validity_days(150.0, is_odc=False) == 1
    assert GstComplianceService.calculate_ewb_validity_days(200.0, is_odc=False) == 1
    assert GstComplianceService.calculate_ewb_validity_days(201.0, is_odc=False) == 2
    assert GstComplianceService.calculate_ewb_validity_days(650.0, is_odc=False) == 4

    # Over Dimensional Cargo (20 km/day)
    assert GstComplianceService.calculate_ewb_validity_days(100.0, is_odc=True) == 5


def test_generate_and_update_eway_bill(client: TestClient):
    """Verifies E-Way Bill generation and Part B vehicle update."""
    create_payload = {
        "voucher_id": "vch-demo-001",
        "distance_km": 350.0,
        "is_odc": False,
        "vehicle_number": "MH12XY9999",
        "transporter_name": "SafeXpress Ltd.",
    }

    create_res = client.post("/api/v1/gst/eway-bills", json=create_payload)
    assert create_res.status_code == 201
    data = create_res.json()["data"]
    assert data["validity_days"] == 2
    assert data["vehicle_number"] == "MH12XY9999"

    ewb_id = data["id"]

    # Update Part B vehicle during transit
    update_payload = {"new_vehicle_number": "KA01AB5678", "reason": "Vehicle Breakdown"}
    update_res = client.post(f"/api/v1/gst/eway-bills/{ewb_id}/update-part-b", json=update_payload)
    assert update_res.status_code == 200
    assert update_res.json()["success"] is True
