"""A local kind reconciler that applies the versioned golden-path Helm chart."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Protocol

from platform_control_plane.models.domain import Environment


class ReconciliationError(RuntimeError):
    """Desired state could not be reconciled or observed as ready."""


class Reconciler(Protocol):
    def apply(self, environment: Environment, values_path: Path) -> str: ...

    def destroy(self, environment: Environment) -> None: ...


class RenderOnlyReconciler:
    """Explicit local unit-test adapter; it never represents Kubernetes execution."""

    def apply(self, environment: Environment, values_path: Path) -> str:
        del values_path
        return f"rendered://{environment.request.team}/{environment.request.name}"

    def destroy(self, environment: Environment) -> None:
        del environment


class KindHelmReconciler:
    """Apply rendered state through Helm and wait for Kubernetes readiness."""

    def __init__(self, chart_path: Path, release_namespace: str = "platform-system") -> None:
        self.chart_path = chart_path
        self.release_namespace = release_namespace

    @classmethod
    def from_environment(cls) -> Reconciler:
        if os.getenv("PLATFORM_RECONCILER", "render-only") != "kind":
            return RenderOnlyReconciler()
        chart_path = Path(os.getenv("PLATFORM_HELM_CHART", "platform/helm/golden-path"))
        return cls(chart_path)

    @staticmethod
    def _run(command: list[str]) -> None:
        try:
            subprocess.run(command, check=True, text=True, capture_output=True, timeout=180)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            output = getattr(error, "stderr", "") or getattr(error, "stdout", "") or str(error)
            raise ReconciliationError(str(output).strip()) from error

    @staticmethod
    def _namespace(environment: Environment) -> str:
        return f"{environment.request.team}-{environment.request.name}"

    @staticmethod
    def _release(environment: Environment) -> str:
        return f"env-{str(environment.id)[:8]}"

    def apply(self, environment: Environment, values_path: Path) -> str:
        namespace = self._namespace(environment)
        release = self._release(environment)
        self._run(
            [
                "helm",
                "upgrade",
                "--install",
                release,
                str(self.chart_path),
                "--namespace",
                self.release_namespace,
                "--create-namespace",
                "--values",
                str(values_path),
                "--set",
                "ingress.enabled=false",
                "--wait",
                "--timeout",
                "150s",
            ]
        )
        self._run(
            [
                "kubectl",
                "rollout",
                "status",
                f"deployment/{environment.request.name}",
                "--namespace",
                namespace,
                "--timeout=120s",
            ]
        )
        return f"http://{environment.request.name}.{namespace}.svc.cluster.local"

    def destroy(self, environment: Environment) -> None:
        self._run(
            [
                "helm",
                "uninstall",
                self._release(environment),
                "--namespace",
                self.release_namespace,
                "--ignore-not-found",
                "--wait",
            ]
        )
        self._run(
            [
                "kubectl",
                "delete",
                "namespace",
                self._namespace(environment),
                "--ignore-not-found=true",
                "--wait=true",
                "--timeout=120s",
            ]
        )
