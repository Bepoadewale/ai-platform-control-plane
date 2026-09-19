package platform.environment

import rego.v1

default allow := false
default approval_required := false

deny contains "tenant boundary violation" if input.actor.tenant_id != input.request.team
deny contains "viewer role cannot create environments" if "viewer" in input.actor.roles
deny contains "privileged containers are prohibited" if input.request.workload.privileged
deny contains "LoadBalancer exposure requires platform-operator authorization" if {
  input.request.service_exposure == "loadbalancer"
  not "platform-operator" in input.actor.roles
}
deny contains "observability cannot be disabled" if not input.request.observability
deny contains "agents cannot autonomously request production" if {
  input.actor.is_agent
  input.request.environment_type == "production"
}
deny contains "production environments cannot use ephemeral TTL" if {
  input.request.environment_type == "production"
  input.request.ttl_hours > 0
}
deny contains "GPU workloads are not available in local development" if {
  input.request.workload.gpu_count > 0
  input.request.environment_type == "development"
}

allow if count(deny) == 0
approval_required if input.request.environment_type == "production"
