# Week 1 Goal — Platform Control Plane

Starting maturity: PARTIALLY VALIDATED.

Outcome: make the request → policy → approval → desired state → local kind Ready → audit loop real.

P0: durable state ✅; signed local identity; OPA execution; kind bootstrap; reconciler; Ready/denial/destroy integration tests.

Failure demo: production request without approval or policy-allowed request with failed reconciliation is audited and not marked Ready.

Acceptance: a reproducible local command proves one successful and one failure path without AWS.
