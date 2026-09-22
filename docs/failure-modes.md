# Failure modes and recovery

| Failure | Control-plane behavior | Operator recovery |
| --- | --- | --- |
| OPA/policy unavailable | Fail closed; no desired state is written. | Restore a signed policy bundle and retry with the same idempotency key. |
| Desired-state publication unavailable | Keep request `PLANNED`/`FAILED`; do not apply directly to Kubernetes. | Restore the publication path, retry with the idempotency key, and inspect audit evidence. |
| Argo CD/Kubernetes unavailable | The GitOps path remains unreconciled; direct local reconciliation reports a bounded failure rather than `READY`. | Repair control plane/data plane and inspect Argo or Kubernetes health. |
| Duplicate agent retry | Return original request by tenant-scoped idempotency key. | No manual cleanup required. |
| Partial provisioning | Record `FAILED`, preserve desired state and correlation id. | Reconcile or execute a reviewed compensation workflow. |
| Terraform lock/cloud quota | Do not bypass locking or quotas. | Resolve owner/quota, then retry reviewed apply. |
| Expired credentials | Reject authenticated call; no fallback identity. | Refresh OIDC credentials. |

The local implementation has executed persisted lifecycle recovery through SQLite/PostgreSQL and
kind reconciliation. A transactional outbox and durable Git publication workflow remain production
hardening work; the local direct reconciler and local Argo CD demo do not claim distributed
publication recovery semantics.
