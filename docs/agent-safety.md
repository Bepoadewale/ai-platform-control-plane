# Agent safety

AI agents receive narrow, capability-oriented MCP tools, never arbitrary AWS credentials, `kubectl`, Terraform execution, or administrator APIs. Every write goes through the same API as a human request; the MCP server cannot bypass policy or GitOps.

Tools are classified as READ (`platform_catalog`, `get_environment_status`, `list_environments`, `estimate_cost`, `get_audit_events`), PLAN (`plan_environment`), WRITE (`request_environment`, `deploy_service`), and DESTRUCTIVE (`request_environment_destroy`). Authorization is checked by the API on every call. Destructive production operations require a human approval workflow.

Plan/apply separation makes actions reviewable. Idempotency keys make retries safe. Tenant-scoped identity restricts blast radius; audit events record actor, decision, and transition. Treat tool arguments as untrusted: prompt injection cannot grant a capability absent from the caller's token. Production should add nonce/replay controls, quotas, rate limits, approval expiry, and signed tool assertions.
