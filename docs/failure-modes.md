# Failure and Recovery

This page describes what the platform did when something went wrong during the AWS pilot. The
important point is that it did not silently call a workload healthy or make an unreviewed change.

| What went wrong | What the platform did | How it recovered safely |
| --- | --- | --- |
| Unsafe or cross-team request | OPA denied it before anything changed and the audit record was saved. | Correct the request or policy, then retry safely. |
| Broken container image | Kubernetes could not start it; the platform recorded the environment as failed. | Review and restore the known-good version, then remove the failed environment through GitOps. |
| API or worker Pod removed | Kubernetes restarted it; disruption protections kept another replica available. | PostgreSQL kept the saved plans and jobs while the stateless Pod returned. |
| Environment deleted | A reviewed GitHub deletion change merged; Argo removed the workload and namespace; the record became `DESTROYED`. | Request a new environment through the normal plan and approval path. |
| Policy service unavailable | Protected changes failed closed. | Restore the policy service; do not bypass it. |

Backup/restore, model-quality rollback, and multi-region disaster recovery are future production
improvements, not completed evidence. See [Production Evolution](production-evolution.md).
