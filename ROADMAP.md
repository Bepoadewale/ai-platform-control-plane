# Roadmap

- [x] M1: modular control-plane API, domain lifecycle, plans, audit trail, tests, ADRs.
- [x] M2: kind bootstrap plus Helm golden path (namespace, identity, policy, quotas, limits, ingress, HPA, PDB).
- [x] M3: RBAC model, tenant boundary, audit trail, local policy adapter, and Rego policy contract/tests.
- [x] M4: desired-state renderer and local Argo CD reconciliation. A production Git provider adapter and production Argo status adapter remain pending.
- [x] M5: runnable local MCP runtime and API-backed tool contract. Trusted delegated OIDC identity remains pending.
- [x] M6: Prometheus endpoint, provisioned Grafana dashboard, and local OTLP HTTP tracing. Lifecycle-level metrics, child spans, measured SLOs, and alerting remain pending.
- [x] M7: Terraform module contracts, provider lock, format/validate workflow. Deployable AWS resource implementations remain pending.
- [x] M8: cost metadata/plans and safe non-production TTL destruction.
- [x] M9: AI workload schema with explicit CPU-local/GPU-cloud distinction.
- [x] M10: local PostgreSQL, Keycloak OIDC/JWKS, and live OPA runtime.
- [ ] M11: production-pilot guardrails, GitHub OIDC → AWS, and a reviewed minimal Terraform foundation.
- [ ] M12: protected Git desired-state adapter → Argo CD → EKS lifecycle with readiness/audit evidence.
- [ ] M13: durable asynchronous reconciler, external secret references/workload identity, and lifecycle observability/SLOs.
- [ ] M14: trusted delegated MCP identity, developer self-service integration, and multi-cluster evaluation.

See [the production-pilot plan](docs/production-pilot.md). None of M11–M14 has been executed yet.
