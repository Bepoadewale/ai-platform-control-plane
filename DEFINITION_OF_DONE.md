# Definition of Done

- **Level 1 — Foundation:** domain lifecycle/policy and unit tests exist.
- **Level 2 — Partially Validated:** API and one local dependency are exercised with integration tests.
- **Level 3 — Local End-to-End Validated:** signed identity → policy → plan/approval → kind workload Ready → audit; denial and destroy paths are exercised.
- **Level 4 — Production-pilot complete:** cloud reference environment is Terraform-created,
  cloud-validated through real external integrations and failure/recovery paths, accurately
  documented, and Terraform-destroyed with post-destroy evidence. **Met 2026-10-04.**

## Completed production-pilot gate

The completed pilot created and removed the Terraform-managed AWS reference environment and
executed GitHub OIDC apply, EKS/Argo lifecycle, external secret/workload identity, failure/recovery,
HA, observability, and bounded cost/load checks. Static validation remains insufficient.

## Enterprise/public-SaaS certification gate

The following is deliberately stricter than `PRODUCTION-PILOT COMPLETE`. Do not describe this
repository as **enterprise/public-SaaS certified** until every applicable item has executed evidence:

- [x] Bounded cloud create → validate → destroy pilot, with EKS/Argo/runtime/Console evidence.
- [x] Individual environment request publishes a protected Git change and Argo reconciles that
  workload in EKS with observed readiness, bad-image health regression/restore, and cleanup.
- [x] Durable outbox/worker reconciliation with idempotent retry and recovery has executed.
- [x] GitHub Actions AWS OIDC and external secret/workload identity paths executed without GitHub
  AWS access keys. Enterprise identity remains unexecuted.
- [x] HA pod-loss recovery, bounded load, deployment-health rollback/cleanup, and short-lived
  availability evidence have been measured. Backup/restore and sustained workload evidence remain.
- [x] Prometheus, Tempo, Grafana, a firing alert, a two-minute availability query, and a Cost
  Explorer query have executed. Settled billing data and an error-budget policy remain unexecuted.
- [ ] Enterprise OIDC and trusted public TLS ingress with a production Console identity/CORS
  boundary have been validated.
