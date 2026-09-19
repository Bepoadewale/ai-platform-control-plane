from fastapi import Header, HTTPException
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
