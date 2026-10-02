# P0 — Required for Portfolio Claim

All current portfolio-claim P0 items are executed locally. Re-open this section only when a
validated primary-path regression is discovered.

# P1 — Production Hardening

- Add CI-suitable coverage for the Compose smoke stack when runner capacity allows.
- Expand API-level authorization integration coverage for cross-tenant access.
- [x] Apply AWS pilot account guardrails: USD 10 Budget alerts, required tags, encrypted remote Terraform state, and lock table.
- Add a project-scoped guardrail teardown procedure and record its safe execution after the AWS workload pilot is complete.
- Create a GitHub OIDC role boundary and prove a read-only identity workflow before granting deployment permissions.
- Replace validate-only AWS Terraform contracts with a reviewed, minimal non-production foundation.
- Add protected Git desired-state publication and Argo status observation; do not let the production API invoke Helm/kubectl directly.
- Separate reconciliation from the API process with durable job state and idempotent recovery.
- Add external secret references/workload identity, lifecycle metrics/child spans, and measured SLO/alert evidence.
- Replace development MCP identity environment variables with trusted delegated OIDC identity.

# P2 — Enhancements

- Expand CLI and developer-facing cost reporting.

# P3 — Future / Cloud / Hardware

- Enterprise OIDC validation, multi-cluster delivery, HA/failover, and GPU/cloud workload execution.
