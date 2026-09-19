# Implementation Status

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
| PostgreSQL service | 🟡 Running / Not Application-Backed | Compose healthcheck passes; SQLite remains the persistence backend |
| Argo CD reconciliation | 📐 Architecture Only | valid adapter/manifests only; not run locally |
| AWS Terraform contract | 🟡 Implemented / Validated Statically | Linux-container `terraform validate`; no AWS resources created |
