# Roadmap

- [x] M1: modular control-plane API, domain lifecycle, plans, audit trail, tests, ADRs.
- [x] M2: kind bootstrap plus Helm golden path (namespace, identity, policy, quotas, limits, ingress, HPA, PDB).
- [x] M3: RBAC model, tenant boundary, audit trail, local policy adapter, and Rego policy contract/tests.
- [x] M4: desired-state renderer and Argo CD Application contract; real Git provider/Argo status adapter remains pending.
- [x] M5: API-only MCP tool contract and Codex configuration; installable MCP runtime remains pending.
- [x] M6: Prometheus endpoint, dashboard starter, and SLO documentation; OTEL exporter/tracing remains pending.
- [x] M7: Terraform module contracts, provider lock, format/validate workflow; reviewed resource implementations remain pending.
- [x] M8: cost metadata/plans and safe non-production TTL destruction.
- [x] M9: AI workload schema with explicit CPU-local/GPU-cloud distinction.
- [ ] M10: PostgreSQL repository, OIDC/JWKS, OPA runtime, Git provider adapter, asynchronous reconciler, Crossplane evaluation.
