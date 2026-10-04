# Security

Please do not report vulnerabilities in public issues. Contact the repository owner privately with
reproduction details.

Never commit AWS credentials, GitHub App keys, Terraform state, Keycloak exports containing
credentials, generated bearer tokens, or Cloudflare tunnel URLs. The cloud reference uses
GitHub Actions OIDC for AWS and IRSA-backed External Secrets for the worker's scoped GitHub App
credential; secret values must not pass through Git, API payloads, or audit records.

The completed AWS pilot was private and ephemeral. It is not enterprise/public-SaaS certified:
enterprise identity-provider validation and trusted public TLS ingress remain future work. See the
[security model](docs/security.md) and [production evolution](docs/production-evolution.md).
