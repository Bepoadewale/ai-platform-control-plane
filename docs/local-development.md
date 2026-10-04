# Contributor Harness

The project is cloud-first. The kind/Compose stack is retained only for fast contributor tests,
isolated debugging, and regression checks; it is not the primary deployment architecture or the
evidence boundary for cloud capability.

```console
make install
make bootstrap-local
make compose-smoke
make demo-local
make argocd-demo
make clean-local
```

These commands create and remove only project-owned local Docker/kind resources. Cloud behavior is
validated through the Terraform workflow in [Cloud Operations](cloud-operations.md).
