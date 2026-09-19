# Demo scenarios

**A — valid.** Run `make demo`: `demo-api`, development, small profile, PostgreSQL, Redis, 12-hour TTL becomes `READY` and writes desired state.

**B — rejected.** Submit a request as `agent-requester` with production, privileged workload, or disabled observability. It becomes `REJECTED` with a precise audit reason.

**C — approval.** A developer submits production. It stops in `APPROVAL_REQUIRED`; a `platform-operator` calls the approval endpoint to render desired state.

**D — cleanup.** An expired non-production `READY` environment moves through `DESTROY_PENDING`, `DESTROYING`, and `DESTROYED`; production is protected from TTL deletion.
