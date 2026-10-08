# Production Evolution

## Current delivery state

**Production-pilot complete — ephemeral single-account scope.**

The cloud environment was created, observed, tested through success and failure cases, and removed
safely. This is stronger than infrastructure code that has only been reviewed, but it is not a claim
that a continuously operated enterprise/public-SaaS service exists.

## Next production improvements

| Priority | Improvement | Why it still needs a separate test |
| --- | --- | --- |
| 1 | Enterprise sign-in | Keycloak proved standard OIDC works. A real Entra ID, Okta, or Ping tenant is needed to prove company sign-in, group mapping, account lifecycle, and policy integration. |
| 2 | Trusted public HTTPS | The ALB pilot proves public HTTP routing with exact OIDC/CORS origins. Trusted HTTPS still needs a controlled domain, certificate validation, WAF policy, and reviewed callback/CORS settings. |
| 3 | Model-quality rollback | The platform restored a broken deployment. Rolling back a model because its answers are worse needs model traffic, evaluation thresholds, and canary release controls. |
| 4 | Sustained load and error budgets | The pilot ran a small sample and fired an alert. Capacity and reliability claims need longer traffic tests, alert routing, error-budget rules, and measured results. |
| 5 | Backup and restore | Restart recovery is not disaster recovery. This needs a snapshot, simulated data loss, restore to an isolated database, integrity checks, and cleanup. |
| 6 | Settled billing | AWS Cost Explorer can take 24–48 hours to publish costs. Record usage only after it settles; do not treat early estimates as cost results. |
| 7 | GitHub-hosted Terraform destroy | GitHub OIDC apply was tested. Recreate a pilot and run the deliberately confirmation-gated hosted destroy workflow, then verify that every resource is gone. |

## Delivery principle

Each improvement must be implemented as a bounded cloud vertical slice:

```text
design → reviewed Terraform/application change → cloud execution → failure proof
→ observability/audit evidence → safe teardown or rollback → documentation update
```

No item becomes an executed capability because a manifest, workflow, interface, or diagram exists.

## Explicit non-goals

- Do not turn the reference account into a permanent public SaaS.
- Do not operate public ingress outside a bounded, reviewed pilot without trusted TLS and a
  deliberate public exposure policy.
- Do not add cloud credentials to GitHub secrets.
- Do not claim model-quality, enterprise identity, availability, or cost results without their
  corresponding evidence.
