# Public ALB Ingress

The default pilot remains private. Set `public_alb_enabled=true` only for a bounded public-review
test. Terraform creates an IRSA role for the version-pinned AWS Load Balancer Controller. After
the runtime starts, the controller sees three checked-in Kubernetes Ingress objects and creates one
internet-facing Application Load Balancer.

```text
Internet → generated ALB HTTP address → Console, API, Keycloak → private EKS Pods
```

## What is public

| Path | Destination | Purpose |
| --- | --- | --- |
| `/` | Operator Console | Browser interface |
| `/api/*`, `/healthz`, `/metrics` | Control-plane API | Signed platform requests and health check |
| `/realms/*`, `/resources/*` | Keycloak | Browser sign-in and its static assets |

Prometheus, Grafana, Tempo, Argo CD, PostgreSQL, Kubernetes APIs, and AWS credentials are not
routed by this Ingress.

## Exact browser origin

An ALB DNS name is generated only after Kubernetes applies the Ingress. The public bootstrap waits
for that name, then writes the exact HTTP origin into one project-scoped ConfigMap consumed by
Keycloak, the API, and the Console. It also updates the Keycloak client to that one redirect and
logout origin. The configuration uses no wildcard redirect URI.

## Commands

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-public-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-public-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-public-bootstrap
AWS_PROFILE=<operator-profile> make pilot-cloud-public-smoke
```

The final command verifies the Console, API health endpoint, Keycloak issuer, unauthenticated API
denial, and one API-Pod failover through the generated ALB URL.

## Boundaries

- This is an HTTP-only pilot because no domain or ACM certificate is configured.
- It is disabled by default and creates ALB hourly/LCU charges when enabled.
- The guarded destroy script deletes the checked-in Ingress, waits for the named ALB to disappear,
  and then removes the Terraform-managed EKS/VPC footprint.
- Do not represent this as trusted public HTTPS or enterprise/public-SaaS certification.
