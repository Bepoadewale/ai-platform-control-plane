# Validation

Baseline: `make test`, `make lint`, `make demo`; when tools exist, `make helm-lint` and `make terraform-validate`.

## Clean-room local validation — 2026-09-20

Environment: macOS with Docker Desktop, kind, kubectl, Helm, OPA, Terraform, Python 3.14, and
no cloud credentials. The local cluster and Compose stack were deliberately removed before this
validation:

```console
make clean-local
make install
make bootstrap-local
make compose-smoke
make demo-local
make argocd-demo
```

`make clean-local` removed only this repository's Compose containers, named volumes, locally built
image, and `ai-platform-local` kind cluster. `make bootstrap-local` recreated kind using
`kindest/node:v1.34.0`, Metrics Server chart `3.14.0`, and Argo CD chart `10.9.2` (Argo CD 3.5.3).
The Compose stack recreated Keycloak, OPA, PostgreSQL, the control plane, OTel Collector,
Prometheus, and Grafana.

Executed evidence:

- Keycloak issued a local bearer token accepted by the FastAPI catalog endpoint.
- Prometheus returned a non-zero `sum(platform_requests_total)` result.
- Grafana returned the provisioned `AI Platform Control Plane` dashboard.
- OTel Collector logs contained `GET /api/v1/catalog` spans.
- `make demo-local` exercised signed JWT → OPA → FastAPI → Helm/kind readiness → audit/metrics →
  destroy, production-agent policy denial, independent production approval, and protected destroy.
- `make argocd-demo` completed with Argo CD Application `Synced Healthy`; the managed deployment
  had `1/1` available replicas.

The smoke script uses bounded readiness retries because a newly recreated API or Keycloak container
can accept its port before it is ready to serve. `COMPOSE_SKIP_UP=1 ./scripts/compose-smoke.sh` is
an internal reuse option for validating already-started services; documented users should run
`make compose-smoke`.
