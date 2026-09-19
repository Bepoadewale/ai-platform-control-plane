# Project Status

## Current Maturity

PARTIALLY VALIDATED

## Executed and Verified

- FastAPI lifecycle, tenancy, policy, approval, audit and GitOps-rendering tests/demos run locally.
- SQLite-backed lifecycle and audit recovery survives a service restart.
- Signed RS256 JWT/JWKS verification is exercised through the FastAPI API, including invalid-signature,
  expired, wrong issuer/audience, missing tenant, and unauthorized-role cases.
- Rego policy tests run with OPA 1.20.2.

## Implemented but Not End-to-End Validated

- Desired-state rendering, Terraform/Helm contracts and Prometheus endpoint.

## Simulated

- Cost estimates.
- Header identity is available only through an explicit local-development opt-in.

## Architecture / Contracts Only

- OPA runtime, GitOps controller, Kubernetes reconciliation, AWS provisioning.

## Known Failures

- Local kind cluster creation has not yet completed; Docker Engine is available and the bootstrap will be retried.

## Current P0 Objective

Run OPA as the live request-policy dependency and fail closed on protected writes.

## Last Validation

- `.venv/bin/python -m pytest -q`: 14 passed (2 upstream TestClient deprecation warnings).
- `.venv/bin/python -m ruff check control-plane/src control-plane/tests cli/src`: passed.
- `opa test platform/policies tests/policy`: 1/1 passed with OPA 1.20.2.
- Docker Engine 29.0.1 is available; Helm lint and Terraform validation passed earlier in this run.

## Last Updated

2026-09-19, uncommitted Week 1 JWT/OPA compatibility increment.
