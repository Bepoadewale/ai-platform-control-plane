#!/usr/bin/env python3
"""Run the verified local control-plane acceptance path without cloud credentials."""

from __future__ import annotations

import json
import os
import shutil
import signal
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
from datetime import UTC, datetime, timedelta
from http.server import SimpleHTTPRequestHandler
from pathlib import Path

import httpx
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa

ROOT = Path(__file__).resolve().parents[1]
ISSUER = "https://issuer.local.platform"
AUDIENCE = "ai-platform-control-plane"


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        return None


def run(*command: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=ROOT, check=check, text=True, capture_output=True)


def wait_for(url: str, headers: dict[str, str] | None = None) -> None:
    for _ in range(40):
        try:
            if httpx.get(url, headers=headers, timeout=1).is_success:
                return
        except httpx.HTTPError:
            pass
        time.sleep(1)
    raise RuntimeError(f"timed out waiting for {url}")


def main() -> None:
    if not shutil.which("kind") or not shutil.which("kubectl") or not shutil.which("helm"):
        raise RuntimeError("kind, kubectl, and helm are required")
    if not shutil.which("docker"):
        raise RuntimeError("Docker Desktop is required")

    with tempfile.TemporaryDirectory(prefix="platform-control-plane-demo-") as temp:
        temp_path = Path(temp)
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        public_jwk = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(private_key.public_key()))
        public_jwk.update({"kid": "demo-key", "use": "sig", "alg": "RS256"})
        (temp_path / "jwks.json").write_text(json.dumps({"keys": [public_jwk]}), encoding="utf-8")
        def handler(*args, **kwargs):
            return QuietHandler(*args, directory=temp, **kwargs)

        jwks_server = socketserver.TCPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=jwks_server.serve_forever, daemon=True).start()
        jwks_url = f"http://127.0.0.1:{jwks_server.server_address[1]}/jwks.json"
        claims = {
            "sub": "human:demo-developer",
            "tenant_id": "team-demo",
            "roles": ["developer"],
            "principal_type": "human",
            "iss": ISSUER,
            "aud": AUDIENCE,
            "exp": datetime.now(UTC) + timedelta(minutes=10),
        }
        token = jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": "demo-key"})
        agent_claims = {**claims, "sub": "agent:demo", "roles": ["agent-requester"], "principal_type": "agent"}
        agent_token = jwt.encode(agent_claims, private_key, algorithm="RS256", headers={"kid": "demo-key"})
        operator_claims = {
            **claims,
            "sub": "human:demo-operator",
            "roles": ["platform-operator"],
        }
        operator_token = jwt.encode(
            operator_claims, private_key, algorithm="RS256", headers={"kid": "demo-key"}
        )
        service_name = f"demo-api-{int(time.time()) % 1_000_000}"
        production_service_name = f"demo-prod-{int(time.time()) % 1_000_000}"

        run("docker", "compose", "up", "-d", "opa")
        clusters = run("kind", "get", "clusters").stdout.split()
        if "ai-platform-local" not in clusters:
            run("kind", "create", "cluster", "--name", "ai-platform-local", "--wait", "5m")

        environment = {
            **os.environ,
            "PYTHONPATH": str(ROOT / "control-plane" / "src"),
            "PLATFORM_JWT_ISSUER": ISSUER,
            "PLATFORM_JWT_AUDIENCE": AUDIENCE,
            "PLATFORM_JWKS_URL": jwks_url,
            "PLATFORM_OPA_DECISION_URL": "http://127.0.0.1:8181/v1/data/platform/environment",
            "PLATFORM_RECONCILER": "kind",
            "PLATFORM_HELM_CHART": str(ROOT / "platform" / "helm" / "golden-path"),
            "PLATFORM_DESIRED_STATE_ROOT": str(temp_path / "environments"),
            "PLATFORM_CONTROL_PLANE_DB": str(temp_path / "control-plane.db"),
        }
        api = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "platform_control_plane.api.main:app", "--host", "127.0.0.1", "--port", "8010"],
            cwd=ROOT,
            env=environment,
        )
        try:
            wait_for("http://127.0.0.1:8010/healthz")
            headers = {"Authorization": f"Bearer {token}"}
            response = httpx.post(
                "http://127.0.0.1:8010/api/v1/environments",
                headers=headers,
                json={
                    "name": service_name,
                    "team": "team-demo",
                    "environment_type": "development",
                    "cost_center": "DEMO",
                    "idempotency_key": "local-demo-request-001",
                },
                timeout=180,
            )
            response.raise_for_status()
            environment_result = response.json()
            assert environment_result["state"] == "READY", environment_result
            environment_id = environment_result["id"]
            audit = httpx.get(
                f"http://127.0.0.1:8010/api/v1/environments/{environment_id}/audit-events",
                headers=headers,
                timeout=10,
            ).json()
            assert any(event["action"] == "environment.ready" for event in audit)

            denied = httpx.post(
                "http://127.0.0.1:8010/api/v1/environments",
                headers={"Authorization": f"Bearer {agent_token}"},
                json={
                    "name": "agent-prod-demo",
                    "team": "team-demo",
                    "environment_type": "production",
                    "cost_center": "DEMO",
                    "idempotency_key": "local-demo-agent-denial-001",
                },
                timeout=10,
            ).json()
            assert denied["state"] == "REJECTED", denied

            production = httpx.post(
                "http://127.0.0.1:8010/api/v1/environments",
                headers=headers,
                json={
                    "name": production_service_name,
                    "team": "team-demo",
                    "environment_type": "production",
                    "cost_center": "DEMO",
                    "idempotency_key": "local-demo-production-001",
                },
                timeout=10,
            )
            production.raise_for_status()
            production_result = production.json()
            assert production_result["state"] == "APPROVAL_REQUIRED", production_result
            production_id = production_result["id"]
            self_approval = httpx.post(
                f"http://127.0.0.1:8010/api/v1/environments/{production_id}/approve",
                headers=headers,
                json={"plan_hash": production_result["plan"]["plan_hash"]},
                timeout=10,
            )
            assert self_approval.status_code == 403, self_approval.text
            approved = httpx.post(
                f"http://127.0.0.1:8010/api/v1/environments/{production_id}/approve",
                headers={"Authorization": f"Bearer {operator_token}"},
                json={"plan_hash": production_result["plan"]["plan_hash"]},
                timeout=180,
            )
            approved.raise_for_status()
            assert approved.json()["state"] == "READY", approved.text
            destroy_pending = httpx.post(
                f"http://127.0.0.1:8010/api/v1/environments/{production_id}/destroy",
                headers=headers,
                timeout=10,
            )
            destroy_pending.raise_for_status()
            destroy_result = destroy_pending.json()
            assert destroy_result["state"] == "DESTROY_PENDING", destroy_result
            destroyed_production = httpx.post(
                f"http://127.0.0.1:8010/api/v1/environments/{production_id}/destroy/approve",
                headers={"Authorization": f"Bearer {operator_token}"},
                json={"plan_hash": destroy_result["destroy_plan"]["plan_hash"]},
                timeout=180,
            )
            destroyed_production.raise_for_status()
            assert destroyed_production.json()["state"] == "DESTROYED", destroyed_production.text

            destroyed = httpx.post(
                f"http://127.0.0.1:8010/api/v1/environments/{environment_id}/destroy",
                headers=headers,
                timeout=180,
            ).json()
            assert destroyed["state"] == "DESTROYED", destroyed
            metrics = httpx.get("http://127.0.0.1:8010/metrics", timeout=10).text
            assert "platform_requests_total" in metrics
            deleted_namespace = run(
                "kubectl", "get", "namespace", f"team-demo-{service_name}", check=False
            )
            assert deleted_namespace.returncode != 0
            deleted_production_namespace = run(
                "kubectl", "get", "namespace", f"team-demo-{production_service_name}", check=False
            )
            assert deleted_production_namespace.returncode != 0
            print(
                "PASS: signed JWT → OPA → kind Ready → audit → destroy; "
                "agent production denied; production approval and protected destroy verified"
            )
        finally:
            api.send_signal(signal.SIGTERM)
            api.wait(timeout=15)
            jwks_server.shutdown()
            run("docker", "compose", "stop", "opa", check=False)


if __name__ == "__main__":
    main()
