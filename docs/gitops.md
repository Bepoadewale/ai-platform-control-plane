# GitOps

The control plane renders desired state under `environments/<team>/<environment>/`. In production, a Git provider adapter creates a signed commit or pull request to a protected repository; Argo CD then reconciles that state. The API never silently mutates production Kubernetes resources. The local renderer writes a working-tree fixture so the core workflow can run without Git hosting or a cluster.

For the local GitOps validation, `make argocd-demo` applies the checked-in Application, points it at the current branch, enables Argo CD 3.x resource-health persistence, and waits for `Synced/Healthy`. The local override disables HPA and Ingress because the direct kind reconciler also disables Ingress and the demo cluster does not install an ingress controller; the golden-path chart keeps both defaults enabled for a capable cluster.
