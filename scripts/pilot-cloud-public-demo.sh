#!/usr/bin/env bash
set -euo pipefail

# Exposes only a local kubectl port-forward through an unauthenticated Cloudflare Quick Tunnel.
# It creates no AWS networking resource. Use disposable pilot data and stop it with Ctrl-C.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
log="$(mktemp "${TMPDIR:-/tmp}/ai-platform-cloud-tunnel.XXXXXX")"
forward_pid=""
tunnel_pid=""

cleanup() {
  [[ -n "$tunnel_pid" ]] && kill "$tunnel_pid" 2>/dev/null || true
  [[ -n "$forward_pid" ]] && kill "$forward_pid" 2>/dev/null || true
  wait "$tunnel_pid" 2>/dev/null || true
  wait "$forward_pid" 2>/dev/null || true
  rm -f "$log"
}
trap cleanup EXIT INT TERM

for command in aws kubectl curl cloudflared; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null
kubectl -n platform-system get deployment/control-plane -o jsonpath='{.status.availableReplicas}' | grep -qx '1'

kubectl -n platform-system port-forward service/control-plane 18000:8000 >/tmp/ai-platform-cloud-port-forward.log 2>&1 &
forward_pid=$!
for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:18000/healthz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18000/healthz >/dev/null

cloudflared tunnel --url http://127.0.0.1:18000 --protocol http2 >"$log" 2>&1 &
tunnel_pid=$!
for _ in {1..60}; do
  public_url="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$log" | head -n 1 || true)"
  [[ -n "${public_url:-}" ]] && break
  sleep 1
done
[[ -n "${public_url:-}" ]] || { cat "$log" >&2; exit 1; }
echo "Temporary public cloud control-plane demo: $public_url/docs"
echo "Unauthenticated Quick Tunnel for short-lived pilot viewing only. Ctrl-C stops the tunnel and port-forward; it does not destroy AWS resources."
[[ "${PUBLIC_DEMO_EXIT_AFTER_URL:-0}" == 1 ]] && exit 0
while kill -0 "$forward_pid" 2>/dev/null && kill -0 "$tunnel_pid" 2>/dev/null; do
  sleep 2
done
echo "The Quick Tunnel or its local port-forward ended; start a new temporary review session." >&2
exit 1
