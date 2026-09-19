from __future__ import annotations

from pathlib import Path
from uuid import UUID

from platform_control_plane.audit.repository import AuditRepository
from platform_control_plane.gitops.renderer import GitOpsRenderer
from platform_control_plane.models.domain import (
    Actor,
    Approval,
    AuditEvent,
    Environment,
    EnvironmentRequest,
    LifecycleState,
)
from platform_control_plane.persistence.repository import EnvironmentRepository
from platform_control_plane.planner.service import Planner
from platform_control_plane.policy.engine import OPAPolicyEngine, PolicyEngine
from platform_control_plane.reconciliation.helm import (
    KindHelmReconciler,
    Reconciler,
    ReconciliationError,
)


class EnvironmentService:
    def __init__(
        self,
        desired_state_root: Path,
        database_path: Path | None = None,
        reconciler: Reconciler | None = None,
        policy: PolicyEngine | OPAPolicyEngine | None = None,
    ) -> None:
        self.policy = policy or OPAPolicyEngine.from_environment()
        self.planner = Planner()
        self.audit = AuditRepository(database_path)
        self.renderer = GitOpsRenderer(desired_state_root)
        self.reconciler = reconciler or KindHelmReconciler.from_environment()
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
        current_plan = self.planner.plan(env.request)
        if env.plan is None or current_plan.plan_hash != env.plan.plan_hash:
            env.state = LifecycleState.FAILED
            env.failure_reason = "STALE_PLAN: request no longer matches approved plan"
            self._event(env, actor, "plan.stale", reason=env.failure_reason)
            return env
        env.state = LifecycleState.APPLYING
        self._event(env, actor, "gitops.rendering")
        env.gitops_path = self.renderer.render(env)
        try:
            env.endpoint = self.reconciler.apply(env, self.renderer.root.parent / env.gitops_path)
        except ReconciliationError as error:
            env.state = LifecycleState.FAILED
            env.failure_reason = str(error)
            self._event(env, actor, "reconciliation.failed", reason=env.failure_reason)
            return env
        env.state = LifecycleState.READY
        self._event(env, actor, "environment.ready", gitops_path=env.gitops_path, endpoint=env.endpoint)
        return env

    def close(self) -> None:
        self.repository.close()
        self.audit.close()

    def approve(self, actor: Actor, environment_id: UUID, plan_hash: str) -> Environment:
        env = self.get(actor, environment_id)
        if env.state != LifecycleState.APPROVAL_REQUIRED:
            raise ValueError("environment is not awaiting approval")
        if not ({"platform-operator", "platform-admin"} & {r.value for r in actor.roles}):
            raise PermissionError("platform operator role required")
        if actor.subject == env.owner:
            raise PermissionError("requester cannot approve their own protected request")
        if env.plan is None or plan_hash != env.plan.plan_hash:
            raise ValueError("STALE_PLAN: approval does not match current plan")
        current_plan = self.planner.plan(env.request)
        if current_plan.plan_hash != env.plan.plan_hash:
            raise ValueError("STALE_PLAN: request changed after planning")
        env.approval = Approval(
            environment_id=env.id,
            plan_hash=env.plan.plan_hash,
            requested_by=env.owner,
            approved_by=actor.subject,
        )
        env.state = LifecycleState.APPROVED
        self._event(env, actor, "approval.granted", plan_hash=env.plan.plan_hash)
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
        try:
            self.reconciler.destroy(env)
        except ReconciliationError as error:
            env.state = LifecycleState.FAILED
            env.failure_reason = str(error)
            self._event(env, actor, "destroy.failed", reason=env.failure_reason)
            return env
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
