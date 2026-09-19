package platform.environment

default allow := false

deny contains "tenant boundary violation" if input.actor.tenant_id != input.request.team
deny contains "privileged containers are prohibited" if input.request.workload.privileged
deny contains "LoadBalancer exposure requires platform-operator authorization" if input.request.service_exposure == "loadbalancer" and not "platform-operator" in input.actor.roles
deny contains "observability cannot be disabled" if not input.request.observability
deny contains "agents cannot autonomously request production" if input.actor.is_agent and input.request.environment_type == "production"
deny contains "production environments cannot use ephemeral TTL" if input.request.environment_type == "production" and input.request.ttl_hours > 0

allow if count(deny) == 0
approval_required if input.request.environment_type == "production"
