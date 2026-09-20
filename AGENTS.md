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
