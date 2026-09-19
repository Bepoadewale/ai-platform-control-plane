import os
from typing import Any

import httpx
from platform_control_plane.models.domain import Actor, EnvironmentRequest, EnvironmentType, Role


class PolicyDecision:
    def __init__(
        self, allowed: bool, reasons: list[str] | None = None, approval_required: bool = False
    ):
        self.allowed = allowed
        self.reasons = reasons or []
        self.approval_required = approval_required


class PolicyEngine:
    """Embedded local policy evaluator used only by explicit non-OPA test/demo modes."""

    def evaluate(self, actor: Actor, request: EnvironmentRequest) -> PolicyDecision:
        reasons: list[str] = []
        if actor.tenant_id != request.team:
            reasons.append("tenant boundary violation: request team must match actor tenant")
        if Role.VIEWER in actor.roles:
            reasons.append("viewer role cannot create environments")
        if request.workload.privileged:
            reasons.append("privileged containers are prohibited")
        if request.service_exposure == "loadbalancer" and Role.PLATFORM_OPERATOR not in actor.roles:
            reasons.append("LoadBalancer exposure requires platform-operator authorization")
        if not request.observability:
            reasons.append("observability cannot be disabled")
        if actor.is_agent and request.environment_type is EnvironmentType.PRODUCTION:
            reasons.append("agents cannot autonomously request production")
        if request.environment_type is EnvironmentType.PRODUCTION and request.ttl_hours:
            reasons.append("production environments cannot use ephemeral TTL")
        if request.workload.gpu_count and request.environment_type is EnvironmentType.DEVELOPMENT:
            reasons.append("GPU workloads are not available in local development")
        if reasons:
            return PolicyDecision(False, reasons)
        approval = request.environment_type is EnvironmentType.PRODUCTION
        return PolicyDecision(True, approval_required=approval)


class OPAPolicyEngine:
    """Live OPA adapter. A failed evaluator is a denied protected write."""

    def __init__(self, decision_url: str) -> None:
        self.decision_url = decision_url

    @classmethod
    def from_environment(cls, require_live: bool = False) -> "PolicyEngine | OPAPolicyEngine":
        decision_url = os.getenv("PLATFORM_OPA_DECISION_URL")
        if decision_url:
            return cls(decision_url)
        if require_live:
            return cls("http://127.0.0.1:1/unconfigured")
        return PolicyEngine()

    def evaluate(self, actor: Actor, request: EnvironmentRequest) -> PolicyDecision:
        payload = {
            "input": {
                "actor": actor.model_dump(mode="json"),
                "request": request.model_dump(mode="json"),
            }
        }
        try:
            response = httpx.post(self.decision_url, json=payload, timeout=3)
            response.raise_for_status()
            result: dict[str, Any] = response.json()["result"]
            allowed = result.get("allow")
            reasons = result.get("deny", [])
            approval_required = result.get("approval_required", False)
            if not isinstance(allowed, bool) or not isinstance(reasons, list) or not isinstance(
                approval_required, bool
            ):
                raise ValueError("OPA response has an invalid decision shape")
            return PolicyDecision(allowed, [str(reason) for reason in reasons], approval_required)
        except (httpx.HTTPError, KeyError, TypeError, ValueError) as error:
            return PolicyDecision(False, [f"OPA policy evaluation unavailable: {error}"])
