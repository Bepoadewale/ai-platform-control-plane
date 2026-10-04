# AI Platform Control Plane — Agent Guide

Mission: govern cloud environment requests from API through policy, durable lifecycle, GitOps desired
state, EKS reconciliation, observability, and audit. Preserve tenant isolation and fail closed.

Stack: Python 3.12, FastAPI, Pydantic, PostgreSQL, Keycloak/JWKS, OPA, Argo CD, EKS, Prometheus,
Grafana, Tempo, OpenTelemetry, GitHub App/OIDC, AWS IRSA/External Secrets, and Terraform.

Commands: `make install`, `make test`, `make lint`, `make demo`, `make bootstrap-local`,
`make compose-smoke`, `make console-local`, `make demo-local`, `make argocd-demo`, `make clean-local`, `make helm-lint`,
and `make terraform-validate`.

Rules: this is cloud-first. Treat the local kind/Compose harness as contributor verification, not the
primary deployment claim. Never claim AWS execution without cloud evidence; never trust request
headers as production identity; no secrets; do not push main; preserve lifecycle/idempotency
semantics. Meaningful changes need tests. Update status/backlog after work and report exact
validation.

Operator Console rule: the browser UI is only an authenticated API client. It must use trusted OIDC
tokens, an explicit CORS allow-list, and existing API policy/approval/audit boundaries; never add
browser-held cloud/Kubernetes credentials, a policy decision in JavaScript, or a direct infrastructure
execution path.

Production-pilot rule: do not add long-lived AWS credentials to GitHub or the repository. A
temporary local bootstrap profile may exist only in the operator's `~/.aws` directory and must never
be logged, copied, or committed; replace it with SSO for humans and a least-privilege GitHub Actions
OIDC role for CI. Record real `plan`, `apply`, smoke, failure, cost, and `destroy` evidence before
labeling any AWS component executed. Cloud create/validate/destroy procedure is
`docs/cloud-operations.md`; it requires a dedicated account, budget, and explicit deployment
authority.

The owner-authorized Phase 0 backend and USD 10 Budget are executed and recorded in
`docs/VALIDATION.md`. Before an actual apply, run the reviewed plan, use only the project-scoped
scripts, record evidence, and destroy the workload footprint. The GitHub Actions workflow is manual
and confirmation-gated; it must never receive AWS access keys or broad unattended deployment
authority.

Evidence-label rule: the repository has completed its **Production-pilot** scope: a private,
single-account AWS create → validate → destroy reference environment. Do not call this
enterprise/public-SaaS certified. The seven explicit improvements in `docs/production-evolution.md`
require their own cloud evidence before those narrower claims can be made.
