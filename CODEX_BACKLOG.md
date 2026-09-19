# P0 — Required for Portfolio Claim

- Add migration/version management and corruption/recovery coverage for durable lifecycle/audit state.
- Execute current policy through local OPA and fail closed on evaluator failure.
- Exercise the authenticated HTTP API through OPA and the kind reconciler in one local integration test.
- Add end-to-end TTL and policy-denial tests with audit evidence.

# P1 — Production Hardening

- Persist idempotency keys, add recovery/reconciliation, OTel traces, and PostgreSQL profile.

# P2 — Enhancements

- Expand CLI and developer-facing cost reporting.

# P3 — Future / Cloud / Hardware

- AWS, Argo CD, enterprise OIDC, and multi-cluster delivery.
