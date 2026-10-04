import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

const source = await readFile(new URL("../app.js", import.meta.url), "utf8");

test("uses secure getRandomValues UUID fallback when randomUUID is unavailable", async () => {
  const elements = new Map();
  const element = (id) => {
    if (!elements.has(id)) {
      elements.set(id, {
        addEventListener(event, listener) { this.listeners ??= {}; this.listeners[event] = listener; },
        className: "",
        hidden: false,
        innerHTML: "",
        textContent: "",
      });
    }
    return elements.get(id);
  };
  const storage = new Map();
  const redirects = [];
  let domReady;
  const window = {
    PLATFORM_CONSOLE_CONFIG: {
      apiBaseUrl: "https://console.example.test",
      clientId: "ai-platform-control-plane",
      issuer: "https://console.example.test/realms/platform",
    },
    crypto: {
      getRandomValues(bytes) { for (let index = 0; index < bytes.length; index += 1) bytes[index] = index + 1; return bytes; },
      subtle: { digest: async () => new Uint8Array(32).fill(7).buffer },
    },
    history: { replaceState() {} },
    location: {
      href: "https://console.example.test/",
      origin: "https://console.example.test",
      assign(url) { redirects.push(url); },
    },
    sessionStorage: {
      getItem(key) { return storage.get(key) ?? null; },
      removeItem(key) { storage.delete(key); },
      setItem(key, value) { storage.set(key, value); },
    },
    setTimeout() {},
  };
  const context = vm.createContext({
    URL,
    URLSearchParams,
    TextEncoder,
    Uint8Array,
    atob: (value) => Buffer.from(value, "base64").toString("binary"),
    btoa: (value) => Buffer.from(value, "binary").toString("base64"),
    console,
    document: {
      addEventListener(event, listener) { if (event === "DOMContentLoaded") domReady = listener; },
      getElementById: element,
      querySelectorAll() { return []; },
    },
    window,
  });

  vm.runInContext(source, context, { filename: "app.js" });
  await domReady();
  element("sign-in").listeners.click();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(redirects.length, 1);
  const authorizationUrl = new URL(redirects[0]);
  assert.equal(authorizationUrl.pathname, "/realms/platform/protocol/openid-connect/auth");
  assert.match(authorizationUrl.searchParams.get("state"), /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(storage.get("platform_console_oidc_state"), authorizationUrl.searchParams.get("state"));
  assert.ok(storage.get("platform_console_pkce_verifier"));
});
