"""MCP adapter boundary. Install `mcp` and wire these functions as tools in deployment."""
import os
import httpx

API = os.getenv("PLATFORM_API_URL", "http://127.0.0.1:8000")

TOOL_CLASSIFICATION = {"platform_catalog": "READ", "plan_environment": "PLAN", "request_environment": "WRITE", "deploy_service": "WRITE", "get_environment_status": "READ", "list_environments": "READ", "estimate_cost": "READ", "request_environment_destroy": "DESTRUCTIVE", "get_audit_events": "READ"}

def platform_catalog() -> dict:
    return httpx.get(f"{API}/api/v1/catalog", timeout=10).json()

def plan_environment(request: dict) -> dict:
    return httpx.post(f"{API}/api/v1/plans", json=request, timeout=10).json()

def request_environment(request: dict) -> dict:
    return httpx.post(f"{API}/api/v1/environments", json=request, timeout=10).json()

def get_environment_status(environment_id: str) -> dict:
    return httpx.get(f"{API}/api/v1/environments/{environment_id}", timeout=10).json()

def list_environments() -> list[dict]:
    return httpx.get(f"{API}/api/v1/environments", timeout=10).json()

def estimate_cost(request: dict) -> dict: return plan_environment(request)
def deploy_service(request: dict) -> dict: return request_environment(request)
def request_environment_destroy(environment_id: str) -> dict: return httpx.post(f"{API}/api/v1/environments/{environment_id}/destroy", timeout=10).json()
def get_audit_events(environment_id: str) -> list[dict]: return httpx.get(f"{API}/api/v1/environments/{environment_id}/audit-events", timeout=10).json()
