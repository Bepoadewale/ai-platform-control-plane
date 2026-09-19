# ADR 0002: MCP never calls AWS directly

**Decision:** MCP invokes authenticated platform APIs only.

**Why:** It prevents credential exfiltration and bypass of policy, approval, audit, idempotency, and GitOps controls.
