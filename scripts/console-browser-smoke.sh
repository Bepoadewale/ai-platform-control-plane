#!/usr/bin/env bash
set -euo pipefail

# Exercise the same Authorization Code + PKCE exchange used by the static browser
# console. This uses only the synthetic local fixture account and never prints a token.
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

issuer="http://localhost:8081/realms/platform"
console_origin="http://localhost:4173"
client_id="ai-platform-control-plane"
state="console-browser-smoke"
code_verifier="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~abcdef"
code_challenge="$(printf '%s' "$code_verifier" | openssl dgst -sha256 -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')"

authorization_url="${issuer}/protocol/openid-connect/auth?client_id=${client_id}&redirect_uri=http%3A%2F%2Flocalhost%3A4173%2F&response_type=code&scope=openid%20profile&state=${state}&code_challenge=${code_challenge}&code_challenge_method=S256"

curl --fail --silent --show-error --cookie-jar "$scratch_dir/cookies" \
  --output "$scratch_dir/login.html" "$authorization_url"
form_action="$(perl -0777 -ne 'print $1 if /<form[^>]+action="([^"]+)"/s' "$scratch_dir/login.html" | sed 's/&amp;/\&/g')"
[[ -n "$form_action" ]] || { echo "Keycloak sign-in form was not returned" >&2; exit 1; }

curl --fail --silent --show-error --dump-header "$scratch_dir/headers" --output /dev/null \
  --cookie "$scratch_dir/cookies" --cookie-jar "$scratch_dir/cookies" \
  --data-urlencode username=developer \
  --data-urlencode password=local-development-only \
  --data-urlencode credentialId= \
  --data-urlencode 'login=Sign In' \
  "$form_action"

redirect_url="$(awk '/^[Ll]ocation:/{sub(/^[Ll]ocation:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$scratch_dir/headers")"
[[ "$redirect_url" == "${console_origin}"/* ]] || { echo "Keycloak did not redirect to the console callback" >&2; exit 1; }

authorization_code="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query)["code"][0])' "$redirect_url")"
tokens="$(curl --fail --silent --show-error \
  --data-urlencode grant_type=authorization_code \
  --data-urlencode client_id="$client_id" \
  --data-urlencode redirect_uri="${console_origin}/" \
  --data-urlencode code="$authorization_code" \
  --data-urlencode code_verifier="$code_verifier" \
  "${issuer}/protocol/openid-connect/token")"
access_token="$(jq -er '.access_token' <<<"$tokens")"
id_token="$(jq -er '.id_token' <<<"$tokens")"

curl --fail --silent --show-error -H "Authorization: Bearer ${access_token}" \
  http://localhost:8000/api/v1/catalog | jq -e '.capabilities | index("ttl") != null' >/dev/null

logout_hint="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$id_token")"
curl --fail --silent --show-error --dump-header "$scratch_dir/logout-headers" --output /dev/null \
  --cookie "$scratch_dir/cookies" \
  "${issuer}/protocol/openid-connect/logout?client_id=${client_id}&post_logout_redirect_uri=http%3A%2F%2Flocalhost%3A4173%2F&id_token_hint=${logout_hint}"
logout_redirect="$(awk '/^[Ll]ocation:/{sub(/^[Ll]ocation:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$scratch_dir/logout-headers")"
[[ "$logout_redirect" == "${console_origin}"/* ]] || { echo "Keycloak did not redirect logout to the console" >&2; exit 1; }

echo "PASS: Keycloak Authorization Code + PKCE → signed Console API request → Keycloak logout."
