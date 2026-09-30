#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
log=$(mktemp "${TMPDIR:-/tmp}/ai-platform-control-plane-tunnel.XXXXXX")
tunnel_pid=""

cleanup() {
  [[ -n "$tunnel_pid" ]] && kill "$tunnel_pid" 2>/dev/null || true
  [[ -n "$tunnel_pid" ]] && wait "$tunnel_pid" 2>/dev/null || true
  rm -f "$log"
}
trap cleanup EXIT INT TERM

if ! command -v cloudflared >/dev/null; then
  command -v brew >/dev/null || { echo "cloudflared is required; install it with Homebrew." >&2; exit 1; }
  brew install cloudflared
fi

cd "$root"
make bootstrap-local
make compose-smoke

target=http://127.0.0.1:3000
curl -fsS --max-time 10 "$target/api/health" >/dev/null
cloudflared tunnel --url "$target" --protocol http2 >"$log" 2>&1 &
tunnel_pid=$!
for _ in $(seq 1 60); do
  public_url=$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$log" | head -n 1 || true)
  [[ -n "${public_url:-}" ]] && break
  sleep 1
done
[[ -n "${public_url:-}" ]] || { cat "$log" >&2; exit 1; }
echo "Temporary public Grafana demo: $public_url"
echo "Public and unauthenticated for demonstration only. Ctrl-C stops only the tunnel; run make clean-local to remove project resources."
[[ "${PUBLIC_DEMO_EXIT_AFTER_URL:-0}" == 1 ]] && exit 0
wait "$tunnel_pid"
