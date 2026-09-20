from pathlib import Path

from platform_control_plane.models.domain import (
    Actor,
    Environment,
    EnvironmentRequest,
    EnvironmentType,
    Role,
)
from platform_control_plane.reconciliation.helm import KindHelmReconciler


def environment() -> Environment:
    request = EnvironmentRequest(
        name="kind-api",
        team="team-demo",
        environment_type=EnvironmentType.DEVELOPMENT,
        cost_center="ENG",
        idempotency_key="kind-reconciler-test-001",
    )
    return Environment.from_request(
        request,
        Actor(subject="ada", tenant_id="team-demo", roles={Role.DEVELOPER}),
    )


def test_kind_reconciler_applies_and_observes_deployment(monkeypatch, tmp_path: Path):
    commands: list[list[str]] = []
    reconciler = KindHelmReconciler(tmp_path / "chart")
    monkeypatch.setattr(reconciler, "_run", lambda command: commands.append(command))

    result = reconciler.apply(environment(), tmp_path / "values.yaml")

    assert result == "http://kind-api.team-demo-kind-api.svc.cluster.local"
    assert commands[0][:4] == ["helm", "upgrade", "--install", commands[0][3]]
    assert "--wait" in commands[0]
    assert commands[1][:3] == ["kubectl", "rollout", "status"]


def test_kind_reconciler_destroy_is_idempotent(monkeypatch, tmp_path: Path):
    commands: list[list[str]] = []
    reconciler = KindHelmReconciler(tmp_path / "chart")
    monkeypatch.setattr(reconciler, "_run", lambda command: commands.append(command))

    reconciler.destroy(environment())

    assert "--ignore-not-found" in commands[0]
    assert "--ignore-not-found=true" in commands[1]
