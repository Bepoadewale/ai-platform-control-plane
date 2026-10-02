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
