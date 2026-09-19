from pathlib import Path

from platform_control_plane.models.domain import Environment


class GitOpsRenderer:
    """Renders desired state only; a GitOps controller performs reconciliation."""

    def __init__(self, root: Path):
        self.root = root

    def render(self, environment: Environment) -> str:
        request = environment.request
        path = self.root / request.team / request.name / "values.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        content = "\n".join(
            [
                f"name: {request.name}",
                f"namespace: {request.team}-{request.name}",
                f"team: {request.team}",
                f"environmentType: {request.environment_type}",
                f"ttlHours: {request.ttl_hours or 0}",
                f"profile: {request.workload.size}",
                f"postgresql: {str(request.postgresql).lower()}",
                f"redis: {str(request.redis).lower()}",
                f"objectStorage: {str(request.object_storage).lower()}",
                f"serviceExposure: {request.service_exposure}",
                f"image: {request.image}",
                "observability: true",
                "",
            ]
        )
        path.write_text(content, encoding="utf-8")
        return str(path.relative_to(self.root.parent))
