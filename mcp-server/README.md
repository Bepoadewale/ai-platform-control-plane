# MCP server contract

The MCP server is a runnable FastMCP stdio client boundary. It exposes `platform_catalog` (READ),
`plan_environment` (PLAN), `request_environment` and `deploy_service` (WRITE), and
`request_environment_destroy` (DESTRUCTIVE), plus status/list/cost/audit read tools. It invokes
the control-plane API only; it never executes Terraform, AWS CLI, Helm, or `kubectl`.

The control plane remains the authorization boundary: it validates identity, tenant scope, role,
OPA policy, approval, idempotency, audit, and GitOps publication. The environment variables below
are a contributor-harness identity adapter, not delegated enterprise identity. Do not use them to
claim enterprise/public-SaaS MCP authentication.

Example Codex project configuration:

```json
{"mcp_servers":{"platform":{"command":"python","args":["mcp-server/src/platform_mcp/server.py"],"env":{"PLATFORM_API_URL":"http://127.0.0.1:8000","PLATFORM_MCP_ROLE":"agent-requester"}}}}
```
