# Security Model

The platform checks identity, permissions, policy, approval, and audit before it asks the cloud to
change anything. Developers and AI agents can request work, but they do not receive direct AWS,
Terraform, Kubernetes, GitHub App, or secret credentials.

```text
OIDC JWT/JWKS → tenant and role checks → OPA → immutable plan → independent approval
→ durable audit → scoped GitOps publication → Argo reconciliation
```

| Protection | What the pilot proved |
| --- | --- |
| Secure sign-in | A Keycloak-issued signed token was accepted only after validation by the API. |
| Team separation | A request for another team's environment was denied and recorded. |
| Sensitive changes | The exact plan needed approval from a different operator. |
| Cloud access | GitHub Actions used short-lived AWS access; workloads received only their scoped secret through IRSA and External Secrets. |
| Safer workloads | Containers ran as non-root with restricted privileges, probes, limits, and namespace/network boundaries. |
| Change control | A scoped GitHub App created the desired-state change; Argo CD applied only reviewed, merged changes. |

Keycloak is a validated standards-compatible fixture—not enterprise OIDC. The required ALB path
permits HTTP only and sets the generated ALB DNS name as the exact Console redirect/CORS
origin. It does not expose observability or cluster administration services. Enterprise federation
and trusted public TLS remain deliberate follow-on work.
