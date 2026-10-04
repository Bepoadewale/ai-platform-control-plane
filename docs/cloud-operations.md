# Cloud Operations

The AWS reference environment is deliberately **private, ephemeral, Terraform-managed, and
single-account**. It is not started by default. The executed pilot used two CPU-only EKS nodes,
RDS PostgreSQL, ECR, Argo CD, Keycloak, OPA, Prometheus, Grafana, Tempo, OpenTelemetry, IRSA, and
External Secrets.

In practical terms: Terraform builds a small private test environment, the platform is checked
there, and Terraform removes it again. It is not a permanent public website.

## Guardrails

- Terraform remote state: encrypted/versioned S3 plus DynamoDB locking.
- Mandatory project tags and a USD 10 AWS Budget alert.
- Account guard: every script rejects an unexpected account.
- No long-lived AWS key in GitHub; GitHub Actions uses short-lived OIDC credentials.
- Public ingress is disabled by default. When explicitly enabled, the controller creates one
  HTTP-only ALB; it is removed before Terraform destroys the EKS/VPC footprint.
- Terraform is the authority for creating and removing AWS infrastructure.

## Recreate a disposable pilot

These commands create billable resources. Use a dedicated account and inspect every plan.

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-bootstrap-runtime
AWS_PROFILE=<operator-profile> make pilot-cloud-smoke
AWS_PROFILE=<operator-profile> make pilot-cloud-validate
```

Run the targeted operational drills when the stack is healthy:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-ha-check
AWS_PROFILE=<operator-profile> PILOT_LOAD_REQUESTS=20 PILOT_LOAD_CONCURRENCY=4 make pilot-cloud-load-slo
AWS_PROFILE=<operator-profile> make pilot-cloud-slo-alert-check
AWS_PROFILE=<operator-profile> make pilot-cloud-rollback-check
AWS_PROFILE=<operator-profile> make pilot-cloud-cost-evidence
```

For an authenticated public Console review without a domain, use the optional ALB path instead:

```console
AWS_PROFILE=<operator-profile> make pilot-cloud-public-plan
AWS_PROFILE=<operator-profile> make pilot-cloud-public-apply
AWS_PROFILE=<operator-profile> make pilot-cloud-push-image
AWS_PROFILE=<operator-profile> make pilot-cloud-public-bootstrap
AWS_PROFILE=<operator-profile> make pilot-cloud-public-smoke
```

It prints an AWS-generated `http://...elb.amazonaws.com` URL. It exposes only the Console, API,
and Keycloak endpoints required for browser sign-in. Prometheus, Grafana, Tempo, Argo CD, RDS, and
Kubernetes remain private. The generated URL has no trusted TLS certificate; use a domain plus ACM
before making any HTTPS claim.

## Teardown

Destroy only the pilot footprint after review is complete:

```console
AWS_PROFILE=<operator-profile> EXPECTED_AWS_ACCOUNT_ID=<pilot-account-id> \
  DESTROY_CLOUD_PILOT=<pilot-account-id> make pilot-cloud-destroy
```

Verify EKS, RDS, ECR, pilot Secrets Manager entries, pilot IAM roles, tagged VPCs, and remote
Terraform state are absent. Retain only the intentional state bucket, lock table, and Budget.

## What was checked

The pilot proved that Terraform could build and remove the AWS environment; GitHub Actions could
use short-lived AWS access; a reviewed Git change could create and remove a Kubernetes workload;
the platform could detect a broken image and restore a known-good version; and dashboards, traces,
metrics, alerts, and the authenticated Console worked during controlled tests. Exact commands and
technical results are in [Validation](VALIDATION.md).

## Cost and observability

Prometheus, Tempo, Grafana, and OpenTelemetry ran inside the pilot. The alert drill fired
`PilotUnauthorizedRequestBurst`; the bounded availability query returned `1`. Cost Explorer was
queried, but returned estimated/empty data within AWS's normal 24–48-hour publication lag. It must
not be described as settled cost evidence.
