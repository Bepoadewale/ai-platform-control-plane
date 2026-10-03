#!/usr/bin/env python3
"""Small same-origin proxy for an explicitly temporary Cloudflare console review.

This process never receives AWS credentials. It only proxies three local kubectl
port-forwards and serves an alternate browser runtime configuration.
"""

from __future__ import annotations

import http.client
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


RUNTIME_CONFIG = b'''window.PLATFORM_CONSOLE_CONFIG = {
  apiBaseUrl: "/api",
  issuer: "/auth/realms/platform",
  clientId: "ai-platform-control-plane",
};
'''


class Proxy(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802
        self._proxy()

    def do_POST(self) -> None:  # noqa: N802
        self._proxy()

    def do_PUT(self) -> None:  # noqa: N802
        self._proxy()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._proxy()

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _proxy(self) -> None:
        if self.path == "/runtime-config.js":
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript; charset=utf-8")
            self.send_header("Content-Length", str(len(RUNTIME_CONFIG)))
            self.end_headers()
            self.wfile.write(RUNTIME_CONFIG)
            return

        port, path, host = 18083, self.path, "localhost:18083"
        if self.path.startswith("/api/"):
            port, path, host = 18000, self.path.removeprefix("/api"), "localhost:18000"
        elif self.path.startswith("/auth/"):
            port, path, host = 18081, self.path.removeprefix("/auth"), "localhost:18081"
        elif self.path.startswith("/resources/"):
            # Keycloak themes are served from this root path even when the login
            # endpoints themselves are proxied under /auth.
            port, path, host = 18081, self.path, "localhost:18081"

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in {"connection", "host", "content-length"}
        }
        headers["Host"] = host
        if self.path.startswith("/auth/"):
            # cloudflared terminates HTTPS before this loopback-only proxy. Keycloak must
            # know the browser used HTTPS so it issues secure, callback-valid cookies.
            headers["X-Forwarded-Proto"] = "https"
            headers["X-Forwarded-Host"] = self.headers.get("Host", "")
        if body is not None:
            headers["Content-Length"] = str(len(body))
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=30)
        try:
            connection.request(self.command, path, body=body, headers=headers)
            response = connection.getresponse()
            payload = response.read()
            content_type = response.getheader("Content-Type", "")
            if self.path.startswith("/auth/") and "text/html" in content_type:
                # KC_HOSTNAME intentionally remains loopback-only for this private pilot.
                # Rewrite its rendered form actions to the temporary same-origin proxy.
                payload = payload.replace(b"http://localhost:18081/", b"/auth/")
            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                if key.lower() not in {"connection", "transfer-encoding", "content-length"}:
                    if key.lower() == "set-cookie" and self.path.startswith("/auth/"):
                        value = value.replace("Path=/realms/", "Path=/auth/realms/")
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        finally:
            connection.close()


if __name__ == "__main__":
    port = int(os.environ.get("PILOT_TUNNEL_PROXY_PORT", "18090"))
    ThreadingHTTPServer(("127.0.0.1", port), Proxy).serve_forever()
