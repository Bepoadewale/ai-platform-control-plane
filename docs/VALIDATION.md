# Validation

Baseline: `make test`, `make lint`, `make demo`; when tools exist, `make helm-lint` and `make terraform-validate`. Planned Level-3 validation runs a disposable kind cluster and asserts a reconciled workload becomes Ready. Record command, environment, and result in `PROJECT_STATUS.md`.
