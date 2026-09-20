# Security model

The platform verifies identity at its boundary and applies role plus tenant authorization in the control plane. Local execution validates RS256 JWT/JWKS signatures, issuer, audience, expiry, subject, tenant, and roles. Roles are `viewer`, `developer`, `platform-operator`, `platform-admin`, and `agent-requester`. An agent normally has only `agent-requester`.

Policy defaults deny privileged containers, disabled observability, cross-tenant requests, local-development GPUs, and autonomous agent production creation. Production changes await an independent operator approval bound to the immutable plan hash. Request ids and idempotency keys make retries auditable and prevent duplicate environment creation; reuse of a key with materially different input is rejected.

## Enforced decision examples

| Situation | Decision | Why |
| --- | --- | --- |
| Developer requests a tenant-scoped development environment | Allow | Standard golden path and low-risk lifecycle |
| Agent requests production autonomously | Deny | An agent requester cannot independently mutate protected production |
| Developer requests production | Approval required | A separate operator must approve the exact plan hash |
| Requester tries to approve its own plan | Deny | Approval independence prevents self-authorization |
| Approved plan changes before apply | Reject as stale | Approval is bound to the original plan state/hash |
| Policy service is unavailable for protected write | Fail closed | Availability must not bypass policy |
| Tenant A reads or mutates Tenant B | Deny | Tenant boundary is enforced by the API and policy input |

These paths are covered by local API/policy tests and the `make demo-local` workflow. They do not
mean the local fixture is an enterprise identity deployment; enterprise OIDC remains a production
adapter.

Kubernetes templates set non-root execution, drop Linux capabilities, disable privilege escalation, use read-only root filesystems, resource limits, namespace quotas, and default-deny ingress/egress. Secrets are references only; neither API responses nor audit events contain secret values.

Local header identity is a development-only adapter. Production must use short-lived OIDC tokens, JWKS validation, workload identity, encrypted PostgreSQL, immutable central audit storage, rate limits, and protected/signed Git changes.
