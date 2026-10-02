# Optional AWS deployment

AWS is opt-in and **not executed by this repository today**. The checked-in Terraform is
validate-only: its VPC, EKS, and IAM modules are contracts and the root environment creates no AWS
resources by default. `make terraform-validate` is static validation, not a deployment test.

Before a pilot, replace these contracts with reviewed, deployable modules for one non-production
AWS account: VPC/private EKS subnets, EKS, ECR, RDS PostgreSQL, Secrets Manager references, and
least-privilege workload identity. Use encrypted/locked remote Terraform state, required resource
tags, budget alarms, and an explicit destroy procedure. CI should authenticate with GitHub OIDC and
a scoped AWS role; never commit or configure long-lived AWS access keys.

The first pilot must record reviewed `plan`, explicit `apply`, smoke, failure, rollback, cost review,
and `destroy` evidence before AWS can be described as executed. Do not enable GPU nodes, NAT-heavy
topologies, multi-region, or production data by default. See [production-pilot.md](production-pilot.md).
