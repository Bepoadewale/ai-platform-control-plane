# MCP server contract

The MCP server is intentionally a thin API client. It exposes `platform_catalog` (READ), `plan_environment` (PLAN), `request_environment` and `deploy_service` (WRITE), and `request_environment_destroy` (DESTRUCTIVE), plus status/list/cost/audit read tools. It must pass caller identity to the control plane and never execute Terraform, AWS CLI, or kubectl.

Example Codex project configuration:

```json
{"mcp_servers":{"platform":{"command":"python","args":["-m","platform_mcp.server"],"env":{"PLATFORM_API_URL":"http://127.0.0.1:8000"}}}}
```
