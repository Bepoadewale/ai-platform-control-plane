# Security Model

The control plane applies identity, authorization, policy, approval, and audit before it publishes
cloud intent. No client receives direct AWS, Terraform, Kubernetes, GitHub App, or secret authority.

```text
OIDC JWT/JWKS → tenant and role checks → OPA → immutable plan → independent approval
→ durable audit → scoped GitOps publication → Argo reconciliation
```

| Control | Cloud-pilot evidence |
| --- | --- |
| Signed identity | Keycloak RS256 JWT accepted by FastAPI/JWKS validation |
| Tenant isolation | cross-tenant request denied through live OPA and persisted audit |
| Protected changes | exact plan plus independent operator approval required |
| Cloud credentials | GitHub Actions used short-lived AWS OIDC; workloads used IRSA/External Secrets |
| Workload defaults | non-root, dropped capabilities, no privilege escalation, read-only filesystem, probes, limits, namespace/network boundaries |
| GitOps boundary | scoped GitHub App credential; protected PR is the cloud desired-state mutation |

Keycloak is a validated standards-compatible fixture—not enterprise OIDC. The reference pilot had
no public AWS ingress; its Cloudflare review tunnel was temporary and served synthetic data only.
Enterprise federation and trusted public TLS remain deliberate follow-on work.
