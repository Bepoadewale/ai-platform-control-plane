"""Small, explicit SQLite migration runner for the local control-plane profile."""

from __future__ import annotations

import sqlite3

LATEST_SCHEMA_VERSION = 2


def apply_migrations(connection: sqlite3.Connection) -> None:
    connection.execute(
        "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)"
    )
    applied = {
        row[0] for row in connection.execute("SELECT version FROM schema_migrations").fetchall()
    }
    if 1 not in applied:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS environments (
              id TEXT PRIMARY KEY,
              tenant_id TEXT NOT NULL,
              idempotency_key TEXT NOT NULL,
              payload TEXT NOT NULL,
              UNIQUE (tenant_id, idempotency_key)
            );
            CREATE TABLE IF NOT EXISTS audit_events (
              event_id TEXT PRIMARY KEY,
              request_id TEXT NOT NULL,
              payload TEXT NOT NULL
            );
            """
        )
        connection.execute("INSERT INTO schema_migrations (version) VALUES (1)")
    if 2 not in applied:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS reconciliation_jobs (
              id TEXT PRIMARY KEY,
              environment_id TEXT NOT NULL,
              state TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS reconciliation_jobs_pending
              ON reconciliation_jobs (state, created_at);
            """
        )
        connection.execute("INSERT INTO schema_migrations (version) VALUES (2)")
    connection.commit()
