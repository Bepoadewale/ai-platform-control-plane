import sqlite3
from datetime import datetime
from pathlib import Path
from threading import RLock

from platform_control_plane.models.domain import (
    Environment,
    ReconciliationJob,
    ReconciliationJobState,
)
from platform_control_plane.persistence.migrations import apply_migrations


class EnvironmentRepository:
    """SQLite persistence for local lifecycle state and idempotency keys.

    The repository intentionally owns serialization at the boundary so the domain
    service can retain its current state-machine API while surviving process restarts.
    """

    def __init__(self, database_path: Path | None = None) -> None:
        target = ":memory:" if database_path is None else str(database_path)
        if database_path is not None:
            database_path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(target, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.lock = RLock()
        with self.lock:
            apply_migrations(self.connection)

    def load_all(self) -> list[Environment]:
        with self.lock:
            rows = self.connection.execute("SELECT payload FROM environments").fetchall()
        return [Environment.model_validate_json(row["payload"]) for row in rows]

    def upsert(self, environment: Environment) -> None:
        with self.lock:
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

    def enqueue_job(self, job: ReconciliationJob) -> None:
        with self.lock:
            self.connection.execute(
                """INSERT INTO reconciliation_jobs (id, environment_id, state, payload, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    str(job.id),
                    str(job.environment_id),
                    job.state.value,
                    job.model_dump_json(),
                    job.created_at.isoformat(),
                    job.updated_at.isoformat(),
                ),
            )
            self.connection.commit()

    def load_jobs(self, states: set[ReconciliationJobState] | None = None) -> list[ReconciliationJob]:
        with self.lock:
            if states:
                placeholders = ", ".join("?" for _ in states)
                rows = self.connection.execute(
                    f"SELECT payload FROM reconciliation_jobs WHERE state IN ({placeholders}) ORDER BY created_at",  # noqa: S608
                    tuple(state.value for state in states),
                ).fetchall()
            else:
                rows = self.connection.execute("SELECT payload FROM reconciliation_jobs ORDER BY created_at").fetchall()
        return [ReconciliationJob.model_validate_json(row["payload"]) for row in rows]

    def update_job(self, job: ReconciliationJob) -> None:
        with self.lock:
            self.connection.execute(
                """UPDATE reconciliation_jobs
                SET state = ?, payload = ?, updated_at = ? WHERE id = ?""",
                (job.state.value, job.model_dump_json(), job.updated_at.isoformat(), str(job.id)),
            )
            self.connection.commit()

    def claim_job(self, job: ReconciliationJob) -> bool:
        """Atomically move one pending job to processing.

        Multiple GitOps worker replicas may see the same pending job.  The conditional
        state transition is the ownership boundary: only one worker is allowed to
        publish the GitHub change for a job id.
        """
        with self.lock:
            cursor = self.connection.execute(
                """UPDATE reconciliation_jobs
                SET state = ?, payload = ?, updated_at = ?
                WHERE id = ? AND state = ?""",
                (
                    job.state.value,
                    job.model_dump_json(),
                    job.updated_at.isoformat(),
                    str(job.id),
                    ReconciliationJobState.PENDING.value,
                ),
            )
            self.connection.commit()
        return cursor.rowcount == 1

    def requeue_stale_job(self, job: ReconciliationJob, stale_before: datetime) -> bool:
        """Return an abandoned processing job to the durable queue exactly once."""
        with self.lock:
            cursor = self.connection.execute(
                """UPDATE reconciliation_jobs
                SET state = ?, payload = ?, updated_at = ?
                WHERE id = ? AND state = ? AND updated_at <= ?""",
                (
                    job.state.value,
                    job.model_dump_json(),
                    job.updated_at.isoformat(),
                    str(job.id),
                    ReconciliationJobState.PROCESSING.value,
                    stale_before.isoformat(),
                ),
            )
            self.connection.commit()
        return cursor.rowcount == 1

    def close(self) -> None:
        with self.lock:
            self.connection.close()
