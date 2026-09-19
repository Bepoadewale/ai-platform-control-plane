# Validation

Baseline: `make test`, `make lint`, `make demo`; when tools exist, `make helm-lint` and `make terraform-validate`.

Executed Level-3 local validation: `make demo-local` creates or reuses kind, exercises signed JWT → OPA → FastAPI → Helm/kind → readiness → audit/metrics → destroy, and proves an agent production request is denied. The demo uses no cloud credentials.
