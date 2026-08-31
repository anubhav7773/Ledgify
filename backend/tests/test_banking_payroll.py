from fastapi.testclient import TestClient
from app.services.banking_payroll_service import PayrollService


def test_list_bank_accounts_and_transactions(client: TestClient):
    """Verifies listing of bank accounts and statement transactions."""
    acc_res = client.get("/api/v1/banking/accounts")
    assert acc_res.status_code == 200
    accounts = acc_res.json()["data"]
    assert len(accounts) >= 1
    assert accounts[0]["ifsc_code"] == "HDFC0000240"

    acc_id = accounts[0]["id"]
    tx_res = client.get(f"/api/v1/banking/accounts/{acc_id}/transactions")
    assert tx_res.status_code == 200
    txs = tx_res.json()["data"]
    assert len(txs) >= 1
    assert txs[0]["status"] == "AUTO_MATCHED"


def test_reconcile_match_transaction(client: TestClient):
    """Verifies matching an unreconciled bank transaction."""
    payload = {
        "transaction_id": "tx-002",
        "voucher_id": "vch-demo-001",
        "action_type": "MATCH",
    }
    response = client.post("/api/v1/banking/reconcile-match", json=payload)
    assert response.status_code == 200
    assert response.json()["success"] is True


def test_employee_directory(client: TestClient):
    """Verifies staff employee directory."""
    response = client.get("/api/v1/payroll/employees")
    assert response.status_code == 200
    employees = response.json()["data"]
    assert len(employees) >= 2
    assert employees[0]["uan_number"] is not None


def test_calculate_monthly_payroll_statutory_deductions(client: TestClient):
    """Verifies statutory salary calculations: EPF 12%, ESI, Professional Tax, TDS."""
    payload = {"month": "2026-08"}
    response = client.post("/api/v1/payroll/calculate-run", json=payload)
    assert response.status_code == 200
    data = response.json()["data"]
    assert data["total_employees"] >= 2
    assert data["total_gross_salary"] > 0
    assert data["total_epf"] > 0
    assert data["total_professional_tax"] == 400.0  # 2 employees @ ₹200/mo
    assert data["total_net_disbursement"] == (
        data["total_gross_salary"]
        - data["total_epf"]
        - data["total_esi"]
        - data["total_professional_tax"]
        - data["total_tds"]
    )


def test_execute_payroll_and_post_journal(client: TestClient):
    """Verifies executing payroll automatically creates a balanced Salary Journal Voucher."""
    payload = {"month": "2026-08"}
    response = client.post("/api/v1/payroll/execute-run", json=payload)
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["journal_voucher_id"] is not None
    assert data["journal_voucher_id"].startswith("vch-")


def test_tds_register_and_form_26q(client: TestClient):
    """Verifies TDS Section 194Q/194J register and Form 26Q return summary."""
    # List register
    reg_res = client.get("/api/v1/direct-tax/tds-register?section=194Q")
    assert reg_res.status_code == 200
    items = reg_res.json()["data"]
    assert len(items) >= 1
    assert items[0]["section_code"] == "194Q"
    assert items[0]["rate_percent"] == 0.1

    # Form 26Q summary
    f26q_res = client.get("/api/v1/direct-tax/form-26q-summary?quarter=Q2_2026_27")
    assert f26q_res.status_code == 200
    f26q = f26q_res.json()["data"]
    assert f26q["total_deductions_count"] >= 2
    assert f26q["total_tds_deducted"] > 0
    assert f26q["is_due_soon"] is True
