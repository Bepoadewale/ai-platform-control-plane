# Failure and Recovery

| Failure | Executed cloud behavior | Recovery boundary |
| --- | --- | --- |
| Policy denial | OPA rejected an unsafe/cross-tenant request before mutation; audit persisted | Correct request/policy; retry with same idempotency key |
| Bad workload image | Kubernetes reached `ImagePullBackOff` and `ProgressDeadlineExceeded`; observer persisted `FAILED` | Reviewed known-good desired-state restore, then governed deletion |
| API/worker Pod loss | One API and one worker Pod were deliberately removed; PDBs retained availability and deployments returned to `2/2` | Kubernetes restarts stateless pods; PostgreSQL preserves durable lifecycle/jobs |
| Desired-state deletion | Reviewed GitHub deletion PR merged; Argo pruned Application and namespace; lifecycle became `DESTROYED` | Re-request through normal plan/approval path |
| OPA unavailable | Protected writes fail closed | Restore the policy service; do not bypass it |

Backup/restore, model-quality rollback, and multi-region disaster recovery are future production
improvements, not completed evidence. See [Production Evolution](production-evolution.md).
