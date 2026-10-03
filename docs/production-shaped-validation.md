# Production-Shaped AWS Validation

This is the next evidence target for the control plane:

> **Production-shaped AWS validation — single-account, private, ephemeral, tunnel-reviewed.**

It is intentionally narrower than production certification. All infrastructure remains in the
existing AWS account, no public DNS or load balancer is required, and the Operator Console is
reviewed only through a temporary loopback port-forward or Cloudflare Quick Tunnel. Terraform must
create and destroy the workload footprint for every validation run.

## What this target must prove

```text
signed request
  → OPA and approval
  → durable reconciliation job
  → protected Git desired-state change
  → Argo CD
  → private EKS environment workload
  → observed readiness or failure
  → audit, metrics, traces, SLO signal
  → rollback or cleanup
```

The API records intent. A durable worker publishes approved desired state. Argo CD reconciles the
Git revision. The API/worker observes Argo and Kubernetes; neither directly shells out to Helm or
kubectl in the cloud path.

## Acceptance gate

- [x] SQLite-backed job state survives a service restart; PostgreSQL uses the same explicit job
  schema and repository contract. A cloud PostgreSQL worker restart remains unexecuted.
- [x] An Argo ApplicationSet contract discovers only merged `environments/<team>/<name>` values
  directories and uses the repository's golden-path Helm chart. The worker starts only after
  External Secrets materializes its scoped credential.
- [x] A separately deployed, read-only Argo/Kubernetes observer has local unit coverage for Ready
  and Degraded states; its EKS execution observed both a `1/1` Ready workload and a bad-image
  `ProgressDeadlineExceeded` failure. It cannot publish Git state or mutate workload resources.
- [x] Approved development request produced a protected Git change through the GitHub App in EKS.
- [x] Argo ApplicationSet discovered the merged desired state and created a private environment
  workload in EKS.
- [x] Readiness and destroy were observed through the durable API/audit state; merged deletion
  changes pruned generated Argo Applications and namespaces.
- [x] EKS workloads retrieved the scoped GitHub App credential through the rendered IRSA + External Secrets path;
  no secret value is stored in Git, request payloads, or audit records.
- [x] A Cloudflare Quick Tunnel exposed the real EKS-backed Operator Console through a local
  same-origin proxy. Keycloak PKCE sign-in worked with an exact, session-only redirect origin and
  a mounted AI Platform login theme; no AWS ingress, DNS, or load balancer was created.
- [x] A disposable bad-image environment reached `ImagePullBackOff` then Kubernetes
  `ProgressDeadlineExceeded`; the observer persisted `FAILED`, and GitOps deletion pruned its
  Application and namespace. This is a safe failure-and-cleanup drill, not a quality rollback.
- [ ] Control plane and worker run at more than one replica with probes, PDBs, bounded retries, and
  a deliberate pod-loss/recovery test.
- [ ] Prometheus, Tempo, and Grafana show lifecycle metrics/traces; an alert and error-budget/SLO
  calculation consume generated workload evidence.
- [ ] A bounded load drill runs against disposable tenant workloads. The bad-workload failure drill
  executed; sustained load/capacity evidence remains pending.
- [ ] `make pilot-cloud-destroy` removes the workload footprint; AWS API and Terraform state checks
  record the retained state bucket, lock table, and Budget only.

## Intentional deviations from a public production service

- One AWS account, not separated pilot/staging/production accounts.
- No public DNS, TLS ingress, WAF, or public load balancer.
- Keycloak fixture identity may be used as a production-shaped test issuer; it is not enterprise
  identity validation.
- Temporary tunnel review exposes only a local port-forward and only disposable synthetic data.
- The validation remains an ephemeral, measured exercise—not an availability or customer-SLA claim.

## Delivery order

1. Durable outbox and worker, plus GitHub publication contracts.
2. Argo ApplicationSet and per-environment private workload reconciliation.
3. External Secrets/workload identity and GitHub Actions OIDC execution.
4. HA-shaped runtime, recovery/rollback, lifecycle telemetry, SLO/alert, and load/failure drills.
5. One create → validate → temporary tunnel review → destroy evidence pass.

The full production-certification gate remains in [Definition of Done](../DEFINITION_OF_DONE.md).
