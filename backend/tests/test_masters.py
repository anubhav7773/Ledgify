from fastapi.testclient import TestClient


def test_get_chart_of_accounts(client: TestClient):
    """Verifies retrieval of 28 Tally primary group hierarchy."""
    response = client.get("/api/v1/masters/chart-of-accounts")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["data"]) == 4  # Assets, Liabilities, Income, Expenses


def test_list_and_create_ledger(client: TestClient):
    """Verifies ledger creation and balance tracking."""
    create_payload = {
        "name": "Tata Steel Supply Co.",
        "parent_group_id": "grp-sundry-creditors",
        "parent_group_name": "Sundry Creditors",
        "opening_balance": 75000.0,
        "opening_balance_type": "Cr",
        "gstin": "27AAACT9999P1Z2",
    }

    response = client.post("/api/v1/masters/ledgers", json=create_payload)
    assert response.status_code == 201
    data = response.json()
    assert data["success"] is True
    assert data["data"]["name"] == "Tata Steel Supply Co."
    assert data["data"]["opening_balance"] == 75000.0


def test_list_stock_items(client: TestClient):
    """Verifies stock item inventory listing."""
    response = client.get("/api/v1/masters/stock-items")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["data"]) >= 1
    assert "hsn_code" in data["data"][0]
