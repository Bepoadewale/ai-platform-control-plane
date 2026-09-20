import httpx
from platform_control_plane.models.domain import Actor, EnvironmentRequest, EnvironmentType, Role
from platform_control_plane.policy.engine import OPAPolicyEngine


class Response:
    def __init__(self, payload: dict):
        self.payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self.payload


def request() -> EnvironmentRequest:
    return EnvironmentRequest(
        name="opa-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="opa-policy-test-001",
    )


def actor() -> Actor:
    return Actor(subject="ada", tenant_id="team-demo", roles={Role.DEVELOPER})


def test_live_opa_adapter_translates_decision(monkeypatch):
    captured: dict = {}

    def post(url: str, **kwargs):
        captured["url"] = url
        captured["input"] = kwargs["json"]["input"]
        return Response({"result": {"allow": True, "deny": [], "approval_required": False}})

    monkeypatch.setattr("platform_control_plane.policy.engine.httpx.post", post)
    decision = OPAPolicyEngine("http://opa.local/v1/data/platform/environment").evaluate(actor(), request())

    assert decision.allowed is True
    assert captured["url"].endswith("/platform/environment")
    assert captured["input"]["actor"]["tenant_id"] == "team-demo"


def test_live_opa_unavailable_fails_closed(monkeypatch):
    def post(*_args, **_kwargs):
        raise httpx.ConnectError("not reachable")

    monkeypatch.setattr("platform_control_plane.policy.engine.httpx.post", post)
    decision = OPAPolicyEngine("http://opa.local/v1/data/platform/environment").evaluate(actor(), request())

    assert decision.allowed is False
    assert "unavailable" in decision.reasons[0]
