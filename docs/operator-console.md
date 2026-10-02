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

## Run locally

```bash
make console-local
```

Open `http://localhost:4173`, select **Sign in with Keycloak**, and use one of the local fixture
users. The console shows tenant-visible environments, live catalog capabilities, request-plan and
request submission flows, environment audit evidence, and the governing controls.

`make compose-smoke` verifies the console health endpoint and static page, Keycloak token issuance,
the explicit CORS preflight, authenticated API access, and the existing OTLP/Prometheus/Grafana
path. It is not a substitute for a human browser sign-in test.

## Cloud boundary

The console has not been deployed to AWS. A later cloud validation must use a real browser callback
URL, TLS, an enterprise identity client, an explicit production CORS allow-list, and a public
ingress or authenticated tunnel. It must not expose Keycloak, Grafana, OPA, or the API directly to
the internet merely to make the UI available.
