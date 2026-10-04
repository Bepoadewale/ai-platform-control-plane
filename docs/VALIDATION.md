# Validation

**Evidence boundary:** this document records historical local execution and the completed bounded
AWS pilot. The cloud entries establish **PRODUCTION-PILOT COMPLETE — EPHEMERAL SINGLE-ACCOUNT
SCOPE**; consult [Production Evolution](production-evolution.md) for unexecuted enterprise/public-
SaaS improvements.

The AWS pilot is the primary deployment evidence. Earlier local entries remain as historical
contributor-harness reproducibility evidence and do not substitute for cloud validation.

## Optional public ALB ingress — 2026-10-04

Environment: the disposable `us-east-1` AWS pilot, Terraform 1.14.0, EKS, AWS Load Balancer
Controller chart `3.5.0`, and only synthetic Keycloak identities. The optional flag was enabled
explicitly; no domain, certificate, or public HTTPS claim was involved.

Commands executed:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-public-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-public-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> PILOT_RUNTIME_REVISION=codex/public-alb-ingress \
  make pilot-cloud-public-bootstrap
AWS_PROFILE=<operator-profile> make pilot-cloud-public-smoke
```

Observed evidence:

| Evidence | Result |
| --- | --- |
| Terraform public option | The reviewed plan added the controller's namespace-bound IRSA role and version-pinned policy. `public_alb_enabled=true` was explicit; the default remains false. |
| Public entry point | The AWS Load Balancer Controller created one named internet-facing ALB from three `platform-system` Ingresses. It routed `/` to the Console, `/api` and `/healthz` to the API, and `/realms`/`/resources` to Keycloak. |
| Exact browser boundary | Bootstrap wrote the generated ALB HTTP origin into the project ConfigMap and Keycloak client. The issuer matched that exact origin; no wildcard redirect URI or CORS origin was used. |
| Browser identity | The repeatable public smoke completed Keycloak Authorization Code + PKCE sign-in, token exchange, signed API request, and logout. It did not print a token or password. |
| Browser compatibility | The Console does not assume `crypto.randomUUID()` or `crypto.subtle` exists. It retains `crypto.getRandomValues()` for verifier randomness and has a tested local SHA-256 fallback for the PKCE challenge at the HTTP-only pilot origin. |
| Public safety checks | `/healthz` returned 200; an unauthenticated `/api/v1/environments` request returned 401; `/metrics`, Prometheus, Grafana, Tempo, Argo CD, RDS, and Kubernetes APIs were not routed by the public Ingress. |
| Failover | The smoke deleted one ready API Pod through Kubernetes. The ALB health endpoint remained available and the API Deployment returned to `2/2`. |
| Scope | This is a temporary HTTP pilot with an AWS-generated DNS name. Trusted HTTPS requires a controlled domain and ACM/DNS validation; enterprise identity requires a real enterprise IdP. |

The public ALB remains live only for owner review at the time of this record. The guarded destroy
removes its three namespace-scoped Ingresses, waits for the named ALB, and then destroys the
Terraform-managed EKS/VPC footprint.

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

## Operator Console local smoke — 2026-10-02

`make compose-smoke` rebuilt the Compose control plane and confirmed all of the following:

| Evidence | Result |
| --- | --- |
| Console runtime | Nginx console served `http://localhost:4173/healthz` and its sign-in landing page |
| Browser identity configuration | Local Keycloak completed the console Authorization Code + PKCE login/callback/token exchange and Keycloak logout redirect for the configured callback URL |
| API browser boundary | FastAPI returned an explicit CORS allow-list response for `http://localhost:4173`; wildcard CORS is not configured |
| API authorization | A local Keycloak bearer token reached `/api/v1/catalog` successfully |
| Existing service evidence | PostgreSQL-backed API, OTel Collector span, Prometheus query, and Grafana dashboard assertions passed |

This records a service-level smoke test, not a completed human browser login. The console's local
fixture, production boundary, and manual sign-in steps are in [Operator Console](operator-console.md).

## AWS workload pilot — 2026-10-02 (create/validate/destroy)

Environment: macOS; AWS CLI v2; Terraform 1.14.0; AWS provider 5.100.0; EKS Kubernetes 1.35;
Argo CD chart 10.9.6 / application 3.5.3; Prometheus chart 29.35.0 / application 3.15.0; Grafana
chart 10.5.15 / application 12.3.1; Tempo chart 1.24.4. The pilot ran only in the dedicated,
budget-alerted account and region. No credentials, token values, database password, or public
temporary review URL are recorded here.

Commands executed:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
AWS_PROFILE=<operator-profile> make pilot-cloud-validate
AWS_PROFILE=<operator-profile> make pilot-cloud-destroy
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
| Public review | a temporary owner-review proxy exposed only a local `kubectl port-forward`; no public AWS load balancer or DNS record was created |
| Environment workload success / GitOps publication | Not executed: the cloud runtime intentionally uses `render-only`; individual API environment requests do not yet become protected Git changes or Argo-managed workloads |
| Observed cost during pilot | Not recorded in real time; the USD 10 Budget remains an alert, not a hard cap |
| Terraform destroy / post-destroy query | The EKS cluster was manually deleted during owner review. `make pilot-cloud-destroy` completed the remaining Terraform cleanup: 38 resources destroyed. Post-destroy AWS API checks found EKS, RDS, ECR, the GitOps secret, pilot IAM roles, tagged VPC resources absent; Terraform pilot state contained zero resources. |
| Retained Phase 0 guardrails | Encrypted/versioned remote-state bucket, active DynamoDB lock table, and `ai-platform-control-plane-pilot-monthly-cost` Budget intentionally retained. Their two DynamoDB MD5 entries are Terraform backend bookkeeping, not workload locks. |

The current cloud procedure and security boundaries are in [Cloud Operations](cloud-operations.md).

## AWS Operator Console and governed lifecycle — 2026-10-02 (create/validate/destroy)

The second bounded pilot reused the reviewed Terraform foundation after a graceful local Terraform
interrupt tainted only CoreDNS; Terraform then replaced that add-on and returned a consistent state.
After the recorded validation, the guarded destroy completed and the workload footprint was
independently queried as absent.

Commands executed:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
AWS_PROFILE=<operator-profile> make pilot-cloud-validate
AWS_PROFILE=<operator-profile> make pilot-cloud-console-validate
AWS_PROFILE=<operator-profile> make pilot-cloud-console
AWS_PROFILE=<operator-profile> make pilot-cloud-destroy
```

Observed evidence:

| Evidence | Result |
| --- | --- |
| Argo and runtime readiness | Application `ai-platform-control-plane-runtime` was `Synced Healthy`; control plane, Keycloak, OPA, Operator Console, and OTel Collector each had one available replica. |
| Cloud Operator Console | EKS-hosted hardened Nginx Console was served at loopback `http://localhost:18083`; the validation completed Keycloak Authorization Code + PKCE login/callback/token exchange/logout, explicit CORS preflight, and a signed API request. No public AWS endpoint was created. |
| Development lifecycle | A tenant-scoped development request reached `READY` through the cloud runtime's deliberately `render-only` adapter, then API destroy reached `DESTROYED`. Its audit contained `environment.requested`, `policy.evaluating`, `environment.planned`, `gitops.rendering`, `environment.ready`, `destroy.requested`, `destroy.applying`, and `destroy.complete`. No environment namespace or workload was created; real per-environment GitOps publication remains unexecuted. |
| Protected production lifecycle | A developer production request became `APPROVAL_REQUIRED` with an immutable plan. A developer approval attempt returned `403` because it lacked the platform-operator role. The distinct operator approved the exact apply plan, then the exact destruction plan; final state was `DESTROYED`. |
| Policy denial | A development request with `privileged=true` became `REJECTED` with `privileged containers are prohibited`; its audit contained `environment.requested`, `policy.evaluating`, and `policy.rejected`. Querying all EKS Deployments/Services found no workload with that request name. |
| Metrics and traces | API metrics showed two successful creates, one rejected create, and one policy denial. Prometheus reported its `control-plane` target `up` and `sum(platform_requests_total)=10`; Tempo returned 20 control-plane traces; Grafana returned the provisioned `AI Platform Control Plane` dashboard. |
| Guarded teardown | `make pilot-cloud-destroy` destroyed the 38 Terraform-managed workload resources. AWS API queries confirmed the EKS cluster, RDS instance, ECR repository, VPC, pilot IAM roles, EKS OIDC provider, Secrets Manager objects, and pilot security-group rule absent; pilot Terraform state listed zero resources. The NAT gateway's historical AWS record reported `deleted`. Only the encrypted state bucket, DynamoDB lock table, and USD 10 Budget remain intentionally. |

This is runtime/governance evidence, not a claim that an individual request reconciled to an EKS
workload. The cloud adapter is intentionally `render-only`; the local kind path remains the
executed workload-readiness demonstration.

## AWS production-shaped GitOps, Console, and failure evidence — 2026-10-03

Environment: private, disposable EKS pilot in `us-east-1`; synthetic Keycloak identities and
disposable tenant workloads only. No credentials, secret values, or temporary review URL are
recorded.

| Evidence | Result |
| --- | --- |
| Successful GitOps lifecycle | An approved development request created a GitHub App pull request. After normal checks and merge, Argo ApplicationSet created a private workload whose Deployment reached `1/1` available. A merged deletion pull request removed the desired-state directory; Argo pruned the generated Application and namespace; the API reported `DESTROYED`. |
| Earlier failed test cleanup | The older `cloud-gitops-demo` desired-state directory was removed in a dedicated reviewed GitOps PR after its durable record was found absent. Argo pruned the remaining Application and namespace; no direct `kubectl delete` was used. |
| Authenticated Console review | `make pilot-cloud-console-validate` completed Keycloak Authorization Code + PKCE sign-in/logout and a signed API request. A temporary same-origin owner-review proxy was used; Keycloak’s exact temporary client origin and login theme were verified. No AWS ingress, DNS, or load balancer was created. |
| Failure drill | A development request with `registry.invalid/ai-platform-control-plane:missing` was published and merged through GitOps. Its Pod reached `ImagePullBackOff`; the Deployment reached `ProgressDeadlineExceeded` after a temporary 60-second deadline; the observer stored `FAILED` with the Kubernetes reason. |
| Failure cleanup | The standard destroy request published a reviewed deletion PR. After merge and ApplicationSet refresh, Argo pruned the failure Application and namespace. The durable API state became `DESTROYED`; audit includes request, reconciliation failure, GitOps PR creation, destroy request, and destroy completion. |
| Final cloud smoke | After restoring the declared GitOps runtime to `Synced/Healthy`, `AWS_PROFILE=ai-platform-pilot-key make pilot-cloud-smoke` passed for EKS, Argo, control plane, Operator Console, OPA, Prometheus, Grafana, and the metrics endpoint. |
| Guarded teardown | `AWS_PROFILE=ai-platform-pilot-key make pilot-cloud-destroy` removed the active Terraform workload footprint. Direct post-destroy queries found EKS, RDS, ECR, five pilot IAM roles, project-tagged VPCs, and pilot GitOps secrets absent; the configured remote pilot Terraform state listed zero resources. The encrypted/versioned state bucket, active DynamoDB lock table, and USD 10 budget remain intentionally. |

This is production-shaped single-account evidence, not enterprise/public-SaaS certification. Enterprise identity,
quality rollback, sustained-load/SLO/error-budget/alert policy, secret rotation, and cost measurement
remain explicitly unexecuted.

## AWS resilience and hosted-OIDC pilot — 2026-10-03

| Evidence | Result |
| --- | --- |
| API, policy, and worker availability | EKS ran two `control-plane`, two `opa`, and two `gitops-worker` Pods. Project-scoped PDBs set `minAvailable: 1`. |
| Scoped pod-loss recovery | `make pilot-cloud-ha-check` ran twice. Each pass deleted one ready API Pod and one ready worker Pod; health remained available and both Deployments returned to `2/2` available. |
| Durable worker ownership | The worker now performs an atomic PostgreSQL `PENDING → PROCESSING` claim. A two-worker test passed, and a bounded abandoned lease can requeue safely with the same GitHub change id. |
| Bounded authenticated load | `PILOT_LOAD_REQUESTS=20 PILOT_LOAD_CONCURRENCY=4 make pilot-cloud-load-slo` passed. Prometheus observed `44.97832` successful catalog requests in the two-minute query window, exceeding the requested sample. This is not a sustained-load or SLO certification. |
| GitHub-hosted OIDC | [Run 37116545362](https://github.com/Bepoadewale/ai-platform-control-plane/actions/runs/37116545362) passed: GitHub Actions received short-lived AWS credentials, verified the expected account, initialized remote state, and completed Terraform plan. No GitHub AWS access key was used. |

Hosted Terraform apply/destroy, a quality rollback, alert firing, measured error-budget policy, AWS
Cost Explorer evidence, enterprise OIDC, and trusted public AWS TLS ingress remain unexecuted.

## AWS HA, alert, rollback, and hosted-OIDC extension — 2026-10-04

This extension reused the disposable private EKS pilot. It remains cloud-pilot evidence, not a
enterprise/public-SaaS certification or a claim of a public service.

| Evidence | Result |
| --- | --- |
| GitHub-hosted Terraform OIDC apply | A protected GitHub Actions run assumed the branch-bound AWS role using short-lived credentials and completed the reviewed Terraform apply. No GitHub AWS access key was used. The hosted destroy action remains confirmation-gated and unexecuted. |
| HA / pod-loss | `make pilot-cloud-ha-check` verified two API, two OPA, and two worker replicas plus `minAvailable: 1` PDBs, deleted one ready API Pod and one worker Pod, and observed both Deployments return to `2/2` available. |
| Bounded load | `PILOT_LOAD_REQUESTS=20 PILOT_LOAD_CONCURRENCY=4 make pilot-cloud-load-slo` completed 20 authenticated catalog requests at concurrency four. Prometheus observed 160 successful requests in the two-minute query window. This is a bounded sample, not a sustained throughput or capacity claim. |
| Alert / availability signal | `make pilot-cloud-slo-alert-check` issued 20 invalid bearer requests, observed the firing `PilotUnauthorizedRequestBurst` alert, and returned catalog two-minute availability `1`. No external alert receiver or error-budget policy was configured. |
| GitOps rollback | `make pilot-cloud-rollback-check` published reviewed create, bad-image, restore, and destroy changes. Kubernetes recorded `ProgressDeadlineExceeded` for the bad image; the reviewed restore reached Ready; governed deletion then pruned the namespace. This is deployment-health rollback/cleanup, not model-quality rollback. |
| Cost Explorer | `make pilot-cloud-cost-evidence` queried 2026-10-01 through 2026-10-03. It returned estimated zero/empty groups while AWS billing remained within its documented 24–48-hour delay. This is not a zero-cost claim or settled cost evidence. |
| Historical Console review | The EKS Operator Console was exposed only through a short-lived local same-origin proxy over `kubectl port-forward`. Keycloak allowed only the temporary origin for that session; no AWS public ingress, DNS, or load balancer was created. |

At the time of this record, enterprise identity, trusted public TLS ingress, model/quality rollback,
sustained-load/error-budget evidence, backup/restore, settled AWS billing data, and the hosted
Terraform destroy action remain unexecuted.

## Final AWS cloud-pilot teardown — 2026-10-04

After the temporary Console review path was closed, the account-guarded command below completed:

```console
AWS_PROFILE=<operator-profile> EXPECTED_AWS_ACCOUNT_ID=<pilot-account-id> \
  DESTROY_CLOUD_PILOT=<pilot-account-id> make pilot-cloud-destroy
```

Post-destroy, direct AWS API queries returned `ResourceNotFound` for the pilot EKS cluster, RDS
instance, and ECR repository. The `ai-platform-control-plane-pilot/` Secrets Manager list, pilot
IAM-role list, and project-tagged VPC list were empty. Remote pilot Terraform state listed zero
workload resources. The encrypted/versioned state bucket, DynamoDB lock table, and USD 10 Budget
remain intentionally as Phase 0 guardrails.

The GitHub-hosted Terraform **destroy** action was not used; the local, account-guarded Terraform
destroy was the executed teardown authority. Enterprise OIDC, trusted public TLS ingress,
model/quality rollback, sustained-load/error-budget evidence, backup/restore, and settled AWS
billing data remain unexecuted.

## AWS resilience-pilot final teardown — 2026-10-03

The live final sequence completed before teardown:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
AWS_PROFILE=<operator-profile> make pilot-cloud-ha-check
AWS_PROFILE=<operator-profile> PILOT_LOAD_REQUESTS=20 PILOT_LOAD_CONCURRENCY=4 make pilot-cloud-load-slo
AWS_PROFILE=<operator-profile> DESTROY_CLOUD_PILOT=<expected-account-id> make pilot-cloud-destroy
```

The account-guarded destroy removed the 40-resource Terraform workload footprint. Direct AWS API
checks after completion returned `ResourceNotFound` for the pilot EKS cluster, RDS instance, ECR
repository, pilot IAM roles, and project-tagged VPCs; no matching pilot Secrets Manager object was
listed. Remote Terraform state contained zero workload resources. The encrypted/versioned state
bucket, active DynamoDB lock table, and USD 10 Budget remain intentionally as Phase 0 guardrails.

This records a private, ephemeral cloud-pilot teardown—not enterprise/public-SaaS certification. Quality
rollback, sustained load/SLO/error-budget/alert policy, Cost Explorer evidence, enterprise OIDC,
trusted public AWS TLS ingress, and GitHub-hosted Terraform apply/destroy remain unexecuted.

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
