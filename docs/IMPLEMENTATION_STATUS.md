# Implementation Status

**Evidence boundary:** the repository is **PRODUCTION-PILOT COMPLETE — EPHEMERAL
SINGLE-ACCOUNT SCOPE**. An executed AWS component below ran in the guarded pilot and was torn down;
it does not imply a long-running enterprise/public-SaaS service or that unexecuted enterprise
controls are present.

The AWS pilot is the primary deployment evidence. Rows marked **Executed locally** are retained as
historical contributor-harness validation, not the current deployment claim.

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
| AWS pilot Terraform foundation | ✅ Executed in a bounded AWS pilot | Terraform created the tagged VPC, EKS, two CPU nodes, RDS, ECR, Secrets Manager container, IAM roles, and OIDC providers. The final 2026-10-04 guarded destroy removed the active footprint; direct AWS queries and remote Terraform state confirmed it was absent. |
| AWS Phase 0 guardrails | ✅ Executed in AWS pilot account | encrypted/versioned S3 Terraform state, DynamoDB lock table, required tags, and USD 10 actual-cost alerts |
| GitHub Actions Terraform OIDC workflow | ✅ Executed in a bounded AWS pilot | a protected GitHub Actions run assumed the branch-bound role with short-lived credentials and completed Terraform apply; the confirmation-gated hosted destroy action remains unexecuted |
| EKS GitOps runtime manifests | ✅ Executed in a bounded AWS pilot | Argo CD synchronized the EKS control plane, OPA, Keycloak, OTel Collector, NetworkPolicy, probes, and ECR image to `Synced/Healthy` |
| Cloud observability | ✅ Executed in a bounded AWS pilot | Prometheus scraped the control plane, Tempo returned FastAPI traces, and Grafana exposed the provisioned control-plane dashboard |
| Production Git commit/PR → Argo reconciliation | ✅ Executed in a bounded AWS pilot | EKS worker used the scoped GitHub App credential to publish reviewed create/delete PRs; merged desired state drove Argo ApplicationSet workload creation, readiness, prune, and durable `DESTROYED` state. |
| Durable asynchronous reconciler | ✅ Executed in a bounded AWS pilot | PostgreSQL-backed worker ran in EKS and published the governed Git changes; local tests cover restart-safe job recovery and publication failure, and a two-replica cloud pod-loss drill restored service availability. |
| Argo environment ApplicationSet | ✅ Executed in a bounded AWS pilot | merged values directories created private workload Applications; deletion PRs pruned both Applications and namespaces. |
| Argo/Kubernetes status observer | ✅ Executed in a bounded AWS pilot | separately deployed read-only observer recorded both a `1/1` Ready workload and a bad-image `ProgressDeadlineExceeded` failure. |
| External secret delivery / workload identity | ✅ Executed in a bounded AWS pilot | IRSA-backed External Secrets delivered the scoped GitHub App credential to the worker without placing its value in Git, API requests, or audit records. |
| HA / pod-loss recovery | ✅ Executed in a bounded AWS pilot | two API, OPA, and worker replicas with `minAvailable: 1` PDBs; one API and one worker Pod were deleted and their Deployments returned to `2/2` available |
| Bounded load and availability signal | ✅ Executed in a bounded AWS pilot | 20 authenticated catalog requests at concurrency 4 completed; Prometheus observed 160 successful requests in the two-minute query window. This is not sustained-load certification. |
| Alert and SLO query drill | ✅ Executed in a bounded AWS pilot | 20 invalid bearer requests fired `PilotUnauthorizedRequestBurst`; the two-minute catalog availability query returned `1`. No external alert receiver was configured. |
| Deployment-health rollback / cleanup | ✅ Executed in a bounded AWS pilot | a reviewed bad image reached `ProgressDeadlineExceeded`; a reviewed restore returned the known-good workload to Ready; governed deletion then pruned the namespace. This is not model-quality rollback. |
| Cost Explorer query | 🟡 Executed / delayed billing evidence | the service-level query ran, returning estimated zero/empty data within AWS's 24–48-hour publication window; it is not a zero-cost claim or settled cost evidence. |
| Delegated MCP OIDC identity | 📋 Roadmap | local MCP runtime is executed; environment-variable authority is not production identity |
