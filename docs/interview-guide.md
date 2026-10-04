# Interview guide

This project separates the control plane (API, policy, identity, plans, audit, durable GitOps jobs)
from the data plane (private EKS workloads). Good discussion points: GitOps eventual consistency;
idempotency versus duplicate agent retries; tenant isolation; agent authority; IRSA/External Secrets;
bad-image recovery; pod-loss resilience; and why the API owns intent while Argo owns reconciliation.

The cloud pilot is strong evidence of a disposable reference platform, not an enterprise/public-SaaS
claim. The next interview-worthy discussion is how the seven items in
[Production Evolution](production-evolution.md) would be validated without overstating results.
