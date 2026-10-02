# Production pilot plan

This repository is **PORTFOLIO COMPLETE — LOCAL-FIRST SCOPE**. Its governed lifecycle is executed
locally with kind, Keycloak, OPA, PostgreSQL, Argo CD, Prometheus, Grafana, and OpenTelemetry.
That does not constitute an AWS production deployment.

This document defines the next, separate milestone: a small, budget-bounded AWS pilot that proves
the same control-plane boundary with real cloud infrastructure. It is a plan, not evidence that the
items below have run.

## Pilot outcome

```text
GitHub Actions → GitHub OIDC → Terraform → AWS account
  → VPC / EKS / RDS / ECR / Secrets Manager
  → Argo CD → control-plane workloads
  → Prometheus / Grafana / OpenTelemetry
```

The target user journey is:

```text
Developer or delegated agent
  → API / CLI / MCP
  → OIDC identity, tenant/RBAC, OPA
  → immutable plan and independent approval where required
  → signed Git commit or protected pull request
  → Argo CD reconciliation into EKS
  → readiness observation, audit, metrics, traces, estimated cost
```

The API owns intent and governance. Argo CD owns production reconciliation. The API must not run
`helm`, `kubectl`, or Terraform directly against the production cluster.

## Delivery phases and evidence gates

| Phase | Scope | Evidence required before proceeding |
| --- | --- | --- |
| 0. Pilot guardrails | Dedicated AWS account, budget alarms, tags, remote Terraform state, break-glass process, destroy plan | Account and billing controls reviewed; no workload deployed yet |
| 1. Identity and CI | GitHub Actions OIDC role with least privilege; no long-lived AWS keys | Workflow obtains short-lived credentials and can run a read-only identity check |
| 2. Foundation | Terraform creates VPC, private EKS subnets, EKS, ECR, RDS PostgreSQL, and narrowly scoped IAM/IRSA or Pod Identity | `plan`, reviewed `apply`, smoke, and `destroy` evidence recorded |
| 3. Platform runtime | Control plane, OPA, Argo CD, observability, and external-secret delivery run in EKS | Health, policy denial, secret-reference-only behavior, and telemetry evidence recorded |
| 4. GitOps lifecycle | Desired state becomes a protected Git commit/PR; Argo CD reconciles it | Plan → approval → Git change → Argo `Synced/Healthy` → EKS readiness → audit |
| 5. Reliability | Worker/reconciler separation, retries, idempotency, failure/rollback and recovery tests | API restart and worker failure do not duplicate a mutation; failed deployment remains non-ready |
| 6. Operations | Release/merge integration CI, dashboards, alerts, SLO measurement, and cost review | Measured pilot data, alert exercise, documented teardown, and post-pilot cost review |

## Non-negotiable cloud security boundaries

- GitHub Actions uses AWS OIDC federation and a narrowly scoped IAM role. Do not store
  `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in GitHub secrets.
- Separate pilot, staging, and production accounts before introducing real production workloads.
- Terraform state is remote, encrypted, versioned, access-controlled, and locked.
- EKS workloads use IRSA or EKS Pod Identity. No application Pod receives node or administrator
  credentials.
- Secret values live in AWS Secrets Manager or an equivalent external secret manager. Git desired
  state, API requests, audit records, and agents carry references, never plaintext values.
- Protected environment changes still require exact-plan, independent approval. A delegated AI agent
  cannot self-approve or mint stronger downstream authority.
- Terraform apply/destroy requires a reviewed plan, explicit environment selection, bounded tags,
  and a documented rollback or teardown path.

## Architecture changes required before a pilot can be claimed

1. Replace validate-only Terraform contracts with reviewed, deployable modules. Start with one AWS
   region and a minimal non-production EKS footprint; do not add multi-cloud or GPU nodes.
2. Add a production Git desired-state adapter. It creates a signed commit or pull request in a
   protected environment repository and records the immutable revision in the plan/audit trail.
3. Move reconciliation out of the FastAPI request process. A worker with durable job state is the
   first step; an operator/CRD design is a later evolution, not a prerequisite for the first pilot.
4. Replace development MCP identity environment variables with trusted OIDC/delegated-token
   validation. The MCP boundary remains subordinate to the control-plane authorization checks.
5. Add external secret references and workload identity. No agent or API client receives secret
   material or direct cluster credentials.
6. Emit lifecycle metrics and child spans for policy evaluation, plan creation, approval wait,
   desired-state publication, GitOps reconciliation, readiness, rollback, TTL cleanup, and failure.

## Explicit non-goals for the first pilot

- Multi-region or multi-cluster placement.
- GPU node groups, paid model APIs, or workload benchmarks.
- HA claims without measured failover testing.
- Enterprise identity-provider validation before a real enterprise issuer is available.
- A Kubernetes operator/CRD rewrite before the durable worker and GitOps lifecycle are proven.

## Evidence format

Do not change the repository maturity to production-validated after a successful Terraform apply.
Record a separate pilot validation in `docs/VALIDATION.md` with:

- commit SHA, AWS region, infrastructure and application versions;
- exact `plan`, approved `apply`, smoke, failure, rollback, and destroy commands;
- IAM role boundaries and resource tags, with no credentials or account identifiers committed;
- EKS/Argo readiness, OPA decision, audit timeline, Prometheus/Grafana/trace evidence;
- cost estimate and observed pilot spend; and
- verified Terraform teardown and remaining-resource check.

Only label an AWS component **EXECUTED** after this evidence exists. Until then it remains
**ARCHITECTURE / CONTRACT ONLY** or **PLANNED**.

