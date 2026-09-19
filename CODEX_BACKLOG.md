# P0 — Required for Portfolio Claim

- Add migration/version management and corruption/recovery coverage for durable lifecycle/audit state.
- Replace development header identity with signed local JWT validation.
- Execute current policy through local OPA and fail closed on evaluator failure.
- Bootstrap kind and reconcile one approved environment to a Ready workload.
- Add end-to-end destroy/TTL and denial-path tests with audit evidence.

# P1 — Production Hardening

- Persist idempotency keys, add recovery/reconciliation, OTel traces, and PostgreSQL profile.

# P2 — Enhancements

- Expand CLI and developer-facing cost reporting.

# P3 — Future / Cloud / Hardware

- AWS, Argo CD, enterprise OIDC, and multi-cluster delivery.
