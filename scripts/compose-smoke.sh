#!/usr/bin/env bash
set -euo pipefail

wait_for() {
  local url="$1"
  shift
  for _ in $(seq 1 60); do
    if curl --fail --silent "$@" "$url" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for ${url}" >&2
  return 1
}

if [[ "${COMPOSE_SKIP_UP:-0}" != "1" ]]; then
  docker compose up -d --build
fi
wait_for http://localhost:8000/healthz
wait_for http://localhost:9090/-/ready
wait_for http://localhost:3000/api/health -u admin:local-development-only
wait_for http://localhost:8081/realms/platform/.well-known/openid-configuration

token=""
for _ in $(seq 1 60); do
  if token="$(curl --fail --silent \
    --data-urlencode client_id=ai-platform-control-plane \
    --data-urlencode grant_type=password \
    --data-urlencode username=developer \
    --data-urlencode password=local-development-only \
    http://localhost:8081/realms/platform/protocol/openid-connect/token | jq -er '.access_token' 2>/dev/null)"; then
    break
  fi
  sleep 2
done
[[ -n "${token}" ]] || { echo "Timed out obtaining local Keycloak token" >&2; exit 1; }

curl --fail --silent --show-error \
  -H "Authorization: Bearer ${token}" \
  http://localhost:8000/api/v1/catalog | jq -e '.environment_types | index("development") != null' >/dev/null

for _ in $(seq 1 60); do
  samples="$(curl --fail --silent --show-error \
    'http://localhost:9090/api/v1/query?query=sum(platform_requests_total)' | jq -r '.data.result[0].value[1] // "0"')"
  if [[ "${samples}" != "0" ]]; then
    break
  fi
  sleep 2
done
[[ "${samples}" != "0" ]]

curl --fail --silent --show-error -u admin:local-development-only \
  'http://localhost:3000/api/search?query=AI%20Platform%20Control%20Plane' \
  | jq -e 'length > 0' >/dev/null

for _ in $(seq 1 60); do
  if docker compose logs --no-color otel-collector | grep -q 'GET /api/v1/catalog'; then
    echo "PASS: Keycloak OIDC → FastAPI → PostgreSQL-backed control plane → OTLP → Prometheus → Grafana"
    exit 0
  fi
  sleep 2
done

echo "OTel Collector did not receive the expected HTTP span" >&2
exit 1
