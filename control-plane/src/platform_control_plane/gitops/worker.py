"""Durable GitOps publication worker.

The HTTP API creates a durable job after policy, planning and approval.  This worker is
the only component that can turn rendered desired state into a GitHub pull request.
It intentionally cannot call Helm/kubectl and never treats PR publication as readiness.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Protocol

from platform_control_plane.gitops.github import GitOpsPublicationError
from platform_control_plane.models.domain import (
    LifecycleState,
    ReconciliationAction,
    ReconciliationJob,
    ReconciliationJobState,
)
from platform_control_plane.provisioning.service import EnvironmentService


class DesiredStatePublisher(Protocol):
    def publish(self, *, path: str, content: str, change_id: str, title: str) -> str: ...


class GitOpsWorker:
    """Publishes pending jobs once; safely retries only explicit pending/failed jobs."""

    def __init__(self, service: EnvironmentService, publisher: DesiredStatePublisher) -> None:
        self.service = service
        self.publisher = publisher

    def run_once(self) -> list[ReconciliationJob]:
        processed: list[ReconciliationJob] = []
        for job in self.service.pending_reconciliation_jobs():
            processed.append(self._publish(job))
        return processed

    def _publish(self, job: ReconciliationJob) -> ReconciliationJob:
        if job.action is not ReconciliationAction.APPLY:
            return self._failed(job, "destroy publication is not implemented")
        environment = self.service._environments.get(job.environment_id)
        if environment is None or environment.gitops_path is None:
            return self._failed(job, "environment or rendered desired state is unavailable")
        if environment.state is not LifecycleState.APPLYING:
            return self._failed(job, f"environment is not applying: {environment.state.value}")
        job.state = ReconciliationJobState.PROCESSING
        job.attempts += 1
        job.updated_at = datetime.now(UTC)
        self.service.repository.update_job(job)
        path = environment.gitops_path
        content = (self.service.renderer.root.parent / path).read_text(encoding="utf-8")
        try:
            job.publication_url = self.publisher.publish(
                path=path,
                content=content,
                change_id=str(job.id),
                title=f"gitops: apply {environment.tenant_id}/{environment.request.name}",
            )
        except GitOpsPublicationError as error:
            return self._failed(job, str(error))
        job.state = ReconciliationJobState.PUBLISHED
        job.updated_at = datetime.now(UTC)
        self.service.repository.update_job(job)
        environment.endpoint = job.publication_url
        self.service._event(
            environment,
            job.actor,
            "gitops.pull_request_created",
            job_id=str(job.id),
            pull_request=job.publication_url,
        )
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
        return job
