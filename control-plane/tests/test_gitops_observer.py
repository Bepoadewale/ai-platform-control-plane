from pathlib import Path

from platform_control_plane.gitops.observer import (
    EnvironmentObservation,
    EnvironmentStatusObserver,
)
from platform_control_plane.gitops.worker import GitOpsWorker
from platform_control_plane.models.domain import (
    Actor,
    EnvironmentRequest,
    EnvironmentType,
    LifecycleState,
    Role,
)
from platform_control_plane.provisioning.service import EnvironmentService


class Publisher:
    def publish(self, **_: str) -> str:
        return "https://github.example/owner/repo/pull/42"

    def delete(self, **_: str) -> str:
        return "https://github.example/owner/repo/pull/43"


class StatusClient:
    def __init__(self, state: str, reason: str | None = None) -> None:
        self.result = EnvironmentObservation(state, reason)  # type: ignore[arg-type]

    def observe(self, _):
        return self.result


def developer() -> Actor:
    return Actor(subject="ada", tenant_id="team-demo", roles={Role.DEVELOPER})


def request() -> EnvironmentRequest:
    return EnvironmentRequest(
        name="observed-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="status-observer-request-001",
    )


def published_environment(tmp_path: Path):
    service = EnvironmentService(
        tmp_path / "environments", tmp_path / "state.db", reconciliation_mode="gitops-worker"
    )
    environment = service.create(developer(), request())
    GitOpsWorker(service, Publisher()).run_once()
    return service, environment


def test_observer_marks_argo_ready_workload_ready(tmp_path: Path) -> None:
    service, environment = published_environment(tmp_path)
    observed = EnvironmentStatusObserver(service, StatusClient("READY")).run_once()

    assert [item.id for item in observed] == [environment.id]
    assert service.get(developer(), environment.id).state is LifecycleState.READY
    assert any(
        event.action == "reconciliation.ready"
        for event in service.audit_events(environment.request.request_id)
    )
    service.close()


def test_observer_records_degraded_argo_workload_as_failed(tmp_path: Path) -> None:
    service, environment = published_environment(tmp_path)
    EnvironmentStatusObserver(service, StatusClient("FAILED", "Argo health is Degraded")).run_once()

    persisted = service.get(developer(), environment.id)
    assert persisted.state is LifecycleState.FAILED
    assert persisted.failure_reason == "Argo health is Degraded"
    assert any(
        event.action == "reconciliation.failed"
        for event in service.audit_events(environment.request.request_id)
    )
    service.close()


def test_observer_marks_destroyed_only_after_argo_application_is_absent(tmp_path: Path) -> None:
    service, environment = published_environment(tmp_path)
    EnvironmentStatusObserver(service, StatusClient("READY")).run_once()
    assert service.destroy(developer(), environment.id).state is LifecycleState.DESTROYING
    GitOpsWorker(service, Publisher()).run_once()

    observed = EnvironmentStatusObserver(service, StatusClient("ABSENT")).run_once()
    assert [item.id for item in observed] == [environment.id]
    assert service.get(developer(), environment.id).state is LifecycleState.DESTROYED
    assert any(
        event.action == "destroy.complete"
        for event in service.audit_events(environment.request.request_id)
    )
    service.close()
