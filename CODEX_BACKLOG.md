# P0 — Required for Portfolio Claim

All current portfolio-claim P0 items are executed locally. Re-open this section only when a
validated primary-path regression is discovered.

# P1 — Production Hardening

## Production-shaped single-account validation

- [x] Implement PostgreSQL/SQLite outbox job state and a durable desired-state publication worker
  with restart and publication-failure tests. AWS GitHub publication is executed.
- [x] Publish an approved environment as a protected Git change and observe merge/Argo state.
- [x] Execute the rendered Argo ApplicationSet-driven private EKS environment workload path with
  readiness, bad-workload failure, and destroy evidence. Quality rollback remains separate.
- [x] Execute the rendered IRSA + External Secrets path for the scoped GitHub App credential.
- [ ] Record a secret-rotation/recovery check.
- [x] Add HA-shaped API/worker deployment, recovery drills, lifecycle metrics/traces, SLO/alert,
  and bounded load/failure tests.
- [x] Complete the private, ephemeral, tunnel-reviewed AWS create → validate → destroy pass with
  guarded teardown and post-destroy AWS/Terraform evidence.

See [production-shaped validation](docs/production-shaped-validation.md). This target is
cloud-pilot hardening, not a production-certification claim.

- Add CI-suitable coverage for the Compose smoke stack when runner capacity allows.
- Expand API-level authorization integration coverage for cross-tenant access.
- [x] Apply AWS pilot account guardrails: USD 10 Budget alerts, required tags, encrypted remote Terraform state, and lock table.
- [x] Execute project-scoped AWS pilot teardown after owner completes public review; record destroy and remaining-resource evidence.
- Create a GitHub OIDC role boundary and prove a read-only identity workflow before granting deployment permissions.
- [x] Execute the authenticated Operator Console against the bounded EKS runtime through
  project-scoped local port-forwards; record its Keycloak PKCE, explicit CORS, and signed API
  evidence. A public TLS/enterprise-OIDC ingress remains a separate production hardening task.
- [x] Replace validate-only AWS Terraform contracts with a reviewed, minimal non-production foundation and execute the bounded runtime/policy/restart/telemetry pilot.
- [x] Add a GitHub App desired-state publication boundary and a GitHub Actions plan/apply/destroy workflow.
- [x] Wire GitHub App publication to a durable worker with local restart/failure tests.
- [x] Execute a protected Git change → Argo reconciliation before claiming bounded-pilot GitOps.
- [x] Add protected Git desired-state publication and Argo status observation; the cloud API does not invoke Helm/kubectl directly.
- [x] Separate reconciliation from the API process with durable job state and idempotent recovery.
- Collect sustained-load/error-budget and settled AWS billing evidence; bounded load, alert firing,
  and a delayed Cost Explorer query are executed.
- Replace development MCP identity environment variables with trusted delegated OIDC identity.

# P2 — Enhancements

- Expand CLI and developer-facing cost reporting.

# P3 — Future / Cloud / Hardware

- Enterprise OIDC validation, multi-cluster delivery, HA/failover, and GPU/cloud workload execution.
