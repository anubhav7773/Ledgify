from fastapi.testclient import TestClient


def test_list_and_toggle_dpdp_consents(client: TestClient):
    """Verifies DPDP Act 2023 purpose consents listing and cryptographic toggle."""
    # List consents
    res = client.get("/api/v1/dpdp/consents")
    assert res.status_code == 200
    consents = res.json()["data"]
    assert len(consents) == 5

    # Revoke Document OCR consent
    toggle_payload = {"purpose_code": "PURPOSE_DOCUMENT_OCR", "is_granted": False}
    toggle_res = client.post("/api/v1/dpdp/consents/toggle", json=toggle_payload)
    assert toggle_res.status_code == 200
    assert toggle_res.json()["data"]["is_granted"] is False

    # Check unalterable audit log
    audit_res = client.get("/api/v1/dpdp/consents/audit-log")
    assert audit_res.status_code == 200
    logs = audit_res.json()["data"]
    assert len(logs) >= 1
    assert len(logs[0]["consent_payload_hash"]) == 64  # SHA-256


def test_export_data_portability(client: TestClient):
    """Verifies DSR Data Portability export package generation."""
    response = client.post("/api/v1/dpdp/dsr/export-portability")
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total_vouchers"] >= 1
    assert data["total_accounts"] >= 1
    assert len(data["integrity_checksum_sha256"]) == 64
    assert data["download_url"].endswith(".zip")


def test_section_128_erasure_pseudonymization(client: TestClient):
    """Verifies Right to Erasure pseudonymizes party PII while archiving books for 8 years."""
    payload = {"reason": "Customer account deletion request"}
    response = client.post("/api/v1/dpdp/dsr/erasure", json=payload)
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["status"] == "COMPLETED"
    assert "Section 128" in data["statutory_retention_until"]


def test_verify_play_purchase(client: TestClient):
    """Verifies Google Play purchase token verification and PRO tier unlock."""
    payload = {
        "purchase_token": "token_mock_play_store_9921827419",
        "product_id": "ledgify_pro_annual",
        "order_id": "GPA.3312-8921-9912",
        "package_name": "com.asiverticals.ledgify",
    }
    response = client.post("/api/v1/billing/verify-purchase", json=payload)
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["tier"] == "PRO"
    assert data["status"] == "ACTIVE"
    assert data["is_pro_or_enterprise"] is True


def test_get_subscription_status(client: TestClient):
    """Verifies subscription tier and active entitlement status."""
    response = client.get("/api/v1/billing/subscription-status")
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["tier"] in ["PRO", "ENTERPRISE"]
    assert data["is_pro_or_enterprise"] is True


def test_play_rtdn_webhook(client: TestClient):
    """Verifies RTDN real-time developer notification ingestion."""
    payload = {
        "version": "1.0",
        "package_name": "com.asiverticals.ledgify",
        "event_time_millis": "1788158053000",
        "subscription_notification": {
            "notificationType": 2,  # RENEWED
            "purchaseToken": "token_mock_play_store_9921827419",
            "subscriptionId": "ledgify_pro_annual",
        },
    }
    response = client.post("/api/v1/billing/google-play-rtdn", json=payload)
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "RTDN event processed"
