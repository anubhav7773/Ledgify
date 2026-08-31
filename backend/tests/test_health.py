from fastapi.testclient import TestClient


def test_root_redirect(client: TestClient):
    """Verifies root endpoint returns online status and links."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "docs_url" in data


def test_health_check_endpoint(client: TestClient):
    """Verifies /api/v1/health returns structured ApiResponse envelope."""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert "service" in payload["data"]
    assert "version" in payload["data"]
