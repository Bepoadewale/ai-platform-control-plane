import os
from pathlib import Path
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Response
from platform_control_plane.auth.dependencies import actor_from_request
from platform_control_plane.models.domain import (
    Actor,
    ApprovalRequest,
    EnvironmentRequest,
    LifecycleState,
)
from platform_control_plane.observability.metrics import POLICY_DENIALS, REQUESTS
from platform_control_plane.planner.service import Planner
from platform_control_plane.policy.engine import OPAPolicyEngine
from platform_control_plane.provisioning.service import EnvironmentService
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

app = FastAPI(title="AI Platform Control Plane", version="0.1.0")
service = EnvironmentService(
    Path(os.environ.get("PLATFORM_DESIRED_STATE_ROOT", "environments")),
    Path(os.environ.get("PLATFORM_CONTROL_PLANE_DB", "state/control-plane.db")),
    policy=OPAPolicyEngine.from_environment(require_live=True),
)
planner = Planner()


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/v1/catalog")
def catalog(actor: Actor = Depends(actor_from_request)) -> dict:
    REQUESTS.labels("catalog", "success").inc()
    return {
        "environment_types": ["development", "staging", "production"],
        "profiles": {
            "small": {"cpu": "250m", "memory": "256Mi"},
            "medium": {"cpu": "500m", "memory": "512Mi"},
        },
        "capabilities": [
            "service",
            "postgresql",
            "redis",
            "object-storage",
            "secret-references",
            "observability",
            "ttl",
        ],
        "agent_constraints": [
            "no production",
            "no privileged containers",
            "no direct cloud credentials",
        ],
    }


@app.post("/api/v1/plans")
def plan(request: EnvironmentRequest, actor: Actor = Depends(actor_from_request)):
    return planner.plan(request)


@app.post("/api/v1/environments", status_code=201)
def create(request: EnvironmentRequest, actor: Actor = Depends(actor_from_request)):
    env = service.create(actor, request)
    if env.state == LifecycleState.REJECTED:
        POLICY_DENIALS.labels("policy").inc()
        REQUESTS.labels("create", "rejected").inc()
    else:
        REQUESTS.labels("create", "success").inc()
    return env


@app.get("/api/v1/environments")
def list_environments(actor: Actor = Depends(actor_from_request)):
    return service.list(actor)


@app.get("/api/v1/environments/{environment_id}")
def get_environment(environment_id: UUID, actor: Actor = Depends(actor_from_request)):
    try:
        return service.get(actor, environment_id)
    except (KeyError, PermissionError) as error:
        raise HTTPException(404, detail="environment not found") from error


@app.post("/api/v1/environments/{environment_id}/approve")
def approve(
    environment_id: UUID,
    approval: ApprovalRequest,
    actor: Actor = Depends(actor_from_request),
):
    try:
        return service.approve(actor, environment_id, approval.plan_hash)
    except (ValueError, PermissionError) as error:
        raise HTTPException(403, detail=str(error)) from error


@app.post("/api/v1/environments/{environment_id}/destroy")
def destroy(environment_id: UUID, actor: Actor = Depends(actor_from_request)):
    try:
        return service.destroy(actor, environment_id)
    except (KeyError, PermissionError) as error:
        raise HTTPException(403, detail=str(error)) from error


@app.post("/api/v1/maintenance/ttl-reap")
def reap_expired(actor: Actor = Depends(actor_from_request)):
    if not ({"platform-operator", "platform-admin"} & {role.value for role in actor.roles}):
        raise HTTPException(403, detail="platform operator role required")
    return service.expire_due(actor)


@app.get("/api/v1/environments/{environment_id}/audit-events")
def audit_events(environment_id: UUID, actor: Actor = Depends(actor_from_request)):
    environment = service.get(actor, environment_id)
    return service.audit.list(environment.request.request_id)
