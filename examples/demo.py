from pathlib import Path

from platform_control_plane.models.domain import Actor, EnvironmentRequest, EnvironmentType, Role
from platform_control_plane.provisioning.service import EnvironmentService

service = EnvironmentService(Path("environments"))
actor = Actor(subject="demo-agent", tenant_id="team-demo", roles={Role.AGENT_REQUESTER}, is_agent=True)
request = EnvironmentRequest(name="demo-api", team="team-demo", environment_type=EnvironmentType.DEVELOPMENT, ttl_hours=12, postgresql=True, redis=True, cost_center="DEMO", idempotency_key="demo-agent-001")
environment = service.create(actor, request)
print(f"{environment.state}: {environment.endpoint}")
print(f"GitOps desired state: {environment.gitops_path}")
print(f"Estimated temporary cost: ${environment.plan.estimated_ttl_usd}")
