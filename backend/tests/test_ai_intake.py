import io
from fastapi.testclient import TestClient


def test_scan_receipt_upload(client: TestClient):
    """Verifies OCR receipt scanner extracts structured line items and GST tax."""
    fake_image = io.BytesIO(b"fake_png_binary_data_header_bytes")

    response = client.post(
        "/api/v1/ai/scan-receipt",
        files={"file": ("receipt_test.png", fake_image, "image/png")},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    ocr = data["data"]
    assert "invoice_number" in ocr
    assert ocr["total_amount"] > 0
    assert ocr["confidence_score"] >= 0.85
    assert len(ocr["line_items"]) >= 1


def test_voice_voucher_parsing(client: TestClient):
    """Verifies Voice-to-Voucher parses spoken command into Dr/Cr accounting line items."""
    payload = {"transcript_text": "Pay office rent 35000 from HDFC account"}

    response = client.post("/api/v1/ai/voice-voucher", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    voice = data["data"]
    assert voice["amount"] == 35000.0
    assert "Office Rent" in voice["debit_ledger_name"]
    assert voice["inferred_voucher_type"] == "Payment"


def test_fuzzy_matching_vendor_entity(client: TestClient):
    """Verifies RapidFuzz matches fuzzy supplier names with high confidence."""
    # Test 1: Fuzzy query for Bharat Electronics
    payload1 = {"query_text": "Bharat Electronic Ltd"}
    response1 = client.post("/api/v1/ai/fuzzy-match-ledger", json=payload1)
    assert response1.status_code == 200
    data1 = response1.json()["data"]
    assert data1["best_match"] is not None
    assert "Bharat Electronics" in data1["best_match"]["ledger_name"]
    assert data1["best_match"]["similarity_score"] >= 80.0

    # Test 2: Exact learned alias
    payload2 = {"query_text": "tatasteel"}
    response2 = client.post("/api/v1/ai/fuzzy-match-ledger", json=payload2)
    assert response2.status_code == 200
    data2 = response2.json()["data"]
    assert data2["best_match"]["is_exact_match"] is True
    assert data2["best_match"]["ledger_name"] == "Tata Steel Supply Co."


def test_ai_drafts_queue_and_approve(client: TestClient):
    """Verifies AI drafts queue listing, approval, and voucher posting."""
    # List drafts
    list_res = client.get("/api/v1/ai/drafts")
    assert list_res.status_code == 200
    drafts = list_res.json()["data"]
    assert len(drafts) >= 1

    draft_id = drafts[0]["id"]

    # Approve draft
    approve_res = client.post(f"/api/v1/ai/drafts/{draft_id}/approve")
    assert approve_res.status_code == 200
    voucher = approve_res.json()["data"]
    assert voucher["id"] is not None
    assert voucher["total_amount"] > 0


def test_ai_draft_dismiss(client: TestClient):
    """Verifies dismissing an unwanted AI draft."""
    # First create a voice voucher to ensure we have a fresh draft
    client.post("/api/v1/ai/voice-voucher", json={"transcript_text": "Record test petty cash 500"})

    list_res = client.get("/api/v1/ai/drafts")
    drafts = list_res.json()["data"]
    target_id = drafts[-1]["id"]

    # Dismiss
    del_res = client.delete(f"/api/v1/ai/drafts/{target_id}")
    assert del_res.status_code == 200
    assert del_res.json()["success"] is True
