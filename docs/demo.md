# Cloud Reference Demonstration

In the main demonstration, a developer asked for an environment. The platform checked identity and
permission, recorded the plan, created a reviewable GitHub change, let Argo CD deploy it, and then
recorded whether it became healthy.

```text
developer request → OIDC → tenant/RBAC → OPA → plan/approval
→ PostgreSQL job → GitHub PR → Argo → private EKS workload Ready
→ audit + Prometheus + Tempo + Grafana
```

The failure demonstration was equally important. A deliberately broken image never became ready:

```text
reviewed bad image → ImagePullBackOff → ProgressDeadlineExceeded → FAILED audit
→ reviewed known-good restore → Ready → governed deletion PR → Argo prune → DESTROYED
```

The operational demonstration deleted one API and one worker Pod while backup replicas were active,
ran a small authenticated load sample, fired a Prometheus alert, reviewed the Console through a
private owner-review path, and then ran account-guarded Terraform destroy. See
[Cloud Operations](cloud-operations.md) and [Validation](VALIDATION.md).
