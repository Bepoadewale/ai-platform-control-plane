from pathlib import Path

from platform_control_plane.gitops.github import GitOpsPublicationError
from platform_control_plane.gitops.worker import GitOpsWorker
from platform_control_plane.models.domain import (
    Actor,
    EnvironmentRequest,
    EnvironmentType,
    LifecycleState,
    ReconciliationJobState,
    Role,
)
from platform_control_plane.provisioning.service import EnvironmentService


class RecordingPublisher:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.calls: list[dict[str, str]] = []

    def publish(self, **kwargs: str) -> str:
        self.calls.append(kwargs)
        if self.fail:
            raise GitOpsPublicationError("GitHub unavailable")
        return "https://github.example/owner/repo/pull/42"


def developer() -> Actor:
    return Actor(subject="ada", tenant_id="team-demo", roles={Role.DEVELOPER})


def request() -> EnvironmentRequest:
    return EnvironmentRequest(
        name="gitops-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="gitops-worker-request-001",
    )


def test_worker_publishes_durable_job_without_claiming_kubernetes_readiness(tmp_path: Path) -> None:
    database = tmp_path / "state.db"
    service = EnvironmentService(
        tmp_path / "environments", database, reconciliation_mode="gitops-worker"
    )
    environment = service.create(developer(), request())
    assert environment.state is LifecycleState.APPLYING
    assert len(service.pending_reconciliation_jobs()) == 1
    service.close()

    restarted = EnvironmentService(
        tmp_path / "environments", database, reconciliation_mode="gitops-worker"
    )
    publisher = RecordingPublisher()
    processed = GitOpsWorker(restarted, publisher).run_once()

    assert [job.state for job in processed] == [ReconciliationJobState.PUBLISHED]
    assert publisher.calls[0]["path"] == environment.gitops_path
    recovered = restarted.get(developer(), environment.id)
    assert recovered.state is LifecycleState.APPLYING
    assert recovered.endpoint == "https://github.example/owner/repo/pull/42"
    assert restarted.pending_reconciliation_jobs() == []
    assert len(restarted.reconciliation_jobs(developer(), environment.id)) == 1
    assert any(
        event.action == "gitops.pull_request_created"
        for event in restarted.audit_events(recovered.request.request_id)
    )
    restarted.close()


def test_worker_records_failed_publication_without_direct_reconciliation(tmp_path: Path) -> None:
    service = EnvironmentService(
        tmp_path / "environments", tmp_path / "state.db", reconciliation_mode="gitops-worker"
    )
    environment = service.create(developer(), request())
    processed = GitOpsWorker(service, RecordingPublisher(fail=True)).run_once()

    assert processed[0].state is ReconciliationJobState.FAILED
    assert environment.state is LifecycleState.FAILED
    assert "GitHub unavailable" in (environment.failure_reason or "")
    assert any(
        event.action == "gitops.publication_failed"
        for event in service.audit_events(environment.request.request_id)
    )
    service.close()
