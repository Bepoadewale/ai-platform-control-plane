from collections import defaultdict
from uuid import UUID

from platform_control_plane.models.domain import AuditEvent


class AuditRepository:
    def __init__(self) -> None:
        self._events: dict[UUID, list[AuditEvent]] = defaultdict(list)

    def append(self, event: AuditEvent) -> None:
        self._events[event.request_id].append(event)

    def list(self, request_id: UUID) -> list[AuditEvent]:
        return self._events[request_id].copy()
