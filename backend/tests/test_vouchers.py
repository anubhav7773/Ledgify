from fastapi.testclient import TestClient


def test_create_balanced_voucher(client: TestClient):
    """Verifies that a mathematically balanced voucher creates successfully."""
    payload = {
        "voucher_type": "Payment",
        "voucher_number": "PMT-2026-001",
        "narration": "Office Electricity Bill payment via NEFT",
        "items": [
            {
                "ledger_id": "led-expense-elec",
                "ledger_name": "Electricity Expense",
                "is_debit": True,
                "amount": 12500.0,
            },
            {
                "ledger_id": "led-hdfc-01",
                "ledger_name": "HDFC Current Account",
                "is_debit": False,
                "amount": 12500.0,
            },
        ],
    }

    response = client.post("/api/v1/vouchers", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["success"] is True
    assert data["data"]["voucher_number"] == "PMT-2026-001"
    assert data["data"]["total_amount"] == 12500.0


def test_create_unbalanced_voucher_rejection(client: TestClient):
    """Verifies that an unbalanced entry is rejected with 422 Double-Entry Imbalance error."""
    payload = {
        "voucher_type": "Journal",
        "items": [
            {
                "ledger_id": "led-expense-01",
                "is_debit": True,
                "amount": 10000.0,
            },
            {
                "ledger_id": "led-bank-01",
                "is_debit": False,
                "amount": 8000.0,  # 2000 discrepancy!
            },
        ],
    }

    response = client.post("/api/v1/vouchers", json=payload)
    assert response.status_code == 422
    data = response.json()
    assert data["success"] is False
    assert data["error"]["code"] == "DOUBLE_ENTRY_IMBALANCE"


def test_list_and_get_voucher(client: TestClient):
    """Verifies voucher listing and retrieval by ID."""
    response = client.get("/api/v1/vouchers")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["data"]) >= 1

    first_id = data["data"][0]["id"]
    get_response = client.get(f"/api/v1/vouchers/{first_id}")
    assert get_response.status_code == 200
    assert get_response.json()["data"]["id"] == first_id
