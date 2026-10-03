# Definition of Done

- **Level 1 — Foundation:** domain lifecycle/policy and unit tests exist.
- **Level 2 — Partially Validated:** API and one local dependency are exercised with integration tests.
- **Level 3 — Local End-to-End Validated:** signed identity → policy → plan/approval → kind workload Ready → audit; denial and destroy paths are exercised.
- **Level 4 — Portfolio Complete:** Level 3 plus reproducible demo, accurate README/status, CI, failure recovery and no unlabelled simulated infrastructure claim. **Met 2026-09-19:** `make demo-local` validates the signed FastAPI/OPA/kind success, denial, approval, and cleanup paths; optional cloud and observability-stack adapters remain explicitly marked.

## Separate production-pilot gate

AWS or production-platform execution may only be claimed after a separate pilot completes the
evidence gates in [docs/production-pilot.md](docs/production-pilot.md): GitHub OIDC, reviewed
Terraform plan/apply/destroy, EKS/Argo lifecycle, external secret/workload identity boundary,
failure/recovery evidence, and measured observability/cost evidence. Static Terraform validation,
local kind, or a successful container build are not substitutes.

## Production-certification gate

The following is deliberately stricter than `PORTFOLIO COMPLETE — LOCAL-FIRST SCOPE` and
`CLOUD-PILOT VALIDATED`. Do not describe this repository as production-certified until every
applicable item has executed evidence:

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
