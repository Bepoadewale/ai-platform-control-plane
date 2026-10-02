"""GitHub App-backed desired-state publication for the cloud GitOps boundary.

The publisher intentionally receives a rendered file and returns a pull-request URL. It does not
run Helm, kubectl, or Terraform; Argo CD remains responsible for reconciliation after a reviewed
Git change is merged.
"""

from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import jwt


class GitOpsPublicationError(RuntimeError):
    """GitHub could not safely publish desired state."""


@dataclass(frozen=True)
class GitHubAppConfig:
    app_id: str
    installation_id: str
    repository: str
    private_key_path: Path
    base_branch: str = "main"
    api_url: str = "https://api.github.com"


class GitHubAppPublisher:
    """Creates a branch and PR using an installation token with repository-only authority."""

    def __init__(self, config: GitHubAppConfig, client: httpx.Client | None = None) -> None:
        self.config = config
        self.client = client or httpx.Client(timeout=15.0)

    def _app_jwt(self) -> str:
        if not self.config.private_key_path.is_file():
            raise GitOpsPublicationError("GitHub App private key is unavailable")
        now = datetime.now(UTC)
        return jwt.encode(
            {"iat": now - timedelta(seconds=30), "exp": now + timedelta(minutes=9), "iss": self.config.app_id},
            self.config.private_key_path.read_text(encoding="utf-8"),
            algorithm="RS256",
        )

    def _installation_token(self) -> str:
        response = self.client.post(
            f"{self.config.api_url}/app/installations/{self.config.installation_id}/access_tokens",
            headers={"Authorization": f"Bearer {self._app_jwt()}", "Accept": "application/vnd.github+json"},
        )
        if response.status_code != 201:
            raise GitOpsPublicationError(f"GitHub installation token request failed: {response.status_code}")
        token = response.json().get("token")
        if not isinstance(token, str):
            raise GitOpsPublicationError("GitHub installation token response was invalid")
        return token

    def publish(self, *, path: str, content: str, change_id: str, title: str) -> str:
        """Publish one rendered file on an isolated branch and return the PR URL."""
        if not path.startswith("environments/") or ".." in Path(path).parts:
            raise GitOpsPublicationError("desired-state path must remain under environments/")
        token = self._installation_token()
        headers = {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}
        repo_url = f"{self.config.api_url}/repos/{self.config.repository}"
        ref = self.client.get(f"{repo_url}/git/ref/heads/{self.config.base_branch}", headers=headers)
        if ref.status_code != 200:
            raise GitOpsPublicationError(f"GitHub base branch lookup failed: {ref.status_code}")
        base_sha = ref.json().get("object", {}).get("sha")
        if not isinstance(base_sha, str):
            raise GitOpsPublicationError("GitHub base branch response was invalid")
        branch = f"gitops/{change_id}"
        created = self.client.post(
            f"{repo_url}/git/refs", headers=headers, json={"ref": f"refs/heads/{branch}", "sha": base_sha}
        )
        if created.status_code not in {201, 422}:
            raise GitOpsPublicationError(f"GitHub branch creation failed: {created.status_code}")
        encoded = base64.b64encode(content.encode("utf-8")).decode("ascii")
        updated = self.client.put(
            f"{repo_url}/contents/{path}",
            headers=headers,
            json={"message": title, "content": encoded, "branch": branch},
        )
        if updated.status_code not in {200, 201}:
            raise GitOpsPublicationError(f"GitHub desired-state write failed: {updated.status_code}")
        pull_request = self.client.post(
            f"{repo_url}/pulls",
            headers=headers,
            json={"title": title, "head": branch, "base": self.config.base_branch, "body": "Generated governed desired state."},
        )
        if pull_request.status_code != 201:
            raise GitOpsPublicationError(f"GitHub pull request creation failed: {pull_request.status_code}")
        url = pull_request.json().get("html_url")
        if not isinstance(url, str):
            raise GitOpsPublicationError("GitHub pull request response was invalid")
        return url
