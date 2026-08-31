from fastapi.testclient import TestClient


def test_get_current_user_profile(client: TestClient):
    """Verifies profile endpoint returns active business and tier context."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["subscription_tier"] == "PRO"
    assert payload["data"]["active_business"]["id"] == "BIZ-DEFAULT-01"


def test_switch_business_context(client: TestClient):
    """Verifies switching business tenant updates context."""
    response = client.post(
        "/api/v1/auth/switch-business",
        json={"business_id": "BIZ-BRANCH-DELHI"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["switched_to"] == "BIZ-BRANCH-DELHI"
