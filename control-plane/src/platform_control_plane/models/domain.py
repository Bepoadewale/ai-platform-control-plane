from __future__ import annotations

from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Annotated
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


class Role(StrEnum):
    VIEWER = "viewer"
    DEVELOPER = "developer"
    PLATFORM_OPERATOR = "platform-operator"
    PLATFORM_ADMIN = "platform-admin"
    AGENT_REQUESTER = "agent-requester"


class EnvironmentType(StrEnum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"


class LifecycleState(StrEnum):
    REQUESTED = "REQUESTED"
    VALIDATING = "VALIDATING"
    REJECTED = "REJECTED"
    PLANNED = "PLANNED"
    APPROVAL_REQUIRED = "APPROVAL_REQUIRED"
    APPROVED = "APPROVED"
    APPLYING = "APPLYING"
    READY = "READY"
    FAILED = "FAILED"
    DESTROY_PENDING = "DESTROY_PENDING"
    DESTROYING = "DESTROYING"
    DESTROYED = "DESTROYED"


RESOURCE_PROFILES = {
    "small": {"cpu": "250m", "memory": "256Mi", "monthly_usd": 8.0},
    "medium": {"cpu": "500m", "memory": "512Mi", "monthly_usd": 16.0},
    "large": {"cpu": "1000m", "memory": "1Gi", "monthly_usd": 32.0},
}


class Actor(BaseModel):
    subject: str
    tenant_id: str
    roles: set[Role]
    is_agent: bool = False


class WorkloadProfile(BaseModel):
    size: str = "small"
    replicas: Annotated[int, Field(ge=1, le=10)] = 1
    privileged: bool = False
    gpu_count: Annotated[int, Field(ge=0, le=8)] = 0
    runtime: str | None = None
    model: str | None = None
    latency_slo_ms: Annotated[int | None, Field(ge=1)] = None

    @field_validator("size")
    @classmethod
    def known_size(cls, value: str) -> str:
        if value not in RESOURCE_PROFILES:
            raise ValueError(f"unsupported resource profile: {value}")
        return value


class EnvironmentRequest(BaseModel):
    request_id: UUID = Field(default_factory=uuid4)
    idempotency_key: str = Field(min_length=8, max_length=128)
    name: str = Field(pattern=r"^[a-z][a-z0-9-]{2,40}$")
    team: str = Field(pattern=r"^[a-z][a-z0-9-]{1,30}$")
    environment_type: EnvironmentType
    ttl_hours: Annotated[int | None, Field(ge=1, le=168)] = None
    services: list[str] = Field(default_factory=lambda: ["api"])
    postgresql: bool = False
    redis: bool = False
    observability: bool = True
    workload: WorkloadProfile = Field(default_factory=WorkloadProfile)
    cost_center: str = Field(min_length=2, max_length=32)


class Plan(BaseModel):
    request_id: UUID
    resources: list[str]
    estimated_monthly_usd: float
    estimated_ttl_usd: float | None
    requires_approval: bool
    policy_notes: list[str] = Field(default_factory=list)


class AuditEvent(BaseModel):
    event_id: UUID = Field(default_factory=uuid4)
    request_id: UUID
    actor: str
    tenant_id: str
    action: str
    state: LifecycleState
    occurred_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    details: dict[str, str] = Field(default_factory=dict)


class Environment(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    request: EnvironmentRequest
    tenant_id: str
    owner: str
    state: LifecycleState = LifecycleState.REQUESTED
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    expires_at: datetime | None = None
    plan: Plan | None = None
    gitops_path: str | None = None
    endpoint: str | None = None
    failure_reason: str | None = None

    @classmethod
    def from_request(cls, request: EnvironmentRequest, actor: Actor) -> Environment:
        expires = None
        if request.ttl_hours:
            expires = datetime.now(UTC) + timedelta(hours=request.ttl_hours)
        return cls(
            request=request, tenant_id=actor.tenant_id, owner=actor.subject, expires_at=expires
        )
