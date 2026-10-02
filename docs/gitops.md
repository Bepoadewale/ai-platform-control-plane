# GitOps

The control plane renders desired state under `environments/<team>/<environment>/`. In production, a
Git provider adapter must create a signed commit or pull request to a protected environment
repository; Argo CD then reconciles that immutable revision. The API owns intent, policy, planning,
approval, and observation. Argo CD owns production reconciliation. The API must never silently run
Helm or `kubectl` against production Kubernetes.

The current local renderer writes a working-tree fixture so the core workflow can run without Git
hosting. The current local Argo CD demo proves chart synchronization, not a production Git commit or
pull-request adapter. That adapter, commit identity/signing, protected-branch workflow, Argo status
observation, and rollback semantics are production-pilot work.

For the local GitOps validation, `make argocd-demo` applies the checked-in Application, points it at the current branch, enables Argo CD 3.x resource-health persistence, and waits for `Synced/Healthy`. The local override disables HPA and Ingress because the direct kind reconciler also disables Ingress and the demo cluster does not install an ingress controller; the golden-path chart keeps both defaults enabled for a capable cluster.
