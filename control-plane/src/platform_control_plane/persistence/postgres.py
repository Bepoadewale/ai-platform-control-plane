"""PostgreSQL repositories for the production-shaped local Compose profile."""

from __future__ import annotations

from datetime import datetime
from threading import RLock
from uuid import UUID

import psycopg

from platform_control_plane.models.domain import (
    AuditEvent,
    Environment,
    ReconciliationJob,
    ReconciliationJobState,
)


class PostgresStore:
    def __init__(self, database_url: str) -> None:
        self.connection = psycopg.connect(database_url)
        self.lock = RLock()
        with self.connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS environments (
                  id UUID PRIMARY KEY, tenant_id TEXT NOT NULL, idempotency_key TEXT NOT NULL,
                  payload JSONB NOT NULL, UNIQUE (tenant_id, idempotency_key)
                );
                CREATE TABLE IF NOT EXISTS audit_events (
                  event_id UUID PRIMARY KEY, request_id UUID NOT NULL, payload JSONB NOT NULL,
                  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                CREATE TABLE IF NOT EXISTS reconciliation_jobs (
                  id UUID PRIMARY KEY, environment_id UUID NOT NULL, state TEXT NOT NULL,
                  payload JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL, updated_at TIMESTAMPTZ NOT NULL
                );
                CREATE INDEX IF NOT EXISTS reconciliation_jobs_pending
                  ON reconciliation_jobs (state, created_at);
                """
            )
        self.connection.commit()

    def load_all(self) -> list[Environment]:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute("SELECT payload::text FROM environments")
            return [Environment.model_validate_json(row[0]) for row in cursor.fetchall()]

    def upsert(self, environment: Environment) -> None:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                """INSERT INTO environments (id, tenant_id, idempotency_key, payload)
                VALUES (%s, %s, %s, %s::jsonb)
                ON CONFLICT (id) DO UPDATE SET payload = EXCLUDED.payload""",
                (environment.id, environment.tenant_id, environment.request.idempotency_key, environment.model_dump_json()),
            )
        self.connection.commit()

    def append_audit(self, event: AuditEvent) -> None:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO audit_events (event_id, request_id, payload) VALUES (%s, %s, %s::jsonb) ON CONFLICT DO NOTHING",
                (event.event_id, event.request_id, event.model_dump_json()),
            )
        self.connection.commit()

    def list_audit(self, request_id: UUID) -> list[AuditEvent]:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute("SELECT payload::text FROM audit_events WHERE request_id = %s ORDER BY created_at", (request_id,))
            return [AuditEvent.model_validate_json(row[0]) for row in cursor.fetchall()]

    def enqueue_job(self, job: ReconciliationJob) -> None:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                """INSERT INTO reconciliation_jobs (id, environment_id, state, payload, created_at, updated_at)
                VALUES (%s, %s, %s, %s::jsonb, %s, %s)""",
                (job.id, job.environment_id, job.state.value, job.model_dump_json(), job.created_at, job.updated_at),
            )
        self.connection.commit()

    def load_jobs(self, states: set[ReconciliationJobState] | None = None) -> list[ReconciliationJob]:
        with self.lock, self.connection.cursor() as cursor:
            if states:
                cursor.execute(
                    "SELECT payload::text FROM reconciliation_jobs WHERE state = ANY(%s) ORDER BY created_at",
                    ([state.value for state in states],),
                )
            else:
                cursor.execute("SELECT payload::text FROM reconciliation_jobs ORDER BY created_at")
            return [ReconciliationJob.model_validate_json(row[0]) for row in cursor.fetchall()]

    def update_job(self, job: ReconciliationJob) -> None:
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                """UPDATE reconciliation_jobs SET state = %s, payload = %s::jsonb, updated_at = %s WHERE id = %s""",
                (job.state.value, job.model_dump_json(), job.updated_at, job.id),
            )
        self.connection.commit()

    def claim_job(self, job: ReconciliationJob) -> bool:
        """Atomically claim a pending job for one of several worker replicas."""
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                """UPDATE reconciliation_jobs
                SET state = %s, payload = %s::jsonb, updated_at = %s
                WHERE id = %s AND state = %s""",
                (
                    job.state.value,
                    job.model_dump_json(),
                    job.updated_at,
                    job.id,
                    ReconciliationJobState.PENDING.value,
                ),
            )
            claimed = cursor.rowcount == 1
        self.connection.commit()
        return claimed

    def requeue_stale_job(self, job: ReconciliationJob, stale_before: datetime) -> bool:
        """Requeue work owned by a worker that exceeded its bounded lease."""
        with self.lock, self.connection.cursor() as cursor:
            cursor.execute(
                """UPDATE reconciliation_jobs
                SET state = %s, payload = %s::jsonb, updated_at = %s
                WHERE id = %s AND state = %s AND updated_at <= %s""",
                (
                    job.state.value,
                    job.model_dump_json(),
                    job.updated_at,
                    job.id,
                    ReconciliationJobState.PROCESSING.value,
                    stale_before,
                ),
            )
            requeued = cursor.rowcount == 1
        self.connection.commit()
        return requeued

    def close(self) -> None:
        self.connection.close()
