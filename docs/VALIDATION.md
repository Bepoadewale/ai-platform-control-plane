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

## Future AWS workload-pilot validation template — NOT EXECUTED

Do not fill this section from a local kind run or a Terraform-only validation. When an
owner-authorized pilot occurs, record the commit SHA, AWS region, non-sensitive resource tags,
tool versions, GitHub OIDC role boundary, exact reviewed `terraform plan`/`apply`/smoke/failure/
rollback/`destroy` commands, Argo and EKS readiness evidence, OPA/audit/telemetry evidence, and
observed pilot cost. Confirm teardown by checking that only documented retained resources remain.

The required sequence and security boundaries are in [Production pilot plan](production-pilot.md).

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
