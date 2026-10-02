from pathlib import Path

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import Encoding, NoEncryption, PrivateFormat
from platform_control_plane.gitops.github import (
    GitHubAppConfig,
    GitHubAppPublisher,
    GitOpsPublicationError,
)


def test_rejects_path_outside_environment_tree(tmp_path: Path) -> None:
    publisher = GitHubAppPublisher(
        GitHubAppConfig("1", "2", "owner/repo", tmp_path / "missing.pem"),
        httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(500))),
    )
    with pytest.raises(GitOpsPublicationError, match="under environments"):
        publisher.publish(path="platform/cloud/runtime.yaml", content="x", change_id="abc", title="x")


def test_requires_private_key_before_requesting_token(tmp_path: Path) -> None:
    publisher = GitHubAppPublisher(
        GitHubAppConfig("1", "2", "owner/repo", tmp_path / "missing.pem"),
        httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(500))),
    )
    with pytest.raises(GitOpsPublicationError, match="private key"):
        publisher.publish(path="environments/team/demo/values.yaml", content="x", change_id="abc", title="x")


def test_publishes_rendered_state_on_isolated_branch(tmp_path: Path) -> None:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    key_path = tmp_path / "app.pem"
    key_path.write_bytes(
        key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption())
    )
    requests: list[httpx.Request] = []

    def github(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path.endswith("/access_tokens"):
            return httpx.Response(201, json={"token": "installation-token"})
        if request.url.path.endswith("/git/ref/heads/main"):
            return httpx.Response(200, json={"object": {"sha": "base-sha"}})
        if request.url.path.endswith("/git/refs"):
            return httpx.Response(201, json={})
        if "/contents/environments/" in request.url.path:
            return httpx.Response(201, json={})
        if request.url.path.endswith("/pulls"):
            return httpx.Response(201, json={"html_url": "https://github.example/pull/1"})
        return httpx.Response(500)

    publisher = GitHubAppPublisher(
        GitHubAppConfig("1", "2", "owner/repo", key_path, api_url="https://github.example"),
        httpx.Client(transport=httpx.MockTransport(github)),
    )
    result = publisher.publish(
        path="environments/team/demo/values.yaml",
        content="name: demo\n",
        change_id="request-123",
        title="gitops: render team/demo",
    )

    assert result == "https://github.example/pull/1"
    assert [request.method for request in requests] == ["POST", "GET", "POST", "PUT", "POST"]
    assert requests[3].url.path.endswith("/environments/team/demo/values.yaml")


def test_publishes_desired_state_deletion_on_isolated_branch(tmp_path: Path) -> None:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    key_path = tmp_path / "app.pem"
    key_path.write_bytes(key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption()))
    requests: list[httpx.Request] = []

    def github(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path.endswith("/access_tokens"):
            return httpx.Response(201, json={"token": "installation-token"})
        if request.url.path.endswith("/git/ref/heads/main"):
            return httpx.Response(200, json={"object": {"sha": "base-sha"}})
        if request.url.path.endswith("/git/refs"):
            return httpx.Response(201, json={})
        if "/contents/environments/" in request.url.path and request.method == "GET":
            return httpx.Response(200, json={"sha": "file-sha"})
        if "/contents/environments/" in request.url.path and request.method == "DELETE":
            return httpx.Response(200, json={})
        if request.url.path.endswith("/pulls"):
            return httpx.Response(201, json={"html_url": "https://github.example/pull/2"})
        return httpx.Response(500)

    publisher = GitHubAppPublisher(
        GitHubAppConfig("1", "2", "owner/repo", key_path, api_url="https://github.example"),
        httpx.Client(transport=httpx.MockTransport(github)),
    )
    result = publisher.delete(
        path="environments/team/demo/values.yaml",
        change_id="destroy-123",
        title="gitops: destroy team/demo",
    )

    assert result == "https://github.example/pull/2"
    assert [request.method for request in requests] == ["POST", "GET", "POST", "GET", "DELETE", "POST"]
