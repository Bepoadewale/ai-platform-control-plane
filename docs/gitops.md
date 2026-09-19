# GitOps

The control plane renders desired state under `environments/<team>/<environment>/`. In production, a Git provider adapter creates a signed commit or pull request to a protected repository; Argo CD then reconciles that state. The API never silently mutates production Kubernetes resources. The local renderer writes a working-tree fixture so the core workflow can run without Git hosting or a cluster.
