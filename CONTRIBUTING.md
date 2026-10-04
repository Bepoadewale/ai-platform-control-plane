# Contributing

The AWS pilot is the primary deployment reference. The local kind/Compose workflow remains a
contributor harness; it is not evidence of cloud behavior.

Before opening a change, run the narrowest relevant checks and at minimum:

```bash
make lint
make test
```

For Terraform or cloud-runtime changes, also run the documented plan/validation path in
[Cloud Operations](docs/cloud-operations.md). Keep provisioning catalog-driven, policy-covered,
idempotent, auditable, least-privileged, and tagged for teardown. Never commit credentials,
Terraform state, generated tokens, or a temporary review URL.

Documentation must identify whether a claim is executed in the AWS pilot, statically validated,
historical contributor-harness evidence, or future work. Do not call a change
enterprise/public-SaaS certified without the gate in `DEFINITION_OF_DONE.md`.
