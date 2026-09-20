#!/usr/bin/env bash
set -euo pipefail

command -v docker >/dev/null || { echo "Docker is required"; exit 1; }
command -v kind >/dev/null || { echo "kind is required"; exit 1; }

# This intentionally removes only resources owned by this repository: Compose
# containers, named volumes, its locally-built image, and the named kind cluster.
docker compose down --volumes --remove-orphans --rmi local || true

if kind get clusters | grep -qx "ai-platform-local"; then
  kind delete cluster --name ai-platform-local
fi

echo "PASS: Project-local Compose state and kind cluster removed."
