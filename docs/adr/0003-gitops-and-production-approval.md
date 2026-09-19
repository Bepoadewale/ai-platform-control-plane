# ADR 0003: GitOps with production approval

**Decision:** Desired state is committed/reviewed before Argo CD reconciliation; production requests require an operator approval.

**Why:** Git gives change history and rollback, while approval controls high-impact actions without blocking safe development self-service.
