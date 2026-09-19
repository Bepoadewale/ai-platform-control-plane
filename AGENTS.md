# AI Platform Control Plane — Agent Guide

Mission: govern environment requests from API through policy, lifecycle, desired state, and audit. Preserve tenant isolation and fail closed.

Stack: Python 3.12, FastAPI, Pydantic, Prometheus, Rego contracts, Helm/Terraform contracts.

Commands: `make install`, `make test`, `make lint`, `make demo`, `make helm-lint`, `make terraform-validate`; future local integration: `make bootstrap-local`.

Rules: never claim AWS, Argo, or Kubernetes execution without an integration test; never trust request headers as production identity; no secrets; do not push main; preserve lifecycle/idempotency semantics. Meaningful changes need tests. Update status/backlog after work and report exact validation.
