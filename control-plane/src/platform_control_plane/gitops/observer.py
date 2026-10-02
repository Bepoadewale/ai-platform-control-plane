"""Read-only Argo/Kubernetes status observer for the cloud GitOps path."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, Protocol

import httpx
from platform_control_plane.models.domain import (
    Actor,
    Environment,
    LifecycleState,
    ReconciliationAction,
    Role,
)
from platform_control_plane.provisioning.service import EnvironmentService

ObservationState = Literal["ABSENT", "PENDING", "READY", "FAILED"]


@dataclass(frozen=True)
class EnvironmentObservation:
    state: ObservationState
    reason: str | None = None


class EnvironmentStatusClient(Protocol):
    def observe(self, environment: Environment) -> EnvironmentObservation: ...


class KubernetesArgoStatusClient:
    """Uses the in-cluster service account token; no shell or write API calls are used."""

    def __init__(self, base_url: str | None = None, token_path: Path | None = None) -> None:
        self.base_url = base_url or os.getenv("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
        if not self.base_url.startswith("http"):
            self.base_url = f"https://{self.base_url}"
        self.token_path = token_path or Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
        self.ca_path = Path("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")

    def _get(self, path: str) -> dict:
        if not self.token_path.is_file():
            raise RuntimeError("in-cluster service account token is unavailable")
        response = httpx.get(
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self.token_path.read_text(encoding='utf-8').strip()}"},
            verify=str(self.ca_path) if self.ca_path.is_file() else True,
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()

    def observe(self, environment: Environment) -> EnvironmentObservation:
        application = f"environment-{environment.request.name}"
        try:
            application_data = self._get(
                f"/apis/argoproj.io/v1alpha1/namespaces/argocd/applications/{application}"
            )
        except httpx.HTTPStatusError as error:
            if error.response.status_code == 404:
                return EnvironmentObservation("ABSENT", "Argo Application is absent")
            raise
        status = application_data.get("status", {})
        sync = status.get("sync", {}).get("status")
        if sync != "Synced":
            return EnvironmentObservation("PENDING", f"Argo sync={sync or 'Unknown'}")
        namespace = f"{environment.request.team}-{environment.request.name}"
        try:
            deployment = self._get(
                f"/apis/apps/v1/namespaces/{namespace}/deployments/{environment.request.name}"
            )
        except httpx.HTTPStatusError as error:
            if error.response.status_code == 404:
                return EnvironmentObservation("PENDING", "Argo application is synced; Deployment is not present yet")
            raise
        desired = deployment.get("spec", {}).get("replicas", 1)
        deployment_status = deployment.get("status", {})
        available = deployment_status.get("availableReplicas", 0)
        if available < desired:
            for condition in deployment_status.get("conditions", []):
                if condition.get("type") == "Progressing" and condition.get("status") == "False":
                    return EnvironmentObservation("FAILED", condition.get("message") or "Deployment progress deadline exceeded")
                if condition.get("type") == "ReplicaFailure" and condition.get("status") == "True":
                    return EnvironmentObservation("FAILED", condition.get("message") or "Deployment replica failure")
            return EnvironmentObservation("PENDING", f"Deployment available={available}/{desired}")
        return EnvironmentObservation("READY")


class EnvironmentStatusObserver:
    def __init__(self, service: EnvironmentService, client: EnvironmentStatusClient) -> None:
        self.service = service
        self.client = client
        self.actor = Actor(
            subject="system:argo-observer",
            tenant_id="platform-system",
            roles={Role.PLATFORM_OPERATOR},
        )

    def run_once(self) -> list[Environment]:
        self.service.refresh_from_store()
        observed: list[Environment] = []
        published_actions = {
            job.environment_id: job.action
            for job in self.service.repository.load_jobs()
            if job.state.value == "PUBLISHED"
        }
        for environment in self.service._environments.values():
            action = published_actions.get(environment.id)
            if action is None:
                continue
            result = self.client.observe(environment)
            if action is ReconciliationAction.DESTROY:
                if environment.state is not LifecycleState.DESTROYING or result.state != "ABSENT":
                    continue
                environment.state = LifecycleState.DESTROYED
                self.service._event(environment, self.actor, "destroy.complete")
                observed.append(environment)
                continue
            if environment.state is not LifecycleState.APPLYING:
                continue
            if result.state == "ABSENT":
                continue
            if result.state == "PENDING":
                continue
            if result.state == "READY":
                environment.state = LifecycleState.READY
                environment.failure_reason = None
                self.service._event(environment, self.actor, "reconciliation.ready")
            else:
                environment.state = LifecycleState.FAILED
                environment.failure_reason = result.reason or "Argo/Kubernetes reconciliation failed"
                self.service._event(
                    environment,
                    self.actor,
                    "reconciliation.failed",
                    reason=environment.failure_reason,
                )
            observed.append(environment)
        return observed


def main() -> None:
    database_target = os.environ.get("PLATFORM_DATABASE_URL") or os.environ.get(
        "PLATFORM_CONTROL_PLANE_DB", "state/control-plane.db"
    )
    service = EnvironmentService(
        Path(os.environ.get("PLATFORM_DESIRED_STATE_ROOT", "environments")),
        database_target if database_target.startswith("postgres") else Path(database_target),
        reconciliation_mode="gitops-worker",
    )
    observer = EnvironmentStatusObserver(service, KubernetesArgoStatusClient())
    poll_seconds = max(2, int(os.getenv("PLATFORM_STATUS_OBSERVER_POLL_SECONDS", "10")))
    while True:
        observer.run_once()
        time.sleep(poll_seconds)


if __name__ == "__main__":  # pragma: no cover - executed by runtime manifest
    main()
