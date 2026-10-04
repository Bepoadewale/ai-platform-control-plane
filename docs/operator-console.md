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

During the original pilot, the EKS-hosted Console used Keycloak sign-in/out, an explicit
browser-origin allow-list, and signed API requests through a private owner-review path. The current
optional public-review path uses an AWS ALB DNS name over HTTP. Its bootstrap writes that exact
generated origin into Keycloak, API CORS, and Console configuration; it never permits wildcard
redirects or browser-held cloud credentials.

The Console uses browser cryptography for PKCE and request identifiers. It uses
`crypto.randomUUID()` when available and creates an equivalent version-4 UUID from
`crypto.getRandomValues()` for browsers that do not implement `randomUUID()`. It refuses sign-in
rather than using weak randomness when secure browser cryptography is unavailable. For the
HTTP-only pilot, it also has a tested local SHA-256 fallback for PKCE challenge calculation when a
browser withholds `crypto.subtle` outside a secure context.

A trusted public Console requires enterprise OIDC, a controlled callback URL, public TLS ingress,
and a reviewed production CORS policy. Those are intentionally tracked in
[Production Evolution](production-evolution.md).
