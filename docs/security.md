# Security model

The platform accepts identity claims at its boundary and applies role plus tenant authorization in the control plane. Roles are `viewer`, `developer`, `platform-operator`, `platform-admin`, and `agent-requester`. An agent normally has only `agent-requester`.

Policy defaults deny privileged containers, disabled observability, cross-tenant requests, local-development GPUs, and autonomous agent production creation. Production changes await an operator approval. Request ids and idempotency keys make retries auditable and prevent duplicate environment creation.

Kubernetes templates set non-root execution, drop Linux capabilities, disable privilege escalation, use read-only root filesystems, resource limits, namespace quotas, and default-deny ingress/egress. Secrets are references only; neither API responses nor audit events contain secret values.

Local header identity is a development-only adapter. Production must use short-lived OIDC tokens, JWKS validation, workload identity, encrypted PostgreSQL, immutable central audit storage, rate limits, and protected/signed Git changes.
