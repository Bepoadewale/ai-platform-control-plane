# GitOps Reconciliation

The API does not directly run Helm, `kubectl`, or Terraform in the cloud. It records the requested
change and lets the GitOps path apply it after review.

```text
approved request → PostgreSQL reconciliation job → scoped GitHub App pull request
→ protected merge → Argo ApplicationSet → EKS workload → read-only status observer
```

The worker takes one saved job at a time and publishes only that team's desired state. Its limited
GitHub credential is delivered through AWS workload identity rather than stored in the code. Argo
CD applies the reviewed change; a read-only observer writes back whether the workload became ready,
failed, or was removed.

The cloud pilot executed this path for a Ready workload, a bad-image
`ProgressDeadlineExceeded` failure, reviewed restoration, and deletion PR/namespace prune. The
next concern is not basic GitOps correctness; it is enterprise-hardening such as multi-repository
promotion, commit signing policy, and disaster recovery.
