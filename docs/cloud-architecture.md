# Cloud Architecture

This is the deployed **single-account, private, ephemeral AWS reference architecture**. It was
created with Terraform, validated through governed GitOps lifecycle scenarios, and destroyed with
Terraform. It is the repository's primary architecture; the local harness is retained only for
fast developer verification.

## System context

```mermaid
flowchart LR
  Human[Developer or operator] --> Console[Operator Console]
  Agent[Governed AI agent] --> MCP[MCP / API client]
  Console --> IdP[OIDC issuer]
  MCP --> API
  IdP --> API[Control-plane API]
  API --> Policy[OPA policy]
  API --> State[(RDS PostgreSQL)]
  API --> Audit[Lifecycle and audit state]
  API --> Worker[Durable GitOps worker]
  Worker --> GitHub[Protected GitHub pull request]
  GitHub --> Argo[Argo CD ApplicationSet]
  Argo --> EKS[Private EKS workloads]
  EKS --> Observe[Prometheus · Tempo · Grafana]
  EKS --> Observer[Read-only status observer]
  Observer --> API
```

## AWS deployment topology

```mermaid
flowchart TB
  classDef control fill:#e7f0ff,stroke:#2563eb,color:#102a43;
  classDef security fill:#ecfdf5,stroke:#15803d,color:#123b24;
  classDef data fill:#fff7ed,stroke:#c2410c,color:#431407;
  classDef observe fill:#f5f3ff,stroke:#7c3aed,color:#2e1065;
  classDef external fill:#f4f4f5,stroke:#52525b,color:#18181b;

  subgraph github[GitHub control boundary]
    Actions[Manual Terraform workflow]
    OIDC[GitHub OIDC federation]
    Repo[Protected application and desired-state repository]
    App[Scoped GitHub App credential]
    Actions --> OIDC
    App --> Repo
  end

  subgraph aws[AWS account / us-east-1]
    TF[Terraform state: encrypted S3 + DynamoDB lock]
    OIDC --> TF
    subgraph vpc[Tagged VPC]
      Public[Public subnets: NAT only]
      Private[Private subnets]
      NAT[NAT gateway]
      Public --> NAT --> Private
      subgraph eks[Amazon EKS]
        Argo[Argo CD + ApplicationSet]
        API[FastAPI control plane x2]
        Worker[GitOps worker x2]
        OPA[OPA x2]
        Keycloak[Keycloak fixture]
        Console[Hardened Operator Console]
        Observer[Read-only status observer]
        ESO[External Secrets + IRSA]
        Workload[Tenant namespace / golden-path workload]
        Argo --> API
        Argo --> Worker
        Argo --> OPA
        Argo --> Keycloak
        Argo --> Console
        Argo --> Observer
        Argo --> Workload
        ESO --> Worker
      end
      RDS[(RDS PostgreSQL)]
      ECR[ECR image repository]
      Secrets[Secrets Manager]
      Prom[Prometheus]
      Tempo[Tempo]
      Grafana[Grafana]
      OTel[OpenTelemetry Collector]
      API --> RDS
      API --> OTel
      OTel --> Tempo
      Prom --> Grafana
      Prom --> API
      Secrets --> ESO
      ECR --> API
      ECR --> Worker
    end
  end

  Worker --> Repo
  Repo --> Argo
  class API,Worker,Argo,Console,Observer control;
  class OPA,Keycloak,ESO,OIDC,App security;
  class RDS,ECR,Secrets,TF,NAT data;
  class Prom,Tempo,Grafana,OTel observe;
  class Human,Agent,Actions,Repo,Workload external;
```

## Governed environment lifecycle

```mermaid
sequenceDiagram
  autonumber
  participant C as Console / CLI / agent
  participant I as OIDC + JWT/JWKS
  participant A as API + OPA
  participant D as PostgreSQL
  participant W as GitOps worker
  participant G as Protected GitHub PR
  participant R as Argo CD
  participant K as EKS + observer

  C->>I: Authenticate
  C->>A: Tenant-scoped environment request
  A->>A: RBAC, idempotency, OPA decision
  A->>D: Persist plan, approval requirement, audit
  alt protected request
    C->>A: Independent exact-plan approval
    A->>D: Persist approval binding
  end
  A->>W: Durable reconciliation job
  W->>G: Publish desired-state PR
  G-->>R: Checks pass and PR merges
  R->>K: Render and reconcile golden-path workload
  K-->>A: Ready or failed status
  A->>D: Persist lifecycle transition and audit
  Note over C,K: Destroy repeats policy, approval, GitOps deletion and observed prune.
```

## Trust boundaries

| Boundary | Enforced control |
| --- | --- |
| Browser/client → API | OIDC bearer token, JWT/JWKS validation, explicit CORS |
| API → write operation | tenant/RBAC, OPA, idempotency, immutable plan, approval where required |
| API → reconciliation | durable PostgreSQL job; API does not run cloud `kubectl`, Helm, or Terraform |
| Worker → GitHub | scoped GitHub App credential delivered through IRSA/External Secrets |
| GitHub → AWS | branch-bound GitHub OIDC role with short-lived credentials |
| Desired state → cluster | protected PR merge → Argo ApplicationSet; observed readiness/failure |
| Cloud review | temporary Cloudflare tunnel to local port-forwards only; no AWS public ingress |
