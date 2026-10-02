# AWS pilot runbook

This is the controlled **create → validate → destroy** procedure for the non-production AWS pilot.
It is not a routine local-development command. It creates billable resources and must be run only in
the dedicated account, with the USD 10 Budget alerts already confirmed.

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

## Create and validate

```bash
make pilot-cloud-apply
make pilot-cloud-push-image
make pilot-cloud-bootstrap-runtime
make pilot-cloud-smoke
```

`pilot-cloud-bootstrap-runtime` installs Argo CD and creates one short-lived Kubernetes secret from
the RDS managed secret. That is deliberately a bootstrap-only compromise for this pilot: no secret
value is committed or stored in Terraform state. EKS Pod Identity/IRSA plus External Secrets remains
a required hardening step before a long-lived deployment is claimed.

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

It exposes only a local `kubectl port-forward` through an unauthenticated Cloudflare Quick Tunnel,
prints a temporary `/docs` URL, and creates no AWS load balancer or DNS resource. Keep it open only
while reviewing disposable pilot data. `Ctrl-C` closes the tunnel and local port-forward; it does
**not** destroy the AWS pilot. Run `make pilot-cloud-destroy` only after the owner has confirmed the
public review is complete.

Record the Argo Application state, EKS deployment readiness, health endpoint, OPA denial test,
database persistence, `/metrics`, and trace output before teardown. Populate the evidence template
in `docs/VALIDATION.md` only with observed values.

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

- The runtime’s `render-only` adapter does not yet publish individual environment requests to a
  GitHub pull request and wait for their Argo reconciliation. `GitHubAppPublisher` is implemented
  and unit-tested as the narrow desired-state publication boundary; wiring it into durable worker
  reconciliation remains a required next production increment.
- Prometheus, Grafana, and Tempo run locally today. The first cloud runtime deploys OTel ingestion;
  production-grade cloud dashboard/tracing chart installation and evidence remain pending.
- GitHub App private-key storage and External Secrets/Pod Identity are intentionally not claimed as
  executed by this bootstrap path.
