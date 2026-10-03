# Operator Console

The Operator Console is a separate browser interface for the existing control-plane API. It is
served locally at `http://localhost:4173`; it is not a second control plane and it does not own
authorization or reconciliation logic.

## Security boundary

```text
Browser → Keycloak Authorization Code + PKCE → bearer token
        → FastAPI API → JWT/JWKS verification → tenant/RBAC → OPA → plan/approval/audit
```

- Keycloak owns local fixture authentication.
- The browser sends a Keycloak-issued access token only to the configured control-plane API origin.
- FastAPI verifies issuer, audience, signature, expiry, tenant and roles before every API call.
- CORS is an explicit allow-list (`PLATFORM_CORS_ORIGINS`), not a wildcard.
- The console cannot mint credentials, approve a changed plan, bypass OPA, retrieve secret values,
  or invoke Kubernetes, Terraform, or cloud APIs directly.

The local Keycloak fixture includes `developer` and `operator` users. Their credentials are
synthetic local-development fixtures in the realm file; they must never be reused outside the local
stack.

For the private AWS pilot, the same fixture has a small `ai-platform` Keycloak login theme. It is
an executed presentation layer for the disposable pilot, not enterprise identity branding. A
temporary Cloudflare review uses an exact session-only redirect origin and a local same-origin proxy;
it creates no AWS ingress, domain, or public load balancer.

## Run locally

```bash
make console-local
```

Open `http://localhost:4173`, select **Sign in with Keycloak**, and use one of the local fixture
users. The console shows tenant-visible environments, live catalog capabilities, request-plan and
request submission flows, environment audit evidence, and the governing controls.

`make compose-smoke` verifies the console health endpoint and static page, a browser-equivalent
Keycloak Authorization Code + PKCE login/callback/token exchange, signed API access, Keycloak
logout redirect, explicit CORS preflight, and the existing OTLP/Prometheus/Grafana path.

## Bounded AWS pilot execution

The Console was executed on EKS on 2026-10-02. Its hardened Nginx Deployment was reconciled by
Argo CD alongside the control plane, Keycloak, and OPA. It is intentionally inspected through
local port-forwards rather than a public endpoint:

```bash
AWS_PROFILE=<operator-profile> make pilot-cloud-console
```

Open `http://localhost:18083`. The helper also forwards the API and Keycloak only to loopback, so
the browser completes Keycloak Authorization Code + PKCE and calls the EKS-hosted API with the same
signed bearer-token boundary as the local Console. `make pilot-cloud-console-validate` exercised
that complete login → callback → token exchange → signed catalog request → logout sequence, plus
the explicit CORS preflight.

This is cloud UI execution, not a public web-product claim. A later public deployment needs a
real browser callback URL, TLS, an enterprise identity client, an explicit production CORS
allow-list, and authenticated ingress. It must not expose Keycloak, Grafana, OPA, or the API
directly to the internet merely to make the UI available.
