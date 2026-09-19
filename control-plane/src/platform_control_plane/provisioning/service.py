from pathlib import Path
from uuid import UUID

from platform_control_plane.audit.repository import AuditRepository
from platform_control_plane.gitops.renderer import GitOpsRenderer
from platform_control_plane.models.domain import (
    Actor,
    AuditEvent,
    Environment,
    EnvironmentRequest,
    LifecycleState,
)
from platform_control_plane.persistence.repository import EnvironmentRepository
from platform_control_plane.planner.service import Planner
from platform_control_plane.policy.engine import PolicyEngine


class EnvironmentService:
    def __init__(self, desired_state_root: Path, database_path: Path | None = None) -> None:
        self.policy = PolicyEngine()
        self.planner = Planner()
        self.audit = AuditRepository(database_path)
        self.renderer = GitOpsRenderer(desired_state_root)
        self.repository = EnvironmentRepository(database_path)
        loaded = self.repository.load_all()
        self._environments: dict[UUID, Environment] = {environment.id: environment for environment in loaded}
        self._keys: dict[tuple[str, str], UUID] = {
            (environment.tenant_id, environment.request.idempotency_key): environment.id
            for environment in loaded
        }

    def _event(self, env: Environment, actor: Actor, action: str, **details: str) -> None:
        self.audit.append(
            AuditEvent(
                request_id=env.request.request_id,
                actor=actor.subject,
                tenant_id=actor.tenant_id,
                action=action,
                state=env.state,
                details=details,
            )
        )
        self.repository.upsert(env)

    def create(self, actor: Actor, request: EnvironmentRequest) -> Environment:
        key = (actor.tenant_id, request.idempotency_key)
        if key in self._keys:
            return self._environments[self._keys[key]]
        env = Environment.from_request(request, actor)
        self._environments[env.id] = env
        self._keys[key] = env.id
        self._event(env, actor, "environment.requested")
        env.state = LifecycleState.VALIDATING
        self._event(env, actor, "policy.evaluating")
        decision = self.policy.evaluate(actor, request)
        if not decision.allowed:
            env.state = LifecycleState.REJECTED
            env.failure_reason = "; ".join(decision.reasons)
            self._event(env, actor, "policy.rejected", reasons=env.failure_reason)
            return env
        env.plan = self.planner.plan(request)
        env.state = LifecycleState.PLANNED
        self._event(env, actor, "environment.planned")
        if decision.approval_required:
            env.state = LifecycleState.APPROVAL_REQUIRED
            self._event(env, actor, "approval.required")
            return env
        return self._apply(env, actor)

    def _apply(self, env: Environment, actor: Actor) -> Environment:
        env.state = LifecycleState.APPLYING
        self._event(env, actor, "gitops.rendering")
        env.gitops_path = self.renderer.render(env)
        env.endpoint = f"https://{env.request.name}.{env.request.team}.local.platform.example"
        env.state = LifecycleState.READY
        self._event(env, actor, "environment.ready", gitops_path=env.gitops_path)
        return env

    def close(self) -> None:
        self.repository.close()
        self.audit.close()

    def approve(self, actor: Actor, environment_id: UUID) -> Environment:
        env = self.get(actor, environment_id)
        if env.state != LifecycleState.APPROVAL_REQUIRED:
            raise ValueError("environment is not awaiting approval")
        if not ({"platform-operator", "platform-admin"} & {r.value for r in actor.roles}):
            raise PermissionError("platform operator role required")
        env.state = LifecycleState.APPROVED
        self._event(env, actor, "approval.granted")
        return self._apply(env, actor)

    def get(self, actor: Actor, environment_id: UUID) -> Environment:
        env = self._environments[environment_id]
        if env.tenant_id != actor.tenant_id and "platform-admin" not in {
            r.value for r in actor.roles
        }:
            raise PermissionError("tenant boundary violation")
        return env

    def list(self, actor: Actor) -> list[Environment]:
        if "platform-admin" in {r.value for r in actor.roles}:
            return list(self._environments.values())
        return [e for e in self._environments.values() if e.tenant_id == actor.tenant_id]

    def destroy(self, actor: Actor, environment_id: UUID) -> Environment:
        env = self.get(actor, environment_id)
        if env.request.environment_type.value == "production":
            raise PermissionError("production destruction requires an approval workflow")
        env.state = LifecycleState.DESTROY_PENDING
        self._event(env, actor, "destroy.requested")
        env.state = LifecycleState.DESTROYING
        self._event(env, actor, "destroy.applying")
        env.state = LifecycleState.DESTROYED
        self._event(env, actor, "destroy.complete")
        return env

    def expire_due(self, actor: Actor) -> list[Environment]:
        from datetime import UTC, datetime

        expired = []
        for env in self.list(actor):
            if (
                env.expires_at
                and env.expires_at < datetime.now(UTC)
                and env.state == LifecycleState.READY
            ):
                expired.append(self.destroy(actor, env.id))
        return expired
