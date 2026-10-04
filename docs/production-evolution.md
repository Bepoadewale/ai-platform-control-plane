# Production Evolution

## Current delivery state

**Production-pilot complete — ephemeral single-account scope.**

The reference cloud architecture was created, observed, exercised through success/failure/recovery
paths, and removed safely. This is stronger than static infrastructure code, but it is not a claim
that a continuously operated public enterprise service exists.

## Next production improvements

| Priority | Improvement | Why it remains a future validation |
| --- | --- | --- |
| 1 | Enterprise OIDC | Keycloak validated standards-compatible OIDC. A real Entra ID, Okta, or Ping tenant is required to prove enterprise federation, group mapping, lifecycle, and policy integration. |
| 2 | Trusted public TLS | A public endpoint requires a controlled domain, DNS/ACM validation, ingress/load balancer, WAF policy, and a production callback/CORS configuration. The pilot intentionally used a private tunnel instead. |
| 3 | Model-quality rollback | The control plane proved deployment-health rollback. Model-quality rollback needs a serving workload, canary traffic, evaluation slices, metric gates, and model-release integration. |
| 4 | Sustained load and error budgets | The pilot proved a bounded sample and an alert. Capacity/SLO certification needs longer traffic windows, alert routing, error-budget policy, and measured data. |
| 5 | Backup and restore | Restart recovery is not disaster recovery. Validate snapshot policy, destructive loss simulation, isolated restore, integrity checks, and cleanup. |
| 6 | Settled billing | AWS Cost Explorer data can lag 24–48 hours. Record published usage and allocation only after it settles; do not call early estimated output a cost result. |
| 7 | GitHub-hosted Terraform destroy | OIDC apply executed. Recreate a pilot and perform the confirmation-gated hosted destroy workflow, then verify the same post-destroy resource checks. |

## Delivery principle

Each improvement must be implemented as a bounded cloud vertical slice:

```text
design → reviewed Terraform/application change → cloud execution → failure proof
→ observability/audit evidence → safe teardown or rollback → documentation update
```

No item becomes an executed capability because a manifest, workflow, interface, or diagram exists.

## Explicit non-goals

- Do not turn the reference account into a permanent public SaaS.
- Do not add public ingress merely for a demo.
- Do not add cloud credentials to GitHub secrets.
- Do not claim model-quality, enterprise identity, availability, or cost results without their
  corresponding evidence.
