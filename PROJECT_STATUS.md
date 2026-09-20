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

## Implemented but Not End-to-End Validated

- No primary local control-loop capability is awaiting end-to-end validation.

## Simulated

- Cost estimates.
- Header identity is available only through an explicit local-development opt-in.

## Architecture / Contracts Only

- AWS provisioning.

## Known Failures

- The first golden-path release failed because its read-only filesystem had no writable `/tmp`; the
  chart now supplies an `emptyDir` mount and the corrected release reached Ready. This failure was
  local-only and no longer reproduces.

## Current P0 Objective

No open P0 work. The next focused hardening item is turning the validated Compose stack into
CI-suitable smoke coverage.

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

## Last Updated

2026-09-20, clean-room local bootstrap and end-to-end validation completed.
