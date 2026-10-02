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

## AWS workload pilot — 2026-10-02 (create/validate; teardown pending)

Environment: macOS; AWS CLI v2; Terraform 1.14.0; AWS provider 5.100.0; EKS Kubernetes 1.35;
Argo CD chart 10.9.6 / application 3.5.3; Prometheus chart 29.35.0 / application 3.15.0; Grafana
chart 10.5.15 / application 12.3.1; Tempo chart 1.24.4. The pilot ran only in the dedicated,
budget-alerted account and region. No credentials, token values, database password, or public
tunnel URL are recorded here.

Commands executed:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
AWS_PROFILE=<operator-profile> make pilot-cloud-validate
AWS_PROFILE=<operator-profile> make pilot-cloud-public-demo
```

Observed evidence:

| Evidence | Value / result |
| --- | --- |
| Date / commit | 2026-10-02; runtime application `Synced Healthy` at `38884c73816d3ce81345eec7880bbfe339a8de04` |
| AWS region / project tags | `us-east-1`; Terraform project-scoped pilot tags |
| Reviewed Terraform plan / apply | Foundation was reviewed as 38 additions, then applied; state later contained 47 managed records including provider-managed add-ons and OIDC dependencies |
| Manual GitHub Actions OIDC run | Not executed; manual confirmation-gated workflow remains an unexecuted adapter |
| EKS / nodes ready | two `cpu-pilot` `t3.large` nodes Ready |
| ECR image digest | immutable `pilot` tag: `sha256:3fc303e43d603e18a9984c3197b824e92afc437ceb85a55cb43dd73aaed21f94` |
| Argo Application sync / health | `ai-platform-control-plane-runtime`: `Synced Healthy` |
| Control-plane, OPA, Keycloak, and RDS smoke | `make pilot-cloud-smoke` passed; health, OPA, Prometheus, Grafana, and metrics endpoints were reachable |
| Signed identity / policy denial | in-cluster Keycloak issued an RS256 JWT accepted by FastAPI; a cross-tenant create reached live OPA, returned `REJECTED`, and persisted `policy.rejected` audit evidence |
| Restart or recovery scenario | control-plane Deployment restarted; the rejected environment and its audit timeline were retrieved afterward from RDS |
| Prometheus / Grafana / Tempo | Prometheus `control-plane` target reported `up` and query returned `platform_requests_total`; Grafana returned Prometheus and Tempo datasources plus the `AI Platform Control Plane` dashboard; Tempo search returned FastAPI `GET /api/v1/catalog` traces |
| Public review | temporary Cloudflare Quick Tunnel exposed only a local `kubectl port-forward`; no public AWS load balancer or DNS record was created |
| Environment workload success / GitOps publication | Not executed: the cloud runtime intentionally uses `render-only`; individual API environment requests do not yet become protected Git changes or Argo-managed workloads |
| Observed cost during pilot | Not recorded in real time; the USD 10 Budget remains an alert, not a hard cap |
| Terraform destroy / post-destroy query | Pending owner review of the temporary public URL; resources intentionally remain running |

The required sequence and security boundaries are in [Production pilot plan](production-pilot.md) and
[the AWS pilot runbook](cloud-pilot-runbook.md).

## AWS pilot Phase 0 — 2026-10-02

Environment: dedicated AWS pilot account in `us-east-1`; Terraform 1.14.0; AWS provider 5.100.0;
local IAM-user profile for initial bootstrap. No AWS credentials, account identifiers, or alert
recipient were committed.

Executed sequence:

```console
PILOT_BUDGET_EMAIL='<local recipient>' make pilot-guardrails-bootstrap
PILOT_BUDGET_EMAIL='<local recipient>' make pilot-guardrails-apply
```

The bootstrap verified the expected account before mutation, created/imported only the state
backend (S3 with AES256 encryption, versioning, ownership controls, and public-access blocking) and
the PAY_PER_REQUEST DynamoDB lock table, then stored Terraform state remotely. The reviewed apply
contained one further change: `ai-platform-control-plane-pilot-monthly-cost`, a USD 10 monthly
actual-cost Budget with 50%, 80%, and 100% notification thresholds. AWS API checks confirmed zero
current spend and all three notification records.

Not executed: VPC, EKS, EC2, RDS, ECR, NAT Gateway, Secrets Manager, Kubernetes workloads, GitHub
OIDC, application deployment, Argo reconciliation in AWS, failure/rollback, and teardown. Budget
notification delivery cannot be claimed until a threshold is reached or deliberately tested. AWS
Budgets is alerting, not a guaranteed spend stop.
