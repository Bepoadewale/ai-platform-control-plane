# Cloud Reference Demonstration

The completed reference scenario was:

```text
developer request → OIDC → tenant/RBAC → OPA → plan/approval
→ PostgreSQL job → GitHub PR → Argo → private EKS workload Ready
→ audit + Prometheus + Tempo + Grafana
```

The failure scenario was equally important:

```text
reviewed bad image → ImagePullBackOff → ProgressDeadlineExceeded → FAILED audit
→ reviewed known-good restore → Ready → governed deletion PR → Argo prune → DESTROYED
```

The operational scenario deleted one API and one worker Pod while replicas/PDBs were active, ran a
bounded authenticated load sample, fired a Prometheus alert, reviewed the Console through a
temporary tunnel, and then ran account-guarded Terraform destroy. See
[Cloud Operations](cloud-operations.md) and [Validation](VALIDATION.md).
