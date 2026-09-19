"""Governed MCP transport. This process is an API client, never a cloud client."""

import os
from typing import Any

import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("AI Platform Control Plane")
API = os.getenv("PLATFORM_API_URL", "http://127.0.0.1:8000")

# In local Codex use these short-lived development claims. Production must use MCP OAuth
# identity propagation and API-side OIDC validation; an MCP tool may not choose its own role.
HEADERS = {
    "x-platform-subject": os.getenv("PLATFORM_MCP_SUBJECT", "local-agent"),
    "x-platform-tenant": os.getenv("PLATFORM_MCP_TENANT", "team-demo"),
    "x-platform-roles": os.getenv("PLATFORM_MCP_ROLE", "agent-requester"),
    "x-platform-agent": "true",
}
TOOL_CLASSIFICATION = {
    "platform_catalog": "READ", "plan_environment": "PLAN", "request_environment": "WRITE",
    "deploy_service": "WRITE", "get_environment_status": "READ", "list_environments": "READ",
    "estimate_cost": "READ", "request_environment_destroy": "DESTRUCTIVE", "get_audit_events": "READ",
}


async def request(method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
    async with httpx.AsyncClient(base_url=API, headers=HEADERS, timeout=10) as client:
        response = await client.request(method, path, json=payload)
        response.raise_for_status()
        return response.json()


@mcp.tool()
async def platform_catalog() -> dict[str, Any]:
    """READ: list approved platform capabilities and constrained resource profiles."""
    return await request("GET", "/api/v1/catalog")


@mcp.tool()
async def plan_environment(environment: dict[str, Any]) -> dict[str, Any]:
    """PLAN: validate shape and return a non-mutating infrastructure/cost proposal."""
    return await request("POST", "/api/v1/plans", environment)


@mcp.tool()
async def request_environment(environment: dict[str, Any]) -> dict[str, Any]:
    """WRITE: submit an auditable governed request. Policy and approval are enforced by the API."""
    return await request("POST", "/api/v1/environments", environment)


@mcp.tool()
async def get_environment_status(environment_id: str) -> dict[str, Any]:
    """READ: retrieve tenant-scoped lifecycle state and endpoint."""
    return await request("GET", f"/api/v1/environments/{environment_id}")


@mcp.tool()
async def list_environments() -> list[dict[str, Any]]:
    """READ: list environments visible to the authenticated tenant."""
    return await request("GET", "/api/v1/environments")


@mcp.tool()
async def estimate_cost(environment: dict[str, Any]) -> dict[str, Any]:
    """READ: return the plan cost estimate without creating infrastructure."""
    return await plan_environment(environment)


@mcp.tool()
async def deploy_service(environment: dict[str, Any]) -> dict[str, Any]:
    """WRITE: alias for the governed environment request golden path."""
    return await request_environment(environment)


@mcp.tool()
async def request_environment_destroy(environment_id: str) -> dict[str, Any]:
    """DESTRUCTIVE: request non-production destruction; production requires approval."""
    return await request("POST", f"/api/v1/environments/{environment_id}/destroy")


@mcp.tool()
async def get_audit_events(environment_id: str) -> list[dict[str, Any]]:
    """READ: retrieve immutable lifecycle/audit records for an environment."""
    return await request("GET", f"/api/v1/environments/{environment_id}/audit-events")


if __name__ == "__main__":
    mcp.run(transport="stdio")
