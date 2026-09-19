import sqlite3
from pathlib import Path

from platform_control_plane.models.domain import Environment


class EnvironmentRepository:
    """SQLite persistence for local lifecycle state and idempotency keys.

    The repository intentionally owns serialization at the boundary so the domain
    service can retain its current state-machine API while surviving process restarts.
    """

    def __init__(self, database_path: Path | None = None) -> None:
        target = ":memory:" if database_path is None else str(database_path)
        if database_path is not None:
            database_path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(target)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute(
            """
            CREATE TABLE IF NOT EXISTS environments (
              id TEXT PRIMARY KEY,
              tenant_id TEXT NOT NULL,
              idempotency_key TEXT NOT NULL,
              payload TEXT NOT NULL,
              UNIQUE (tenant_id, idempotency_key)
            )
            """
        )
        self.connection.commit()

    def load_all(self) -> list[Environment]:
        rows = self.connection.execute("SELECT payload FROM environments").fetchall()
        return [Environment.model_validate_json(row["payload"]) for row in rows]

    def upsert(self, environment: Environment) -> None:
        self.connection.execute(
            """
            INSERT INTO environments (id, tenant_id, idempotency_key, payload)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET payload = excluded.payload
            """,
            (
                str(environment.id),
                environment.tenant_id,
                environment.request.idempotency_key,
                environment.model_dump_json(),
            ),
        )
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()
