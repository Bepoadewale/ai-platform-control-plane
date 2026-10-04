# Operator Console

The Console is an authenticated browser client for the existing API—not a second control plane.

```text
Browser → OIDC Authorization Code + PKCE → bearer token → FastAPI
        → JWT/JWKS → tenant/RBAC → OPA → plan/approval/audit
```

The browser cannot choose tenant/roles, mint credentials, bypass policy, retrieve secrets, or call
AWS, Kubernetes, Terraform, or Argo directly.

The EKS-hosted Console executed Keycloak PKCE sign-in/out, explicit CORS, and signed API access. A
temporary Cloudflare Quick Tunnel exposed only local port-forwards through a same-origin proxy; it
did not create public AWS ingress, DNS, or a load balancer.

A trusted public Console requires enterprise OIDC, a controlled callback URL, public TLS ingress,
and a reviewed production CORS policy. Those are intentionally tracked in
[Production Evolution](production-evolution.md).
