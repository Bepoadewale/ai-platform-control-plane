# Agent Safety

An AI agent is a governed caller, not a platform administrator.

It can inspect tenant-visible catalog, status, audit, and cost estimates; create plans; and request
permitted tenant work through MCP or the API. It cannot read secrets, obtain AWS/Kubernetes/Git
credentials, cross tenant boundaries, alter policy, approve itself, or autonomously mutate protected
production.

Every agent write traverses the same signed identity, tenant/RBAC, OPA, immutable plan, approval,
durable audit, and GitOps path as a human write. Prompt content never grants a capability absent
from the caller's authorization.

The current MCP runtime remains subordinate to the API. Replacing its development authority adapter
with delegated enterprise OIDC is tracked in [Production Evolution](production-evolution.md).
