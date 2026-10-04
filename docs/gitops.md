# GitOps Reconciliation

Cloud writes do not invoke Helm, `kubectl`, or Terraform from the API process.

```text
approved request → PostgreSQL reconciliation job → scoped GitHub App pull request
→ protected merge → Argo ApplicationSet → EKS workload → read-only status observer
```

The worker atomically claims durable jobs, publishes only tenant-scoped desired state, and holds a
scoped GitHub App credential delivered through IRSA and External Secrets. Argo owns workload
reconciliation; the observer writes Ready/Failed/Destroyed evidence back to the durable lifecycle
and audit record.

The cloud pilot executed this path for a Ready workload, a bad-image
`ProgressDeadlineExceeded` failure, reviewed restoration, and deletion PR/namespace prune. The
next concern is not basic GitOps correctness; it is enterprise-hardening such as multi-repository
promotion, commit signing policy, and disaster recovery.
