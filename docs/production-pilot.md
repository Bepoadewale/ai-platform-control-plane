# Production pilot plan

This repository is **PORTFOLIO COMPLETE — LOCAL-FIRST SCOPE**. Its governed lifecycle is executed
locally with kind, Keycloak, OPA, PostgreSQL, Argo CD, Prometheus, Grafana, and OpenTelemetry.
That does not constitute an AWS production deployment.

This document defines the separate, budget-bounded AWS pilot and records its current evidence
boundary. The foundation and runtime validation below ran on 2026-10-02; unfinished phases remain
plans, not implied production capability.

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
| 0. Pilot guardrails | Dedicated AWS account, budget alarms, tags, remote Terraform state, break-glass process, destroy plan | **Executed 2026-10-02:** account guard, encrypted/versioned state, lock table, tags, and USD 10 alerts. No workload deployed; see `docs/VALIDATION.md`. |
| 1. Identity and CI | GitHub Actions OIDC roles with least privilege; no long-lived AWS keys | **Implemented, not executed:** manual `plan`/`apply`/`destroy` workflow is branch-bound and confirmation-gated; record a real OIDC run before claiming it executed. |
| 2. Foundation | Terraform creates VPC, private EKS subnets, EKS, ECR, RDS PostgreSQL, ECR, and narrowly scoped IAM | **Executed and torn down 2026-10-02:** two bounded pilots applied the foundation and ran two Ready CPU nodes. The first EKS cluster was manually deleted during owner review; the second used the guarded Terraform destroy. Post-destroy checks found zero Terraform workload resources. Observed cost remains unrecorded. |
| 3. Platform runtime | Control plane, OPA, Argo CD, observability, and external-secret delivery run in EKS | **Partially executed and torn down 2026-10-02:** Argo-synchronized control plane, OPA, Keycloak, hardened Operator Console, OTel, Prometheus, Grafana, and Tempo passed health/policy/restart/telemetry checks. The Console's loopback-only port-forward completed Keycloak PKCE login/logout and a signed API request. Bootstrap-only Kubernetes secret delivery was used; external secrets/workload identity remain pending. |
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

## Architecture changes required before production-shaped expansion

1. Apply the reviewed deployable Terraform foundation in one AWS region and a minimal
   non-production EKS footprint; do not add multi-cloud or GPU nodes.
2. Wire the implemented GitHub App desired-state publisher into durable worker reconciliation. It
   creates a branch and protected pull request; it does not run Helm, kubectl, or Terraform.
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

The exact guarded commands, GitHub Actions dropdown workflow, runtime boundary, and teardown
procedure are in [the AWS pilot runbook](cloud-pilot-runbook.md).
