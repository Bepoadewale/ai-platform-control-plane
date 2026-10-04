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
- No public load balancer, DNS, or AWS public ingress in the reference pilot.
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

For an authenticated temporary Console review, use `make pilot-cloud-console-public-demo`. It
exposes only a local same-origin proxy through a short-lived Cloudflare Quick Tunnel. It creates no
AWS public endpoint and must use disposable synthetic data.

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
