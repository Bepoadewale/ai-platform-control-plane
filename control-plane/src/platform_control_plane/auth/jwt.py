"""Local OIDC-compatible JWT verification for the control-plane API."""

import json
import os
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
from fastapi import HTTPException
from platform_control_plane.models.domain import Actor, Role


@dataclass(frozen=True)
class JWTSettings:
    issuer: str
    audience: str
    jwks_url: str

    @classmethod
    def from_environment(cls) -> "JWTSettings":
        try:
            return cls(
                issuer=os.environ["PLATFORM_JWT_ISSUER"],
                audience=os.environ["PLATFORM_JWT_AUDIENCE"],
                jwks_url=os.environ["PLATFORM_JWKS_URL"],
            )
        except KeyError as error:
            raise HTTPException(
                status_code=503,
                detail="JWT verification is not configured",
            ) from error


class JWTVerifier:
    def __init__(
        self,
        settings: JWTSettings,
        jwks_fetcher: Callable[[str], dict[str, Any]] | None = None,
    ) -> None:
        self.settings = settings
        self.jwks_fetcher = jwks_fetcher or self._fetch_jwks

    @staticmethod
    def _fetch_jwks(url: str) -> dict[str, Any]:
        try:
            response = httpx.get(url, timeout=3)
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise HTTPException(status_code=503, detail="JWKS is unavailable") from error

    def verify(self, token: str) -> Actor:
        try:
            header = jwt.get_unverified_header(token)
            key_id = header.get("kid")
            if not key_id:
                raise jwt.InvalidTokenError("token missing key id")
            jwks = self.jwks_fetcher(self.settings.jwks_url)
            jwk = next(key for key in jwks["keys"] if key.get("kid") == key_id)
            signing_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(jwk))
            claims = jwt.decode(
                token,
                signing_key,
                algorithms=["RS256"],
                issuer=self.settings.issuer,
                audience=self.settings.audience,
                options={"require": ["exp", "sub", "iss", "aud", "tenant_id"]},
            )
            roles = claims.get("roles", [])
            if not isinstance(roles, list):
                raise jwt.InvalidTokenError("roles must be an array")
            principal_type = claims.get("principal_type", "human")
            return Actor(
                subject=claims["sub"],
                tenant_id=claims["tenant_id"],
                roles={Role(role) for role in roles},
                is_agent=principal_type == "agent",
            )
        except (KeyError, StopIteration, jwt.PyJWTError, ValueError) as error:
            raise HTTPException(status_code=401, detail="invalid authentication token") from error
