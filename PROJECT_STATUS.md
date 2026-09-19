# Project Status

## Current Maturity

PARTIALLY VALIDATED

## Executed and Verified

- FastAPI lifecycle, tenancy, policy, approval, audit and GitOps-rendering tests/demos run locally.
- SQLite-backed lifecycle and audit recovery survives a service restart.
- Signed RS256 JWT/JWKS verification is exercised through the FastAPI API, including invalid-signature,
  expired, wrong issuer/audience, missing tenant, and unauthorized-role cases.
- Rego policy tests run with OPA 1.20.2.
- A kind v0.30.0 Kubernetes cluster was created with Docker Engine 29.0.1. The lifecycle service
  rendered a golden-path Helm release, observed its Deployment Ready, and executed verified cleanup.

## Implemented but Not End-to-End Validated

- Prometheus endpoint and direct local Kubernetes reconciliation adapter. The adapter has not yet
  been exercised through the authenticated HTTP API or a live OPA request path.

## Simulated

- Cost estimates.
- Header identity is available only through an explicit local-development opt-in.

## Architecture / Contracts Only

- OPA runtime, GitOps controller, AWS provisioning.

## Known Failures

- The first golden-path release failed because its read-only filesystem had no writable `/tmp`; the
  chart now supplies an `emptyDir` mount and the corrected release reached Ready. This failure was
  local-only and no longer reproduces.

## Current P0 Objective

Run OPA as the live request-policy dependency and fail closed on protected writes, then exercise
the authenticated HTTP API through the kind reconciler.

## Last Validation

- `.venv/bin/python -m pytest -q`: 14 passed (2 upstream TestClient deprecation warnings).
- `.venv/bin/python -m ruff check control-plane/src control-plane/tests cli/src`: passed.
- `opa test platform/policies tests/policy`: 1/1 passed with OPA 1.20.2.
- Docker Engine 29.0.1 is available; Helm lint and Terraform validation passed earlier in this run.
- `PLATFORM_RECONCILER=kind ... EnvironmentService.create(...)`: Deployment reached Ready in kind.
- `PLATFORM_RECONCILER=kind ... EnvironmentService.destroy(...)`: namespace deletion verified.

## Last Updated

2026-09-19, uncommitted local kind reconciliation increment.
