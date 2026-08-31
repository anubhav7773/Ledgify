from fastapi.testclient import TestClient


def test_root_redirect(client: TestClient):
    """Verifies root endpoint returns online status for GET and HEAD."""
    # GET
    res_get = client.get("/")
    assert res_get.status_code == 200
    assert res_get.json()["status"] == "online"

    # HEAD (UptimeRobot)
    res_head = client.head("/")
    assert res_head.status_code == 200
    assert "X-Service" in res_head.headers


def test_health_check_endpoint(client: TestClient):
    """Verifies /api/v1/health returns 200 OK for GET and HEAD."""
    # GET
    res_get = client.get("/api/v1/health")
    assert res_get.status_code == 200
    assert res_get.json()["success"] is True

    # HEAD
    res_head = client.head("/api/v1/health")
    assert res_head.status_code == 200
    assert res_head.headers.get("X-Status") == "UP"


def test_uptime_robot_ping_probes(client: TestClient):
    """Verifies ultra-fast HEAD ping endpoints for UptimeRobot monitoring."""
    for path in ["/health", "/ping", "/api/v1/health/ping"]:
        head_res = client.head(path)
        assert head_res.status_code == 200

        get_res = client.get(path)
        assert get_res.status_code == 200
