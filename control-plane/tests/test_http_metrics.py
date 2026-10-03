from fastapi.testclient import TestClient
from platform_control_plane.api.main import app


def test_http_boundary_metrics_record_status_without_authorization_data() -> None:
    client = TestClient(app)

    assert client.get("/healthz").status_code == 200
    metrics = client.get("/metrics").text

    assert 'platform_http_requests_total{method="GET",route="/healthz",status_code="200"}' in metrics
    assert "authorization" not in metrics.lower()
