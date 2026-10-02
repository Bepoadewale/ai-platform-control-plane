# AI Platform Control Plane — Agent Guide

Mission: govern environment requests from API through policy, lifecycle, desired state, and audit. Preserve tenant isolation and fail closed.

Stack: Python 3.12, FastAPI, Pydantic, SQLite/PostgreSQL, Keycloak/JWKS, OPA, Helm/kind, Argo CD,
Prometheus, Grafana, OpenTelemetry, and Terraform contracts.

Commands: `make install`, `make test`, `make lint`, `make demo`, `make bootstrap-local`,
`make compose-smoke`, `make demo-local`, `make argocd-demo`, `make clean-local`, `make helm-lint`,
and `make terraform-validate`.

Rules: never claim AWS execution without an integration test; never trust request headers as production
identity; no secrets; do not push main; preserve lifecycle/idempotency semantics. Argo/kind/OPA,
Keycloak, PostgreSQL, OTel, Prometheus, and Grafana are locally executed only when evidence exists.
Meaningful changes need tests. Update status/backlog after work and report exact validation.

Production-pilot rule: do not add long-lived AWS credentials to GitHub, local configuration, or the
repository. Use a least-privilege GitHub Actions OIDC role and record real `plan`, `apply`, smoke,
failure, cost, and `destroy` evidence before labeling any AWS component executed. The production
pilot plan is `docs/production-pilot.md`; it does not authorize provisioning until the repository
owner supplies a dedicated account, budget, and explicit deployment authority.

The owner-authorized Phase 0 backend and USD 10 Budget are executed and recorded in
`docs/VALIDATION.md`. They do not authorize EKS, VPC, RDS, workloads, GitHub deployment roles, or
any other paid service; obtain a reviewed plan and explicit scope before each later phase.
