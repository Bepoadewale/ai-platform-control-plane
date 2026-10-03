# AWS pilot runbook

This is the controlled **create → validate → destroy** procedure for the non-production AWS pilot.
It is not a routine local-development command or a production-certification procedure. It creates
billable resources and must be run only in the dedicated account, with the USD 10 Budget alerts
already confirmed. A successful run is **CLOUD-PILOT VALIDATED**, not production-certified.

## Boundaries

- Account: the account configured in `EXPECTED_AWS_ACCOUNT_ID`; scripts reject any other account.
- Region: `us-east-1` by default.
- Scope: the `ai-platform-control-plane-pilot` VPC, EKS cluster, RDS instance, ECR repository,
  empty GitOps-publisher secret container, and pilot IAM roles only.
- Retained after teardown: the Phase 0 remote-state bucket, DynamoDB lock table, and Budget alert.
- No AWS access key belongs in GitHub. GitHub Actions assumes the branch-bound OIDC role.
- No GitHub App private key belongs in Terraform state, Git, application logs, or a pull request.

## Prerequisites

Install Docker Desktop, AWS CLI v2, Terraform, `kubectl`, Helm, `jq`, `curl`, and OpenSSL. Configure
an AWS CLI profile locally; it is used only by local operator scripts and never committed.

Run the safe, non-mutating checks first:

```bash
make pilot-guardrails-bootstrap
make pilot-cloud-plan
```

Review the entire plan. The foundation uses two CPU-only `t3.large` EKS nodes, one NAT gateway, and
one `db.t3.micro` PostgreSQL instance. It does not provision GPUs, load balancers, or public app
endpoints. The intended pilot window is short; Budget alerts are notifications, not a spending cap.

The node group intentionally does not wait for the CoreDNS add-on: CoreDNS cannot become healthy
until schedulable nodes exist, so that dependency would create a startup deadlock.

The cloud OPA manifest mounts its Rego policy as one file rather than a ConfigMap directory. This
avoids the ConfigMap `..data` symlink tree being recursively loaded by OPA as duplicate policies.

## Create and validate

```bash
make pilot-cloud-apply
make pilot-cloud-push-image
make pilot-cloud-put-gitops-secret
make pilot-cloud-bootstrap-runtime
make pilot-cloud-smoke
make pilot-cloud-validate
make pilot-cloud-console-validate
```

`pilot-cloud-put-gitops-secret` places the locally held GitHub App credential directly into the
project-scoped Secrets Manager entry through the AWS CLI. It never prints the key or passes it to
Terraform. `pilot-cloud-bootstrap-runtime` installs External Secrets with an IRSA role limited to
that secret, waits for the namespace-local worker Secret, then starts the API, GitOps worker and
read-only status observer. The separate RDS bootstrap secret remains a short-lived pilot compromise;
no secret value is committed or stored in Terraform state.

The runtime starts the control plane, OPA, Keycloak, and an OpenTelemetry Collector under Argo CD.
Use port forwarding for inspection; the pilot does not create a public load balancer:

```bash
kubectl -n platform-system port-forward service/control-plane 8000:8000
kubectl -n argocd port-forward service/argocd-server 8080:443
```

After the runtime smoke test passes, use a temporary public review URL if needed:

```bash
make pilot-cloud-public-demo
```

For a short-lived, authenticated review of the real EKS-hosted Operator Console, use:

```bash
make pilot-cloud-console-public-demo
```

This starts only local port-forwards, a same-origin local proxy, and a Cloudflare Quick Tunnel. It
temporarily adds that exact `trycloudflare.com` origin to the synthetic pilot Keycloak client, then
restores the original client configuration when the command exits. It does not create AWS ingress,
DNS, TLS, a load balancer, or a persistent public endpoint. Do not use it with non-synthetic data.

It exposes only a local `kubectl port-forward` through an unauthenticated Cloudflare Quick Tunnel,
prints a temporary `/docs` URL, and creates no AWS load balancer or DNS resource. Keep it open only
while reviewing disposable pilot data. `Ctrl-C` closes the tunnel and local port-forward; it does
**not** destroy the AWS pilot. Run `make pilot-cloud-destroy` only after the owner has confirmed the
public review is complete.

`pilot-cloud-validate` runs the bounded signed-JWT, live OPA cross-tenant denial/audit, RDS restart
recovery, Prometheus target/query, Tempo trace, and Grafana dashboard checks. The real lifecycle
exercise is separate and uses GitHub pull requests deliberately:

```bash
PILOT_RUNTIME_REVISION=codex/production-shaped-single-account make pilot-cloud-bootstrap-runtime
make pilot-cloud-gitops-lifecycle
# Review the printed GitOps pull request, then continue with the exact environment UUID it prints.
# The second command performs the explicit merge:
PILOT_GITOPS_ENVIRONMENT_ID=<environment-id> MERGE_GITOPS_CHANGE=<environment-id> make pilot-cloud-gitops-lifecycle
```

The lifecycle command proves API intent → durable worker → GitHub PR → merged desired state →
Argo ApplicationSet → private EKS workload → read-only observer → Git deletion PR → Argo prune.
It uses a disposable development environment and requires an explicit reviewed merge; it does not
give the API or worker Kubernetes mutation authority. Record all observed evidence in
`docs/VALIDATION.md` before teardown.

To inspect the EKS-hosted authenticated Operator Console without creating a public AWS endpoint:

```bash
make pilot-cloud-console
```

The helper prints `http://localhost:18083` and forwards the Console, API, and Keycloak services to
loopback only. `make pilot-cloud-console-validate` validates the Console's Keycloak PKCE
login/logout, explicit API CORS policy, and signed API request against EKS.

## GitHub Actions future operation

`aws-pilot-terraform` is a manual GitHub Actions workflow with an **action** dropdown:

- `plan`: creates no resources.
- `apply`: requires `confirmation=APPLY` and the Terraform OIDC role ARN output.
- `destroy`: requires `confirmation=DESTROY` and the same role ARN.

The role is restricted to the repository and `codex/production-pilot-roadmap` ref. It is for a
reviewed pilot only, not an unattended production deployer. Its state access is scoped to the
project's Terraform S3 prefix and DynamoDB lock table. Before using it, apply the foundation
locally once, copy `github_terraform_role_arn` from Terraform output, and inspect the role policy.

## Teardown and verification

```bash
make pilot-cloud-destroy
```

The command refuses to proceed unless `DESTROY_CLOUD_PILOT` is set by the Make target. It destroys
only Terraform-managed workload resources, then asserts that the named EKS cluster and RDS instance
are absent. Independently review the AWS console for remaining project-tagged resources and record
the result. Never use account-wide `aws ... --all`, `terraform destroy` from another directory, or
Docker/Kubernetes prune commands as pilot cleanup.

## Known pilot limits

- The GitOps worker, External Secrets contract, ApplicationSet and read-only status observer are
  implemented and locally tested. Their complete AWS lifecycle is not claimed until the documented
  disposable create → PR → merge → Ready → deletion → destroy run is recorded.
- Prometheus, Grafana, and Tempo have been exercised in the bounded pilot. Their storage is
  deliberately ephemeral and their charts are not a production HA/retention design.
- GitHub App private-key storage and External Secrets/Pod Identity are intentionally not claimed as
  executed by this bootstrap path.
