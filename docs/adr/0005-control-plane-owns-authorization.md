# ADR 0005: Authorization is owned by the control plane

**Decision:** MCP, CLI, and UI clients are untrusted transports. The control plane validates identity, tenant scope, role, and policy for every action.

**Why:** Client-side authorization can be bypassed. A single server-side boundary maintains consistent capability rules and audit records across humans and agents.
