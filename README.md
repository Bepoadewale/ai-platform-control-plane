# AI Platform Control Plane

A cloud-first, governed control plane for humans and AI agents to request Kubernetes environments
without receiving AWS administrator, Kubernetes, Terraform, Git, or secret credentials.

**Delivery state:** **Production-pilot complete — ephemeral single-account scope.** The baseline
AWS reference environment was created with Terraform, validated through real EKS GitOps workflows,
and destroyed with Terraform. Every recreated cloud pilot includes the same temporary ALB
owner-review path—not a claim of a permanent public service or enterprise/public-SaaS certification.

![Executed AWS pilot architecture](docs/assets/cloud-pilot-architecture.svg)

The diagram is generated from selected [official AWS Architecture Icons](docs/assets/AWS_ICON_ATTRIBUTION.md)
and kept with its source in this repository. It shows topology; the lifecycle sequence is described
in the [cloud architecture](docs/cloud-architecture.md).

See the detailed [cloud architecture](docs/cloud-architecture.md), including AWS resources, trust
boundaries, and lifecycle sequence.

## What it allows—and prevents

| Caller | Allowed | Prevented |
| --- | --- | --- |
| Developer | Request tenant-scoped development environments and propose production changes | Cross-tenant access, direct cloud/cluster credentials, self-approval |
| Platform operator | Independently approve the exact protected plan | Approving stale/changed plans or bypassing policy |
| AI agent | Inspect catalog/audit, estimate cost, plan, and request permitted work through API/MCP | Self-approval, autonomous protected production mutation, arbitrary Terraform or `kubectl`, secret access |

Every write follows the same control loop:

```text
signed identity → tenant/RBAC → OPA → immutable plan → independent approval where required
→ durable GitOps job → protected GitHub PR → Argo CD → EKS readiness/failure
→ persistent audit, metrics, traces → governed destroy
```

The API owns intent and governance. Argo CD owns cloud reconciliation. The API does not shell out
to Helm, `kubectl`, or Terraform against EKS.

## What the AWS pilot proved

The AWS pilot proved the platform can safely manage a cloud environment from request to cleanup.

- Terraform created the AWS environment: networking, Kubernetes, database, container registry,
  secrets, access controls, and its narrow ALB entry point.
- Users signed in with secure tokens. The platform checked their team, role, and permissions
  before accepting a request.
- Policy rules could allow, deny, or require an independent approval before a sensitive change.
- Every request, plan, approval, result, and restart-safe record was stored in PostgreSQL for an
  audit trail.
- After approval, the platform created a reviewed GitHub change. Argo CD deployed it into private
  Kubernetes and confirmed that the workload became healthy.
- A deliberately broken container image was detected as unhealthy. The platform restored the
  previous working version, then safely removed the failed environment.
- Deliberately deleting platform Pods did not take the service down: Kubernetes restored the API
  and worker replicas while disruption protections preserved availability.
- Prometheus, Grafana, Tempo, and OpenTelemetry provided dashboards, traces, metrics, and a real
  alert during controlled traffic.
- The required HTTP ALB path was executed in the bounded pilot: the Console completed
  Keycloak PKCE login/logout, the API enforced signed identity, and one API-Pod loss preserved
  `/healthz`. It is not a trusted HTTPS claim.
- Terraform then removed the pilot infrastructure. Checks confirmed that the cluster, database,
  registry, secrets, roles, network, and Terraform-managed workload state were gone.

Technical evidence: [validation record](docs/VALIDATION.md) and
[implementation status](docs/IMPLEMENTATION_STATUS.md).

## Cloud operations

The pilot is intentionally not started by default. It creates billable resources only through
Terraform and only after plan review.

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
```

Run the operational drills and destroy procedure in [Cloud Operations](docs/cloud-operations.md).
The destroy command is account-guarded and removes only project-owned pilot resources.

## Current boundary and next improvements

The completed pilot does **not** claim enterprise IdP validation, trusted public TLS ingress,
model-quality rollback, sustained error-budget evidence, disaster recovery, settled AWS billing, or
GitHub-hosted destroy execution. These are deliberate next production improvements, not hidden
gaps. See [Production Evolution](docs/production-evolution.md).

## Documentation

- [Cloud architecture](docs/cloud-architecture.md) · [Cloud operations](docs/cloud-operations.md)
- [AWS ALB ingress](docs/alb-ingress.md)
- [Security model](docs/security.md) · [Agent safety](docs/agent-safety.md) · [GitOps](docs/gitops.md)
- [Operator Console](docs/operator-console.md) · [Observability](docs/observability.md)
- [Validation evidence](docs/VALIDATION.md) · [Implementation status](docs/IMPLEMENTATION_STATUS.md)
- [Production evolution](docs/production-evolution.md) · [Interview guide](docs/interview-guide.md)

## Developer harness

The original kind/Compose implementation remains available for fast contributor verification, but is
not the deployment story: see [local development](docs/local-development.md).
