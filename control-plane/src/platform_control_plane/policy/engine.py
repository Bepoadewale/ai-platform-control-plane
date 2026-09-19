from platform_control_plane.models.domain import Actor, EnvironmentRequest, EnvironmentType, Role


class PolicyDecision:
    def __init__(
        self, allowed: bool, reasons: list[str] | None = None, approval_required: bool = False
    ):
        self.allowed = allowed
        self.reasons = reasons or []
        self.approval_required = approval_required


class PolicyEngine:
    """Fail-closed policy boundary. OPA bundle can replace this adapter in production."""

    def evaluate(self, actor: Actor, request: EnvironmentRequest) -> PolicyDecision:
        reasons: list[str] = []
        if actor.tenant_id != request.team:
            reasons.append("tenant boundary violation: request team must match actor tenant")
        if Role.VIEWER in actor.roles:
            reasons.append("viewer role cannot create environments")
        if request.workload.privileged:
            reasons.append("privileged containers are prohibited")
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
