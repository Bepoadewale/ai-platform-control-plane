# Demo scenarios

**A — full local acceptance.** Run `make demo-local` with Docker Desktop, kind, kubectl, and Helm installed. It generates a temporary RS256 signing key/JWKS, starts OPA, starts FastAPI, creates a real kind workload, waits for `READY`, retrieves its audit, checks Prometheus metrics, destroys it, and verifies namespace deletion. It also executes a production request through independent exact-plan approval and independently approved destruction.

**B — rejected.** Submit a request as `agent-requester` with production, privileged workload, or disabled observability. It becomes `REJECTED` with a precise audit reason.

**C — approval.** A developer submits production. It stops in `APPROVAL_REQUIRED`; a different `platform-operator` must approve the exact SHA-256 plan hash. A requester cannot self-approve and a changed/mismatched plan is rejected as `STALE_PLAN`.

**D — cleanup.** An expired non-production `READY` environment moves through `DESTROY_PENDING`, `DESTROYING`, and `DESTROYED`; production is protected from TTL deletion.

**E — failed reconciliation.** A deliberately unhealthy image is deployed to kind with a bounded timeout. The environment becomes `FAILED` and records `reconciliation.failed`; it is never marked `READY`.

**F — tenant boundary and retry safety.** API tests prove a tenant cannot read or mutate another
tenant's environment. Repeating the same mutation with the same idempotency key returns the original
result; reusing that key for materially different input is rejected rather than creating duplicate
infrastructure.

**G — local GitOps.** Run `make argocd-demo` after `make bootstrap-local`. Argo CD applies the
checked-in golden path from the current branch; the script waits for Application `Synced/Healthy`
and a `1/1` available Deployment. This is local kind/Argo execution, not a hosted Git provider or
production Argo HA claim.
