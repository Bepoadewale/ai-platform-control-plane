# Optional AWS deployment

AWS is opt-in and **not executed as a workload deployment by this repository today**. The pilot
Terraform foundation is deployable and has an AWS-backed plan; it creates no AWS resources unless a
guarded apply command is explicitly run. `make terraform-validate` and `make pilot-cloud-plan` are
not deployment tests.

The reviewed pilot foundation supplies VPC/private EKS subnets, EKS, ECR, RDS PostgreSQL, an empty
Secrets Manager container, and branch-bound GitHub OIDC roles. External Secrets plus workload
identity is intentionally deferred until after the short pilot runtime. Use encrypted/locked remote
Terraform state, required resource tags, budget alarms, and the explicit destroy procedure. CI must
authenticate with GitHub OIDC and a scoped AWS role; never commit or configure long-lived AWS keys.

The first pilot must record reviewed `plan`, explicit `apply`, smoke, failure, rollback, cost review,
and `destroy` evidence before AWS can be described as executed. Do not enable GPU nodes, NAT-heavy
topologies, multi-region, or production data by default. See [production-pilot.md](production-pilot.md).

## Phase 0: account guardrails — executed 2026-10-02

The tracked bootstrap at `infrastructure/terraform/bootstrap/` creates only project-scoped pilot
guardrails: a USD 10 monthly actual-cost alert budget (50/80/100% notifications), encrypted and
versioned S3 Terraform state, a DynamoDB state-lock table, and mandatory tags. It deliberately does
not create VPC, EKS, EC2, RDS, NAT Gateway, ECR, or workloads. It requires a locally installed
Terraform CLI and AWS CLI profile; it does not mount credentials into a container.

Bootstrap the encrypted remote state and inspect the budget plan with a local AWS profile and an
alert recipient, never a committed value. This command creates only the state bucket and lock table;
it does not create the budget or workload infrastructure:

```bash
PILOT_BUDGET_EMAIL='your-alert-email@example.com' make pilot-guardrails-bootstrap
```

After reviewing the plan, apply only to the expected pilot account:

```bash
PILOT_BUDGET_EMAIL='your-alert-email@example.com' make pilot-guardrails-apply
```

AWS Budgets alerts are not a guaranteed hard spending stop. They are an early warning; paid pilot
resources must still be intentionally created, monitored, and destroyed. Keep the bootstrap change
in a reviewed branch and apply only to the explicitly checked pilot account.

The first execution created only this Phase 0 state/budget boundary. It did **not** create VPC, EKS,
RDS, ECR, NAT Gateway, Secrets Manager, workloads, GitHub OIDC, or an AWS Argo deployment. See
[validation evidence](VALIDATION.md#aws-pilot-phase-0--2026-10-02).

## Pilot implementation — not executed

The full command sequence is documented in [cloud-pilot-runbook.md](cloud-pilot-runbook.md):

```bash
make pilot-cloud-plan
make pilot-cloud-apply
make pilot-cloud-push-image
make pilot-cloud-bootstrap-runtime
make pilot-cloud-smoke
make pilot-cloud-destroy
```

`pilot-cloud-apply` and `pilot-cloud-destroy` require explicit confirmation environment variables
through their Make targets, reject an unexpected AWS account, and keep Terraform plans outside the
repository. The manual `aws-pilot-terraform` GitHub Actions workflow offers the same future
`plan`/`apply`/`destroy` selection through a dropdown and confirmation field. It has not been run.
