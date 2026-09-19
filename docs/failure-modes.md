# Failure modes and recovery

| Failure | Control-plane behavior | Operator recovery |
| --- | --- | --- |
| OPA/policy unavailable | Fail closed; no desired state is written. | Restore a signed policy bundle and retry with the same idempotency key. |
| Git provider unavailable | Keep request `PLANNED`/`FAILED`; do not apply directly to Kubernetes. | Restore connectivity, use outbox retry, inspect audit event. |
| Argo CD/Kubernetes unavailable | Desired state remains committed; reconciliation is eventually consistent. | Repair control plane/data plane and inspect Argo health. |
| Duplicate agent retry | Return original request by tenant-scoped idempotency key. | No manual cleanup required. |
| Partial provisioning | Record `FAILED`, preserve desired state and correlation id. | Reconcile or execute a reviewed compensation workflow. |
| Terraform lock/cloud quota | Do not bypass locking or quotas. | Resolve owner/quota, then retry reviewed apply. |
| Expired credentials | Reject authenticated call; no fallback identity. | Refresh OIDC credentials. |

Production persistence uses transactional state plus an outbox so an audit transition and a GitOps work item cannot be silently split. The current local mode demonstrates the lifecycle in-process; it does not claim distributed recovery semantics.
