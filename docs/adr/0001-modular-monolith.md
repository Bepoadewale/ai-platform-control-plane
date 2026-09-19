# ADR 0001: Start with a modular monolith

**Decision:** Keep policy, planning, audit, GitOps rendering, and API in one deployable Python service with explicit modules.

**Why:** Transactions, idempotency, and authorization remain coherent while the product surface is evolving. Separate workers/adapters can be extracted around measured scaling/failure boundaries.
