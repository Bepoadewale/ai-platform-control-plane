#!/usr/bin/env python3
"""List installations for the locally held GitHub App key without printing secret material."""

from __future__ import annotations

import argparse
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import jwt


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--private-key", type=Path, required=True)
    args = parser.parse_args()
    if not args.private_key.is_file():
        raise SystemExit("GitHub App private key is unavailable")
    now = datetime.now(UTC)
    token = jwt.encode(
        {"iat": now - timedelta(seconds=30), "exp": now + timedelta(minutes=9), "iss": args.app_id},
        args.private_key.read_text(encoding="utf-8"),
        algorithm="RS256",
    )
    response = httpx.get(
        "https://api.github.com/app/installations",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
        timeout=15,
    )
    response.raise_for_status()
    for installation in response.json():
        account = installation.get("account", {}).get("login", "unknown")
        repository_selection = installation.get("repository_selection", "unknown")
        print(f"installation_id={installation['id']} account={account} repositories={repository_selection}")


if __name__ == "__main__":
    main()
