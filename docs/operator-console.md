# Operator Console

The Console is the browser view of the existing platform. It lets an operator see environments,
plans, approvals, and audit history; it does not give the browser direct control of AWS or
Kubernetes.

```text
Browser → OIDC Authorization Code + PKCE → bearer token → FastAPI
        → JWT/JWKS → tenant/RBAC → OPA → plan/approval/audit
```

The browser cannot choose its own team or role, create credentials, bypass policy, retrieve
secrets, or call AWS, Kubernetes, Terraform, or Argo directly.

During the pilot, the EKS-hosted Console used Keycloak sign-in/out, an explicit browser-origin
allow-list, and signed API requests. A temporary Cloudflare Quick Tunnel let the owner review it
privately. It did not create a public AWS website, DNS record, or load balancer.

A trusted public Console requires enterprise OIDC, a controlled callback URL, public TLS ingress,
and a reviewed production CORS policy. Those are intentionally tracked in
[Production Evolution](production-evolution.md).
