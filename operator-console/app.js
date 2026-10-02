(() => {
  const config = window.PLATFORM_CONSOLE_CONFIG;
  const store = window.sessionStorage;
  const tokenKey = "platform_console_token";
  const stateKey = "platform_console_oidc_state";
  const verifierKey = "platform_console_pkce_verifier";
  const byId = (id) => document.getElementById(id);
  const escapeHtml = (value) => String(value ?? "").replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#039;", '"': "&quot;" })[char]);
  const tell = (message, error = false) => { const el = byId("notice"); el.textContent = message; el.className = `show${error ? " error" : ""}`; window.setTimeout(() => { el.className = ""; }, 5500); };
  const base64Url = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const verifier = () => base64Url(crypto.getRandomValues(new Uint8Array(48)));
  const challenge = async (value) => base64Url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  const redirectUri = () => `${window.location.origin}/`;
  const getToken = () => store.getItem(tokenKey);

  async function login() {
    const state = crypto.randomUUID(); const codeVerifier = verifier();
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
    store.setItem(tokenKey, (await response.json()).access_token); store.removeItem(stateKey); store.removeItem(verifierKey); window.history.replaceState({}, document.title, "/");
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
    idempotency_key: `${form.name.value}-${crypto.randomUUID()}`.slice(0, 120), name: form.name.value, team: form.team.value, environment_type: form.environment_type.value, ttl_hours: Number(form.ttl_hours.value), services: ["api"], postgresql: form.postgresql.checked, redis: form.redis.checked, object_storage: false, secret_refs: [], service_exposure: "ingress", image: "nginxinc/nginx-unprivileged:1.27-alpine", observability: true, workload: { size: form.size.value, replicas: 1, privileged: false, gpu_count: 0, min_replicas: 1, max_replicas: 3, scaling_policy: "cpu" }, cost_center: form.cost_center.value,
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
  async function renderLoggedIn() {
    const token = getToken(); if (!token) return renderLoggedOut();
    const claims = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    const roles = claims.realm_access?.roles?.join(", ") || "authenticated";
    byId("session").innerHTML = `<span>${escapeHtml(claims.preferred_username || claims.sub)} · ${escapeHtml(roles)}</span><button id="sign-out" class="button secondary">Sign out</button>`;
    byId("sign-out").addEventListener("click", () => { store.removeItem(tokenKey); renderLoggedOut(); });
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
    try { await finishLogin(); await renderLoggedIn(); } catch (error) { store.removeItem(tokenKey); renderLoggedOut(); tell(error.message, true); }
  });
})();
