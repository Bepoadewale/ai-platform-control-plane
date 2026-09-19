# Architecture

The control plane is a modular monolith because the first hard problem is governed workflow consistency, not service-to-service networking. It owns authorization, policy evaluation, idempotency, lifecycle state, audit events, planning, and GitOps rendering. Kubernetes is the data plane.

```mermaid
sequenceDiagram
  participant Client as Human/Agent
  participant API as Platform API
  participant Policy as OPA policy
  participant Git as Desired state repo
  participant Argo as Argo CD
  participant K8s as Kubernetes
  Client->>API: request + idempotency key
  API->>Policy: actor + tenant + request
  Policy-->>API: allow/deny/approval
  API->>Git: render/commit desired state
  Git->>Argo: reconciliation
  Argo->>K8s: apply golden path
  API-->>Client: lifecycle/status
```

State is recorded as `REQUESTED → VALIDATING → PLANNED → APPLYING → READY`, with rejection, approval, failure, and destruction branches. The in-memory repository is intentionally local-demo only; PostgreSQL is the production persistence seam.
