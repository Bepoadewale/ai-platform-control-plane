# Implementation Status

**Evidence boundary:** the repository is **PORTFOLIO COMPLETE — LOCAL-FIRST SCOPE** and
**CLOUD-PILOT VALIDATED — NOT PRODUCTION-CERTIFIED**. An executed AWS component below means it ran
in the short-lived, guarded pilot and was torn down; it does not imply a long-running production
service or that unexecuted production controls are present.

| Capability | Status | Validation |
| --- | --- | --- |
| Control-plane API/lifecycle | ✅ Executed locally | signed FastAPI + OPA + kind acceptance demo |
| Durable lifecycle/audit state | ✅ Executed | SQLite restart-recovery test |
| Tenant boundaries and idempotency | ✅ Executed | lifecycle tests cover cross-tenant denial and conflicting-key rejection |
| Signed JWT/JWKS | ✅ Executed locally | FastAPI authentication integration tests |
| Keycloak OIDC | ✅ Executed locally | synthetic Keycloak realm issued a bearer token accepted by FastAPI |
| OPA policy enforcement | ✅ Executed locally | OPA 1.20.2 HTTP decision and API integration |
| GitOps rendering | ✅ Executed locally | rendered Helm values consumed by kind reconciler |
| Kubernetes reconciliation | ✅ Executed locally | Helm apply, rollout readiness, API destroy in kind |
| Approval plan binding / stale plans | ✅ Executed locally | immutable apply/destroy plans, independent approval, and kind cleanup |
| TTL reaping | ✅ Executed locally | short-TTL kind workload reaped with namespace deletion verified |
| Interrupted reconciliation recovery | ✅ Executed locally | persisted `APPLYING` workload recovered once after service restart |
| Helm/Kubernetes security defaults | ✅ Executed locally | non-root image, read-only root filesystem, `emptyDir /tmp`, probes, limits, and readiness |
| Prometheus / Grafana | ✅ Executed locally | Prometheus scrape/query and provisioned Grafana dashboard API |
| OpenTelemetry Collector | ✅ Executed locally | collector received FastAPI HTTP spans via OTLP/HTTP |
| PostgreSQL persistence | ✅ Executed locally | authenticated API create, direct SQL lifecycle/audit evidence, and restart recovery |
| Argo CD reconciliation | ✅ Executed locally | Argo CD 3.5.3 synchronized the Helm golden path in kind; Application reported `Synced/Healthy` and Deployment became `1/1` available |
| Clean-room bootstrap and teardown | ✅ Executed locally | `make clean-local` removed Project 1 local state; `make bootstrap-local`, `make compose-smoke`, `make demo-local`, and `make argocd-demo` recreated and validated it |
| Operator Console | ✅ Executed in bounded AWS pilot | EKS-hosted, hardened Nginx UI served through a project-scoped local port-forward; Keycloak Authorization Code + PKCE login/logout, explicit CORS, and signed API request passed. No public AWS endpoint, TLS ingress, or enterprise identity issuer is claimed. |
| AWS pilot Terraform foundation | ✅ Executed in a bounded AWS pilot | Terraform created the tagged VPC, EKS, two CPU nodes, RDS, ECR, Secrets Manager container, IAM roles, and OIDC providers; a guarded teardown then removed workload resources (the EKS cluster had been manually deleted during review) |
| AWS Phase 0 guardrails | ✅ Executed in AWS pilot account | encrypted/versioned S3 Terraform state, DynamoDB lock table, required tags, and USD 10 actual-cost alerts |
| GitHub Actions Terraform OIDC workflow | 🟡 Implemented / Not Executed | manual plan/apply/destroy dropdown, branch-bound OIDC roles, and explicit confirmations; no OIDC workflow run yet |
| EKS GitOps runtime manifests | ✅ Executed in a bounded AWS pilot | Argo CD synchronized the EKS control plane, OPA, Keycloak, OTel Collector, NetworkPolicy, probes, and ECR image to `Synced/Healthy` |
| Cloud observability | ✅ Executed in a bounded AWS pilot | Prometheus scraped the control plane, Tempo returned FastAPI traces, and Grafana exposed the provisioned control-plane dashboard |
| Production Git commit/PR → Argo reconciliation | 🟡 Implemented / Not Executed | GitHub App publisher is unit-tested; durable worker wiring and an AWS GitOps lifecycle remain pending |
| Durable asynchronous reconciler | 📋 Roadmap | API-process local reconciler is executed; worker/operator is not |
| External secret delivery / workload identity | 📋 Roadmap | EKS OIDC provider and an empty Secrets Manager container are in the plan; IRSA/Pod Identity plus External Secrets is not executed |
| Delegated MCP OIDC identity | 📋 Roadmap | local MCP runtime is executed; environment-variable authority is not production identity |
