import hashlib
import json

from platform_control_plane.models.domain import RESOURCE_PROFILES, EnvironmentRequest, Plan


class Planner:
    def plan(self, request: EnvironmentRequest, action: str = "APPLY") -> Plan:
        profile = RESOURCE_PROFILES[request.workload.size]
        monthly = profile["monthly_usd"] * request.workload.replicas
        resources = ["Namespace", "ResourceQuota", "LimitRange", "NetworkPolicy", "ServiceAccount"]
        resources.extend(
            ["Deployment", "Service", "Ingress", "ServiceMonitor", "PodDisruptionBudget"]
        )
        if request.postgresql:
            resources.append("PostgreSQL (in-cluster demo; managed service in AWS profile)")
            monthly += 12
        if request.redis:
            resources.append("Redis (in-cluster demo; managed service in AWS profile)")
            monthly += 6
        if request.object_storage:
            resources.append("Object storage (bucket policy via AWS profile)")
            monthly += 2
        if request.secret_refs:
            resources.append("ExternalSecret references (values never exposed to requester)")
        ttl_cost = monthly * request.ttl_hours / (24 * 30) if request.ttl_hours else None
        plan = Plan(
            request_id=request.request_id,
            action=action,
            resources=resources,
            estimated_monthly_usd=round(monthly, 2),
            estimated_ttl_usd=round(ttl_cost, 2) if ttl_cost else None,
            requires_approval=action == "DESTROY" or request.environment_type == "production",
        )
        digest_input = {
            "request": request.model_dump(mode="json", exclude={"request_id", "idempotency_key"}),
            "action": plan.action,
            "resources": plan.resources,
            "estimated_monthly_usd": plan.estimated_monthly_usd,
            "estimated_ttl_usd": plan.estimated_ttl_usd,
            "requires_approval": plan.requires_approval,
            "version": plan.version,
        }
        plan.plan_hash = hashlib.sha256(
            json.dumps(digest_input, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        return plan
