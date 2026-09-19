from platform_control_plane.models.domain import RESOURCE_PROFILES, EnvironmentRequest, Plan


class Planner:
    def plan(self, request: EnvironmentRequest) -> Plan:
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
        return Plan(
            request_id=request.request_id,
            resources=resources,
            estimated_monthly_usd=round(monthly, 2),
            estimated_ttl_usd=round(ttl_cost, 2) if ttl_cost else None,
            requires_approval=request.environment_type == "production",
        )
