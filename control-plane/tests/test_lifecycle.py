from pathlib import Path

from platform_control_plane.models.domain import (
    Actor,
    EnvironmentRequest,
    EnvironmentType,
    LifecycleState,
    Role,
)
from platform_control_plane.provisioning.service import EnvironmentService


def developer():
    return Actor(subject="ada", tenant_id="team-demo", roles={Role.DEVELOPER})


def test_dev_environment_is_rendered_and_ready(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    result = service.create(
        developer(),
        EnvironmentRequest(
            name="demo-api",
            team="team-demo",
            environment_type=EnvironmentType.DEVELOPMENT,
            ttl_hours=12,
            postgresql=True,
            redis=True,
            cost_center="ENG",
            idempotency_key="demo-request-001",
        ),
    )
    assert result.state is LifecycleState.READY
    assert result.gitops_path
    assert len(service.audit.list(result.request.request_id)) >= 4


def test_agent_production_is_rejected(tmp_path: Path):
    actor = Actor(
        subject="agent", tenant_id="team-demo", roles={Role.AGENT_REQUESTER}, is_agent=True
    )
    service = EnvironmentService(tmp_path / "environments")
    result = service.create(
        actor,
        EnvironmentRequest(
            name="prod-api",
            team="team-demo",
            environment_type=EnvironmentType.PRODUCTION,
            cost_center="ENG",
            idempotency_key="agent-production-001",
        ),
    )
    assert result.state is LifecycleState.REJECTED
    assert "agents cannot autonomously request production" in result.failure_reason


def test_production_requires_operator_approval(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    request = EnvironmentRequest(
        name="payments-api",
        team="team-demo",
        environment_type=EnvironmentType.PRODUCTION,
        cost_center="ENG",
        idempotency_key="production-request-001",
    )
    env = service.create(developer(), request)
    assert env.state is LifecycleState.APPROVAL_REQUIRED
    operator = Actor(subject="operator", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR})
    assert service.approve(operator, env.id).state is LifecycleState.READY


def test_idempotency_returns_original_environment(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    request = EnvironmentRequest(
        name="demo-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="dedupe-key-123",
    )
    assert service.create(developer(), request).id == service.create(developer(), request).id
