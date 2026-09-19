from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
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
    assert service.approve(operator, env.id, env.plan.plan_hash).state is LifecycleState.READY


def test_production_approval_is_bound_to_plan_and_cannot_self_approve(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    requester = Actor(
        subject="operator-requester", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR}
    )
    env = service.create(
        requester,
        EnvironmentRequest(
            name="approval-api",
            team="team-demo",
            environment_type=EnvironmentType.PRODUCTION,
            cost_center="ENG",
            idempotency_key="approval-bound-request-001",
        ),
    )
    with pytest.raises(PermissionError):
        service.approve(requester, env.id, env.plan.plan_hash)
    approver = Actor(subject="another-operator", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR})
    with pytest.raises(ValueError, match="STALE_PLAN"):
        service.approve(approver, env.id, "0" * 64)
    assert service.approve(approver, env.id, env.plan.plan_hash).approval.plan_hash == env.plan.plan_hash


def test_production_destroy_requires_distinct_exact_plan_approval(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    requester = Actor(
        subject="production-owner", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR}
    )
    approver = Actor(subject="production-approver", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR})
    env = service.create(
        requester,
        EnvironmentRequest(
            name="production-destroy-api",
            team="team-demo",
            environment_type=EnvironmentType.PRODUCTION,
            cost_center="ENG",
            idempotency_key="production-destroy-request-001",
        ),
    )
    assert service.approve(approver, env.id, env.plan.plan_hash).state is LifecycleState.READY
    assert service.destroy(requester, env.id).state is LifecycleState.DESTROY_PENDING
    with pytest.raises(PermissionError):
        service.approve_destroy(requester, env.id, env.destroy_plan.plan_hash)
    with pytest.raises(ValueError, match="STALE_PLAN"):
        service.approve_destroy(approver, env.id, "0" * 64)
    assert service.approve_destroy(approver, env.id, env.destroy_plan.plan_hash).state is LifecycleState.DESTROYED


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


def test_expired_environment_is_destroyed_and_audited(tmp_path: Path):
    service = EnvironmentService(tmp_path / "environments")
    environment = service.create(
        developer(),
        EnvironmentRequest(
            name="ttl-api",
            team="team-demo",
            environment_type=EnvironmentType.DEVELOPMENT,
            ttl_hours=1,
            cost_center="ENG",
            idempotency_key="ttl-reap-request-001",
        ),
    )
    environment.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    expired = service.expire_due(developer())

    assert [item.id for item in expired] == [environment.id]
    assert environment.state is LifecycleState.DESTROYED
    assert service.audit.list(environment.request.request_id)[-1].action == "destroy.complete"


def test_lifecycle_and_audit_survive_service_restart(tmp_path: Path):
    database_path = tmp_path / "state" / "control-plane.db"
    request = EnvironmentRequest(
        name="durable-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="durable-request-001",
    )
    first = EnvironmentService(tmp_path / "environments", database_path)
    created = first.create(developer(), request)
    first.close()

    restarted = EnvironmentService(tmp_path / "environments", database_path)
    recovered = restarted.get(developer(), created.id)
    assert recovered.state is LifecycleState.READY
    assert recovered.request.idempotency_key == request.idempotency_key
    assert len(restarted.audit.list(created.request.request_id)) >= 4
    assert restarted.create(developer(), request).id == created.id
    restarted.close()


def test_recovery_reconciles_persisted_applying_environment_once(tmp_path: Path):
    database_path = tmp_path / "state" / "control-plane.db"
    first = EnvironmentService(tmp_path / "environments", database_path)
    created = first.create(
        developer(),
        EnvironmentRequest(
            name="recover-api",
            team="team-demo",
            environment_type=EnvironmentType.DEVELOPMENT,
            cost_center="ENG",
            idempotency_key="recovery-request-001",
        ),
    )
    created.state = LifecycleState.APPLYING
    first.repository.upsert(created)
    first.close()

    operator = Actor(subject="operator", tenant_id="team-demo", roles={Role.PLATFORM_OPERATOR})
    restarted = EnvironmentService(tmp_path / "environments", database_path)
    recovered = restarted.recover_pending(operator)

    assert [environment.id for environment in recovered] == [created.id]
    assert recovered[0].state is LifecycleState.READY
    assert restarted.recover_pending(operator) == []
    assert any(
        event.action == "reconciliation.recovery_started"
        for event in restarted.audit.list(created.request.request_id)
    )
    restarted.close()
