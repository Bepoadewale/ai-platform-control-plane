import sqlite3
from collections import defaultdict
from pathlib import Path
from uuid import UUID

from platform_control_plane.models.domain import AuditEvent


class AuditRepository:
    def __init__(self, database_path: Path | None = None) -> None:
        self._events: dict[UUID, list[AuditEvent]] = defaultdict(list)
        self.connection: sqlite3.Connection | None = None
        if database_path is not None:
            database_path.parent.mkdir(parents=True, exist_ok=True)
            self.connection = sqlite3.connect(database_path)
            self.connection.row_factory = sqlite3.Row
            self.connection.execute(
                """
                CREATE TABLE IF NOT EXISTS audit_events (
                  event_id TEXT PRIMARY KEY,
                  request_id TEXT NOT NULL,
                  payload TEXT NOT NULL
                )
                """
            )
            self.connection.commit()

    def append(self, event: AuditEvent) -> None:
        self._events[event.request_id].append(event)
        if self.connection is not None:
            self.connection.execute(
                "INSERT OR IGNORE INTO audit_events (event_id, request_id, payload) VALUES (?, ?, ?)",
                (str(event.event_id), str(event.request_id), event.model_dump_json()),
            )
            self.connection.commit()

    def list(self, request_id: UUID) -> list[AuditEvent]:
        if self.connection is not None:
            rows = self.connection.execute(
                "SELECT payload FROM audit_events WHERE request_id = ? ORDER BY rowid", (str(request_id),)
            ).fetchall()
            return [AuditEvent.model_validate_json(row["payload"]) for row in rows]
        return self._events[request_id].copy()

    def close(self) -> None:
        if self.connection is not None:
            self.connection.close()
