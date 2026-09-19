import os

from fastapi import Header, HTTPException
from platform_control_plane.auth.jwt import JWTSettings, JWTVerifier
from platform_control_plane.models.domain import Actor, Role


def actor_from_headers(
    x_platform_subject: str = Header("local-developer"),
    x_platform_tenant: str = Header("team-demo"),
    x_platform_roles: str = Header("developer"),
    x_platform_agent: bool = Header(False),
) -> Actor:
    try:
        return Actor(
            subject=x_platform_subject,
            tenant_id=x_platform_tenant,
            roles={Role(role.strip()) for role in x_platform_roles.split(",")},
            is_agent=x_platform_agent,
        )
    except ValueError as error:
        raise HTTPException(status_code=401, detail="invalid role claim") from error


def actor_from_request(
    authorization: str | None = Header(default=None),
    x_platform_subject: str = Header("local-developer"),
    x_platform_tenant: str = Header("team-demo"),
    x_platform_roles: str = Header("developer"),
    x_platform_agent: bool = Header(False),
) -> Actor:
    """Authenticate API callers; headers are an explicit local-development escape hatch."""
    if os.getenv("PLATFORM_AUTH_MODE") == "headers":
        if os.getenv("PLATFORM_ALLOW_INSECURE_HEADERS") != "true":
            raise HTTPException(status_code=503, detail="insecure header auth is not enabled")
        return actor_from_headers(
            x_platform_subject,
            x_platform_tenant,
            x_platform_roles,
            x_platform_agent,
        )
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer token required")
    return JWTVerifier(JWTSettings.from_environment()).verify(authorization.removeprefix("Bearer "))
