from fastapi.testclient import TestClient


def test_trial_balance_is_balanced(client: TestClient):
    """Verifies Trial Balance returns balanced closing debit and credit columns."""
    response = client.get("/api/v1/reports/trial-balance")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    tb = data["data"]
    assert tb["is_balanced"] is True
    assert tb["total_closing_debit"] == tb["total_closing_credit"]
    assert tb["discrepancy"] == 0.0


def test_profit_and_loss_report(client: TestClient):
    """Verifies Profit & Loss calculations."""
    response = client.get("/api/v1/reports/profit-and-loss")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    pnl = data["data"]
    assert pnl["gross_profit"] > 0
    assert pnl["net_profit_before_tax"] > 0
    assert pnl["total_revenue"] >= pnl["revenue_from_operations"]


def test_balance_sheet_equilibrium(client: TestClient):
    """Verifies Schedule III Balance Sheet equilibrium."""
    response = client.get("/api/v1/reports/balance-sheet")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    bs = data["data"]
    assert bs["is_balanced"] is True
    assert bs["total_equity_and_liabilities"] == bs["total_assets"]


def test_day_book_feed(client: TestClient):
    """Verifies Day Book transaction stream."""
    response = client.get("/api/v1/reports/day-book")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert len(data["data"]) >= 1
