import sqlite3
from pathlib import Path

from platform_control_plane.persistence.migrations import LATEST_SCHEMA_VERSION
from platform_control_plane.persistence.repository import EnvironmentRepository


def test_empty_database_receives_versioned_schema(tmp_path: Path):
    database_path = tmp_path / "control-plane.db"
    repository = EnvironmentRepository(database_path)
    repository.close()

    with sqlite3.connect(database_path) as connection:
        versions = connection.execute("SELECT version FROM schema_migrations").fetchall()
        tables = {
            row[0]
            for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'").fetchall()
        }
    assert versions == [(LATEST_SCHEMA_VERSION,)]
    assert {"environments", "audit_events"}.issubset(tables)
