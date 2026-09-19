# Interview guide

This project separates the control plane (API, policy, identity, plans, audit, desired state) from the data plane (Kubernetes workloads). Good discussion points: GitOps eventual consistency; idempotency versus duplicate agent retries; tenant isolation; agent identity and capability authorization; namespace/network isolation; failure handling when policy, Git, Argo CD, or Kubernetes is unavailable; SLOs; TTL/cost allocation; and AI-agent blast-radius control.

Extensions include durable PostgreSQL and an outbox worker, OPA bundles, a GitHub PR adapter, HA Argo CD, disaster recovery of audit/state, Crossplane compositions for managed services, and GPU-aware vLLM node pools. CPU local inference is only a functional development mode—not a substitute for production model-serving capacity, GPU scheduling, model cache, or latency SLOs.
