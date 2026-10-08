# AWS ALB Ingress

Every cloud pilot creates one bounded HTTP Application Load Balancer. Terraform creates the IRSA
role for the version-pinned AWS Load Balancer Controller. After the runtime starts, the controller
sees three checked-in Kubernetes Ingress objects and creates the ALB.

```text
Internet → generated ALB HTTP address → Console, API, Keycloak → private EKS Pods
```

## What is public

| Path | Destination | Purpose |
| --- | --- | --- |
| `/` | Operator Console | Browser interface |
| `/api/*`, `/healthz` | Control-plane API | Signed platform requests and health check |
| `/realms/*`, `/resources/*` | Keycloak | Browser sign-in and its static assets |

Prometheus, Grafana, Tempo, Argo CD, PostgreSQL, Kubernetes APIs, and AWS credentials are not
routed by this Ingress.

## Exact browser origin

An ALB DNS name is generated only after Kubernetes applies the Ingress. Runtime bootstrap waits for
that name, then writes the exact HTTP origin into one project-scoped ConfigMap consumed by
Keycloak, the API, and the Console. It also updates the Keycloak client to that one redirect and
logout origin. The configuration uses no wildcard redirect URI.

## Commands

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
```

The final command verifies the Console, Keycloak PKCE sign-in/logout, API health endpoint, exact
Keycloak issuer, unauthenticated API denial, and one API-Pod failover through the generated ALB
URL.

## Boundaries

- This is an HTTP-only pilot because no domain or ACM certificate is configured.
- It is part of every cloud pilot and creates ALB hourly/LCU charges while the pilot exists.
- The guarded destroy script deletes the checked-in Ingress, waits for the named ALB to disappear,
  and then removes the Terraform-managed EKS/VPC footprint.
- Do not represent this as trusted public HTTPS or enterprise/public-SaaS certification.
