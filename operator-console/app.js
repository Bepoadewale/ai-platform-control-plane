(() => {
  const config = window.PLATFORM_CONSOLE_CONFIG;
  const store = window.sessionStorage;
  const tokenKey = "platform_console_token";
  const idTokenKey = "platform_console_id_token";
  const stateKey = "platform_console_oidc_state";
  const verifierKey = "platform_console_pkce_verifier";
  const byId = (id) => document.getElementById(id);
  const escapeHtml = (value) => String(value ?? "").replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#039;", '"': "&quot;" })[char]);
  const tell = (message, error = false) => { const el = byId("notice"); el.textContent = message; el.className = `show${error ? " error" : ""}`; window.setTimeout(() => { el.className = ""; }, 5500); };
  const browserCrypto = window.crypto;
  const secureBytes = (size) => {
    if (!browserCrypto || typeof browserCrypto.getRandomValues !== "function") throw new Error("This browser does not provide secure random values required for sign-in.");
    return browserCrypto.getRandomValues(new Uint8Array(size));
  };
  const base64Url = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const verifier = () => base64Url(secureBytes(48));
  const randomUuid = () => {
    if (browserCrypto && typeof browserCrypto.randomUUID === "function") return browserCrypto.randomUUID();
    const bytes = secureBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  };
  // An HTTP-only pilot origin is not always a secure browser context, which means some browsers
  // with secure randomness omit WebCrypto's `subtle` API. PKCE still needs SHA-256, so retain
  // WebCrypto when available and use this bounded, dependency-free SHA-256 implementation for the
  // short verifier only. Randomness always comes from `crypto.getRandomValues()` above.
  const sha256Fallback = (value) => {
    const source = new TextEncoder().encode(value);
    const bitLength = source.length * 8;
    const paddedLength = Math.ceil((source.length + 9) / 64) * 64;
    const bytes = new Uint8Array(paddedLength);
    bytes.set(source); bytes[source.length] = 0x80;
    bytes[paddedLength - 4] = (bitLength >>> 24) & 0xff;
    bytes[paddedLength - 3] = (bitLength >>> 16) & 0xff;
    bytes[paddedLength - 2] = (bitLength >>> 8) & 0xff;
    bytes[paddedLength - 1] = bitLength & 0xff;
    const words = new Uint32Array(64);
    const hash = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    const constants = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];
    const rotateRight = (number, bits) => (number >>> bits) | (number << (32 - bits));
    for (let offset = 0; offset < bytes.length; offset += 64) {
      for (let index = 0; index < 16; index += 1) words[index] = (bytes[offset + index * 4] << 24) | (bytes[offset + index * 4 + 1] << 16) | (bytes[offset + index * 4 + 2] << 8) | bytes[offset + index * 4 + 3];
      for (let index = 16; index < 64; index += 1) {
        const first = rotateRight(words[index - 15], 7) ^ rotateRight(words[index - 15], 18) ^ (words[index - 15] >>> 3);
        const second = rotateRight(words[index - 2], 17) ^ rotateRight(words[index - 2], 19) ^ (words[index - 2] >>> 10);
        words[index] = (words[index - 16] + first + words[index - 7] + second) >>> 0;
      }
      let [a, b, c, d, e, f, g, h] = hash;
      for (let index = 0; index < 64; index += 1) {
        const first = (h + (rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)) + ((e & f) ^ (~e & g)) + constants[index] + words[index]) >>> 0;
        const second = ((rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) >>> 0;
        [a, b, c, d, e, f, g, h] = [(first + second) >>> 0, a, b, c, (d + first) >>> 0, e, f, g];
      }
      hash[0] = (hash[0] + a) >>> 0; hash[1] = (hash[1] + b) >>> 0; hash[2] = (hash[2] + c) >>> 0; hash[3] = (hash[3] + d) >>> 0;
      hash[4] = (hash[4] + e) >>> 0; hash[5] = (hash[5] + f) >>> 0; hash[6] = (hash[6] + g) >>> 0; hash[7] = (hash[7] + h) >>> 0;
    }
    const result = new Uint8Array(32);
    hash.forEach((number, index) => { result[index * 4] = number >>> 24; result[index * 4 + 1] = number >>> 16; result[index * 4 + 2] = number >>> 8; result[index * 4 + 3] = number; });
    return result;
  };
  const challenge = async (value) => {
    if (browserCrypto && browserCrypto.subtle) return base64Url(await browserCrypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
    return base64Url(sha256Fallback(value));
  };
  const redirectUri = () => `${window.location.origin}/`;
  const getToken = () => store.getItem(tokenKey);

  async function login() {
    const state = randomUuid(); const codeVerifier = verifier();
    store.setItem(stateKey, state); store.setItem(verifierKey, codeVerifier);
    const query = new URLSearchParams({ client_id: config.clientId, redirect_uri: redirectUri(), response_type: "code", scope: "openid profile", state, code_challenge: await challenge(codeVerifier), code_challenge_method: "S256" });
    window.location.assign(`${config.issuer}/protocol/openid-connect/auth?${query}`);
  }

  async function finishLogin() {
    const url = new URL(window.location.href); const code = url.searchParams.get("code");
    if (!code) return;
    if (url.searchParams.get("state") !== store.getItem(stateKey)) throw new Error("OIDC state did not match; sign in again.");
    const response = await fetch(`${config.issuer}/protocol/openid-connect/token`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "authorization_code", client_id: config.clientId, redirect_uri: redirectUri(), code, code_verifier: store.getItem(verifierKey) || "" }) });
    if (!response.ok) throw new Error("Keycloak did not issue an access token.");
    const tokens = await response.json();
    store.setItem(tokenKey, tokens.access_token);
    store.setItem(idTokenKey, tokens.id_token);
    store.removeItem(stateKey); store.removeItem(verifierKey); window.history.replaceState({}, document.title, "/");
  }

  async function api(path, options = {}) {
    const token = getToken(); if (!token) throw new Error("Sign in is required.");
    const response = await fetch(`${config.apiBaseUrl}${path}`, { ...options, headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...(options.headers || {}) } });
    const body = await response.json().catch(() => ({}));
    if (response.status === 401) { store.removeItem(tokenKey); renderLoggedOut(); }
    if (!response.ok) throw new Error(body.detail || `Request failed (${response.status}).`);
    return body;
  }

  const payloadFrom = (form) => ({
    idempotency_key: `${form.name.value}-${randomUuid()}`.slice(0, 120), name: form.name.value, team: form.team.value, environment_type: form.environment_type.value, ttl_hours: Number(form.ttl_hours.value), services: ["api"], postgresql: form.postgresql.checked, redis: form.redis.checked, object_storage: false, secret_refs: [], service_exposure: "ingress", image: "nginxinc/nginx-unprivileged:1.27-alpine", observability: true, workload: { size: form.size.value, replicas: 1, privileged: false, gpu_count: 0, min_replicas: 1, max_replicas: 3, scaling_policy: "cpu" }, cost_center: form.cost_center.value,
  });
  const showResult = (targetId, data) => { const target = byId(targetId); target.hidden = false; target.textContent = JSON.stringify(data, null, 2); };
  const showView = (name) => { document.querySelectorAll(".view").forEach((item) => item.classList.toggle("active", item.id === name)); document.querySelectorAll(".tab").forEach((item) => item.classList.toggle("active", item.dataset.view === name)); };

  async function refresh() {
    const [catalog, environments] = await Promise.all([api("/api/v1/catalog"), api("/api/v1/environments")]);
    const items = Array.isArray(environments) ? environments : [];
    byId("environment-count").textContent = items.length;
    byId("ready-count").textContent = items.filter((item) => item.state === "READY").length;
    byId("approval-count").textContent = items.filter((item) => item.state === "APPROVAL_REQUIRED").length;
    byId("capabilities").innerHTML = catalog.capabilities.map((item) => `<span>${escapeHtml(item)}</span>`).join("");
    byId("constraints").textContent = `Agent constraints: ${catalog.agent_constraints.join(" · ")}`;
    byId("environment-rows").innerHTML = items.length ? items.map((item) => `<tr><td><strong>${escapeHtml(item.request.name)}</strong><br><small>${escapeHtml(item.id)}</small></td><td>${escapeHtml(item.request.environment_type)}</td><td><span class="state">${escapeHtml(item.state)}</span></td><td>${item.plan ? escapeHtml(item.plan.plan_hash.slice(0, 10)) : "—"}</td><td>${item.expires_at ? new Date(item.expires_at).toLocaleString() : "—"}</td><td><button class="button secondary audit" data-id="${item.id}">Audit</button></td></tr>`).join("") : '<tr><td colspan="6" class="empty">No environments are visible to this tenant.</td></tr>';
    document.querySelectorAll(".audit").forEach((button) => button.addEventListener("click", async () => { try { showResult("audit-result", await api(`/api/v1/environments/${button.dataset.id}/audit-events`)); showView("governance"); tell("Audit evidence loaded."); } catch (error) { tell(error.message, true); } }));
  }

  function renderLoggedOut() { byId("app").hidden = true; byId("login-panel").hidden = false; byId("session").innerHTML = ""; }
  function signOut() {
    const idToken = store.getItem(idTokenKey);
    store.removeItem(tokenKey); store.removeItem(idTokenKey);
    const query = new URLSearchParams({ client_id: config.clientId, post_logout_redirect_uri: redirectUri() });
    if (idToken) query.set("id_token_hint", idToken);
    window.location.assign(`${config.issuer}/protocol/openid-connect/logout?${query}`);
  }
  async function renderLoggedIn() {
    const token = getToken(); if (!token) return renderLoggedOut();
    const claims = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    const roles = claims.realm_access?.roles?.join(", ") || "authenticated";
    byId("session").innerHTML = `<span>${escapeHtml(claims.preferred_username || claims.sub)} · ${escapeHtml(roles)}</span><button id="sign-out" class="button secondary">Sign out</button>`;
    byId("sign-out").addEventListener("click", signOut);
    byId("login-panel").hidden = true; byId("app").hidden = false;
    try { await refresh(); } catch (error) { tell(error.message, true); }
  }

  document.addEventListener("DOMContentLoaded", async () => {
    byId("sign-in").addEventListener("click", () => login().catch((error) => tell(error.message, true)));
    document.querySelectorAll(".tab").forEach((button) => button.addEventListener("click", () => showView(button.dataset.view)));
    document.querySelectorAll(".refresh").forEach((button) => button.addEventListener("click", () => refresh().then(() => tell("Evidence refreshed.")).catch((error) => tell(error.message, true))));
    const form = byId("request-form");
    byId("plan-request").addEventListener("click", async () => { try { showResult("request-result", await api("/api/v1/plans", { method: "POST", body: JSON.stringify(payloadFrom(form)) })); } catch (error) { tell(error.message, true); } });
    form.addEventListener("submit", async (event) => { event.preventDefault(); try { const response = await api("/api/v1/environments", { method: "POST", body: JSON.stringify(payloadFrom(form)) }); showResult("request-result", response); await refresh(); tell(`Environment is ${response.state}.`); } catch (error) { tell(error.message, true); } });
    try { await finishLogin(); await renderLoggedIn(); } catch (error) { store.removeItem(tokenKey); store.removeItem(idTokenKey); renderLoggedOut(); tell(error.message, true); }
  });
})();
