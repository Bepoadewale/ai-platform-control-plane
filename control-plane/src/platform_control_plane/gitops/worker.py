"""Durable GitOps publication worker.

The HTTP API creates a durable job after policy, planning and approval.  This worker is
the only component that can turn rendered desired state into a GitHub pull request.
It intentionally cannot call Helm/kubectl and never treats PR publication as readiness.
"""

from __future__ import annotations

import os
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol

from platform_control_plane.gitops.github import GitOpsPublicationError
from platform_control_plane.models.domain import (
    LifecycleState,
    ReconciliationAction,
    ReconciliationJob,
    ReconciliationJobState,
)
from platform_control_plane.observability.metrics import (
    RECONCILIATION_JOBS,
    RECONCILIATION_QUEUE_DEPTH,
)
from platform_control_plane.policy.engine import OPAPolicyEngine
from platform_control_plane.provisioning.service import EnvironmentService


class DesiredStatePublisher(Protocol):
    def publish(self, *, path: str, content: str, change_id: str, title: str) -> str: ...

    def delete(self, *, path: str, change_id: str, title: str) -> str: ...


class GitOpsWorker:
    """Publishes pending jobs once; safely retries only explicit pending/failed jobs."""

    def __init__(self, service: EnvironmentService, publisher: DesiredStatePublisher) -> None:
        self.service = service
        self.publisher = publisher

    def run_once(self) -> list[ReconciliationJob]:
        self.service.refresh_from_store()
        processed: list[ReconciliationJob] = []
        for job in self.service.pending_reconciliation_jobs():
            processed.append(self._publish(job))
        RECONCILIATION_QUEUE_DEPTH.set(len(self.service.pending_reconciliation_jobs()))
        return processed

    def _publish(self, job: ReconciliationJob) -> ReconciliationJob:
        environment = self.service._environments.get(job.environment_id)
        if environment is None or environment.gitops_path is None:
            return self._failed(job, "environment or rendered desired state is unavailable")
        expected_state = (
            LifecycleState.APPLYING if job.action is ReconciliationAction.APPLY else LifecycleState.DESTROYING
        )
        if environment.state is not expected_state:
            return self._failed(job, f"environment is not {expected_state.value.lower()}: {environment.state.value}")
        job.state = ReconciliationJobState.PROCESSING
        job.attempts += 1
        job.updated_at = datetime.now(UTC)
        self.service.repository.update_job(job)
        try:
            if job.action is ReconciliationAction.APPLY:
                # API and worker pods do not share a mutable filesystem. Re-rendering is deterministic
                # from the persisted request and allows a restarted worker to resume safely.
                path = self.service.renderer.render(environment)
                content = (self.service.renderer.root.parent / path).read_text(encoding="utf-8")
                job.publication_url = self.publisher.publish(
                    path=path,
                    content=content,
                    change_id=str(job.id),
                    title=f"gitops: apply {environment.tenant_id}/{environment.request.name}",
                )
            else:
                job.publication_url = self.publisher.delete(
                    path=environment.gitops_path,
                    change_id=str(job.id),
                    title=f"gitops: destroy {environment.tenant_id}/{environment.request.name}",
                )
        except GitOpsPublicationError as error:
            return self._failed(job, str(error))
        job.state = ReconciliationJobState.PUBLISHED
        job.updated_at = datetime.now(UTC)
        self.service.repository.update_job(job)
        environment.endpoint = job.publication_url
        event = "gitops.pull_request_created" if job.action is ReconciliationAction.APPLY else "gitops.destroy_pull_request_created"
        self.service._event(
            environment,
            job.actor,
            event,
            job_id=str(job.id),
            pull_request=job.publication_url,
        )
        RECONCILIATION_JOBS.labels(job.action.value, "published").inc()
        return job

    def _failed(self, job: ReconciliationJob, reason: str) -> ReconciliationJob:
        job.state = ReconciliationJobState.FAILED
        job.failure_reason = reason
        job.updated_at = datetime.now(UTC)
        self.service.repository.update_job(job)
        environment = self.service._environments.get(job.environment_id)
        if environment is not None:
            environment.state = LifecycleState.FAILED
            environment.failure_reason = f"GITOPS_PUBLICATION_FAILED: {reason}"
            self.service._event(environment, job.actor, "gitops.publication_failed", reason=reason)
        RECONCILIATION_JOBS.labels(job.action.value, "failed").inc()
        return job


def worker_from_environment() -> GitOpsWorker:
    """Build the separately deployed worker from scoped runtime configuration."""
    required = {
        "PLATFORM_GITHUB_APP_ID": os.getenv("PLATFORM_GITHUB_APP_ID"),
        "PLATFORM_GITHUB_APP_INSTALLATION_ID": os.getenv("PLATFORM_GITHUB_APP_INSTALLATION_ID"),
        "PLATFORM_GITHUB_REPOSITORY": os.getenv("PLATFORM_GITHUB_REPOSITORY"),
        "PLATFORM_GITHUB_APP_PRIVATE_KEY_PATH": os.getenv("PLATFORM_GITHUB_APP_PRIVATE_KEY_PATH"),
    }
    missing = [key for key, value in required.items() if not value]
    if missing:
        raise RuntimeError(f"GitOps worker configuration is incomplete: {', '.join(missing)}")
    from platform_control_plane.gitops.github import GitHubAppConfig, GitHubAppPublisher

    database_target = os.environ.get("PLATFORM_DATABASE_URL") or os.environ.get(
        "PLATFORM_CONTROL_PLANE_DB", "state/control-plane.db"
    )
    service = EnvironmentService(
        Path(os.environ.get("PLATFORM_DESIRED_STATE_ROOT", "environments")),
        database_target if database_target.startswith("postgres") else Path(database_target),
        policy=OPAPolicyEngine.from_environment(require_live=True),
        reconciliation_mode="gitops-worker",
    )
    publisher = GitHubAppPublisher(
        GitHubAppConfig(
            app_id=required["PLATFORM_GITHUB_APP_ID"] or "",
            installation_id=required["PLATFORM_GITHUB_APP_INSTALLATION_ID"] or "",
            repository=required["PLATFORM_GITHUB_REPOSITORY"] or "",
            private_key_path=Path(required["PLATFORM_GITHUB_APP_PRIVATE_KEY_PATH"] or ""),
            base_branch=os.getenv("PLATFORM_GITHUB_BASE_BRANCH", "main"),
        )
    )
    return GitOpsWorker(service, publisher)


def main() -> None:
    """Run a bounded-polling worker; Kubernetes restarts it after fatal configuration failures."""
    worker = worker_from_environment()
    poll_seconds = max(1, int(os.getenv("PLATFORM_GITOPS_WORKER_POLL_SECONDS", "5")))
    while True:
        worker.run_once()
        time.sleep(poll_seconds)


if __name__ == "__main__":  # pragma: no cover - exercised by the runtime manifest
    main()
