"""PostgreSQL repositories for the production-shaped local Compose profile."""

from __future__ import annotations

from threading import RLock
from uuid import UUID

import psycopg

from platform_control_plane.models.domain import AuditEvent, Environment


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

    def close(self) -> None:
        self.connection.close()
