# Project Status

## Current Maturity

PORTFOLIO COMPLETE — LOCAL-FIRST SCOPE

## Executed and Verified

- FastAPI lifecycle, tenancy, policy, approval, audit and GitOps-rendering tests/demos run locally.
- SQLite-backed lifecycle and audit recovery survives a service restart.
- Signed RS256 JWT/JWKS verification is exercised through the FastAPI API, including invalid-signature,
  expired, wrong issuer/audience, missing tenant, and unauthorized-role cases.
- Rego policy tests run with OPA 1.20.2.
- A kind v0.30.0 Kubernetes cluster was created with Docker Engine 29.0.1. The lifecycle service
  rendered a golden-path Helm release, observed its Deployment Ready, and executed verified cleanup.
- The FastAPI request path was executed with live OPA and kind: request → OPA allow → plan → Helm
  reconciliation → Kubernetes readiness → persisted audit → API-driven destroy. A production agent
  request was denied by OPA with no Kubernetes mutation.
- A real kind TTL lifecycle was executed: Ready workload → persisted expiry → reaper → verified
  namespace deletion. A deliberately unhealthy workload persisted as `FAILED` with a
  `reconciliation.failed` audit event before cleanup.
- `make demo-local` executes a reproducible signed JWT → OPA → FastAPI → kind Ready → audit/metrics
  → destroy flow; verifies autonomous production-agent denial; and exercises production apply/destroy
  through independent exact-plan approvals. The non-root API image build and `/healthz` endpoint were
  also executed locally.
- The protected production lifecycle was executed in kind: immutable apply plan → independent
  approval → Ready → immutable destruction plan → independent approval → verified cleanup.
- An interrupted `APPLYING` environment was persisted, the lifecycle service was restarted, and an
  operator recovery pass reconciled it exactly once before verified kind cleanup.
- Local Keycloak issued a real RS256 developer token that FastAPI validated through Keycloak JWKS.
  The Compose smoke test also exercised the PostgreSQL-backed API, Prometheus scrape/query, OTel
  Collector HTTP spans, and provisioned Grafana dashboard.
- Argo CD 3.5.3 was installed in kind and synchronized the branch’s Helm golden path. The
  Application reached `Synced/Healthy` and its managed Deployment reached `1/1` available.
- A clean-room local reset removed the repository’s Compose containers, volumes, local image, and
  kind cluster. The documented bootstrap then recreated kind, Metrics Server, Argo CD, the Compose
  integration stack, the governed lifecycle demo, and Argo CD `Synced/Healthy` reconciliation.
- AWS pilot Phase 0 was applied in the dedicated pilot account: Terraform created an encrypted,
  versioned, public-access-blocked S3 state bucket, a project-scoped DynamoDB lock table, and a
  USD 10 monthly actual-cost Budget with 50/80/100% alert thresholds. No workload infrastructure
  was created.
- A bounded AWS workload pilot created the tagged VPC, private EKS cluster, two `t3.large` CPU
  nodes, RDS PostgreSQL, ECR repository/image, Secrets Manager container, OIDC providers, and
  scoped IAM roles through Terraform. Argo CD reached `Synced/Healthy` for the ECR-hosted control
  plane, OPA, Keycloak, and OTel Collector.
- The EKS runtime accepted a Keycloak-issued RS256 JWT, rejected a cross-tenant request through
  live OPA with a persisted audit trail, retained that rejected state after a control-plane restart,
  and exposed live Prometheus metrics, Tempo traces, and the provisioned Grafana dashboard.

## Implemented but Not End-to-End Validated

- No primary local control-loop capability is awaiting end-to-end validation.

## Simulated

- Cost estimates.
- Header identity is available only through an explicit local-development opt-in.

## Architecture / Contracts Only

- Durable worker reconciliation, external secret delivery/workload identity, and delegated MCP
  OIDC identity.

## Explicitly Unexecuted Production Adapters

- GitHub Actions OIDC federation. The manual plan/apply/destroy workflow and role are implemented,
  but no GitHub-hosted OIDC workflow run has yet been executed.
- Enterprise OIDC issuer, protected environment repository, and production GitOps commit/PR flow.
- Multi-cluster placement, HA/failover validation, GPU nodes, and cloud billing evidence.

See [the production-pilot plan](docs/production-pilot.md) for scoped delivery gates and evidence
requirements. These are not local-first completion blockers and have not been started.

## Known Failures

- The first golden-path release failed because its read-only filesystem had no writable `/tmp`; the
  chart now supplies an `emptyDir` mount and the corrected release reached Ready. This failure was
  local-only and no longer reproduces.

## Current P0 Objective

No open local-first P0 work. The bounded cloud pilot is torn down; its observed cost was not
recorded. GitOps publication, a durable reconciler, external secrets/workload identity, and GitHub
Actions OIDC execution remain later P1 work.

## Last Validation

- `.venv/bin/python -m pytest -q`: 26 passed (2 upstream TestClient deprecation warnings).
- Local Compose: Keycloak bearer token → FastAPI `/api/v1/catalog`: `200`.
- `make compose-smoke`: Keycloak token, FastAPI catalog authorization, PostgreSQL state, Prometheus
  query, OTel Collector HTTP span, and Grafana dashboard assertions passed.
- Prometheus query `sum(platform_requests_total)`: returned `1`; Collector logs contained
  `GET /api/v1/catalog` spans with `service.name=ai-platform-control-plane`; Grafana dashboard API
  returned the provisioned `AI Platform Control Plane` dashboard.
- `.venv/bin/python -m ruff check control-plane/src control-plane/tests cli/src scripts/demo-local.py`: passed.
- `opa test platform/policies tests/policy`: 1/1 passed with OPA 1.20.2.
- `helm lint platform/helm/golden-path`: passed.
- `terraform -chdir=... validate`: host provider-schema loader failed on macOS; the same locked
  configuration passed `hashicorp/terraform:1.9.8` Linux-container validation after adding its
  verified Linux ARM64 provider checksum.
- `PLATFORM_RECONCILER=kind ... EnvironmentService.create(...)`: Deployment reached Ready in kind.
- `PLATFORM_RECONCILER=kind ... EnvironmentService.destroy(...)`: namespace deletion verified.
- FastAPI on `127.0.0.1:8001` + OPA container + kind: API-created Deployment reached `READY`, audit
  timeline was retrieved, OPA denied autonomous production, and API destroy removed the namespace.
- `PLATFORM_RECONCILER=kind ... expire_due(...)`: TTL workload cleanup and namespace deletion verified.
- `PLATFORM_RECONCILER=kind ... create(image=busybox:1.36)`: unhealthy workload reached `FAILED` and
  recorded `reconciliation.failed` before cleanup.
- `make demo-local`: passed with signed JWT, OPA, kind, audit, metrics, dev destroy, autonomous-agent
  denial, independent production apply approval, and independent protected-destroy approval.
- `docker build -f control-plane/Dockerfile -t ai-platform-control-plane:week1 .` plus non-root
  container `/healthz`: passed.
- `PLATFORM_RECONCILER=kind ... recover_pending(...)`: persisted `APPLYING` workload reconciled once
  after restart; subsequent recovery was a no-op and namespace cleanup was verified.
- `ARGOCD_TARGET_REVISION=codex/week-01-platform-control-plane make argocd-demo`: Argo CD 3.5.3
  synchronized the golden path and observed Application `Synced/Healthy` plus a `1/1` Deployment.
- Clean-room workflow: `make clean-local`; `make bootstrap-local`; `make compose-smoke`; `make
  demo-local`; and `make argocd-demo`. The first command removed only Project 1 resources. The
  rebuilt stack passed direct API/Keycloak/Prometheus/Grafana/OTel assertions, the governed
  lifecycle demo, and Argo CD `Synced/Healthy` verification.
- AWS Phase 0: `scripts/bootstrap-pilot-guardrails.sh` authenticated the expected pilot account,
  initialized remote Terraform state, imported the secure backend resources, and applied only
  `ai-platform-control-plane-pilot-monthly-cost`. AWS API verification confirmed AES256 bucket
  encryption, versioning enabled, active lock table, zero current budget spend, and 50/80/100%
  actual-cost notifications. No VPC/EKS/RDS/ECR/NAT/workload resources were created.
- AWS foundation implementation: `AWS_PROFILE=ai-platform-pilot-key make pilot-cloud-plan` produced
  a reviewed **38 to add, 0 to change, 0 to destroy** plan, without applying it. Terraform validate,
  Kustomize rendering, shell syntax checks, 29 Python tests, Ruff, and Helm lint passed.
- AWS workload pilot: Terraform applied the reviewed foundation; EKS reported two Ready CPU nodes,
  ECR returned the immutable `pilot` image digest, and Argo Application
  `ai-platform-control-plane-runtime` reported `Synced Healthy`.
- `AWS_PROFILE=ai-platform-pilot-key make pilot-cloud-smoke`: passed for the EKS runtime, Argo,
  control plane, OPA, Prometheus, Grafana, and metrics endpoint.
- `AWS_PROFILE=ai-platform-pilot-key make pilot-cloud-validate`: passed signed Keycloak JWT,
  live cross-tenant OPA denial/audit, RDS-backed control-plane restart recovery, Prometheus target
  scrape, Tempo trace search, and Grafana dashboard discovery. No environment workload was claimed:
  the cloud runtime deliberately uses the documented `render-only` adapter.
- AWS pilot teardown: the EKS cluster was manually deleted during owner review; the guarded
  `make pilot-cloud-destroy` then completed the remaining Terraform cleanup. Post-destroy AWS API
  checks found no tagged pilot workload resources, no EKS/RDS/ECR/secret/IAM/VPC resources, and
  zero resources in the pilot Terraform state. The encrypted state bucket, lock table, and USD 10
  Budget alert remain intentionally retained as Phase 0 guardrails.

## Last Updated

2026-10-02, bounded AWS workload pilot executed, validated, and torn down. Local-first completion
status is unchanged.
