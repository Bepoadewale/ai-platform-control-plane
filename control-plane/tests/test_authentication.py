import json
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from platform_control_plane.api.main import app
from platform_control_plane.auth.jwt import JWTSettings, JWTVerifier
from platform_control_plane.models.domain import Role

ISSUER = "https://issuer.platform.local"
AUDIENCE = "ai-platform-control-plane"
KEY_ID = "local-test-key"


@pytest.fixture()
def issuer_material():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_jwk = json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(private_key.public_key()))
    public_jwk.update({"kid": KEY_ID, "use": "sig", "alg": "RS256"})
    return private_key, {"keys": [public_jwk]}


def issue_token(private_key, **overrides: object) -> str:
    claims: dict[str, object] = {
        "sub": "human:ada",
        "tenant_id": "team-demo",
        "roles": ["developer"],
        "principal_type": "human",
        "iss": ISSUER,
        "aud": AUDIENCE,
        "exp": datetime.now(UTC) + timedelta(minutes=5),
    }
    claims.update(overrides)
    return jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": KEY_ID})


def verifier(jwks: dict) -> JWTVerifier:
    return JWTVerifier(
        JWTSettings(issuer=ISSUER, audience=AUDIENCE, jwks_url="http://local.test/jwks"),
        jwks_fetcher=lambda _: jwks,
    )


def test_valid_signed_jwt_distinguishes_agent_principal(issuer_material):
    private_key, jwks = issuer_material
    actor = verifier(jwks).verify(issue_token(private_key, principal_type="agent"))
    assert actor.subject == "human:ada"
    assert actor.tenant_id == "team-demo"
    assert actor.is_agent is True


def test_keycloak_realm_roles_are_accepted(issuer_material):
    private_key, jwks = issuer_material
    token = issue_token(private_key, roles=None, realm_access={"roles": ["developer"]})
    actor = verifier(jwks).verify(token)

    assert actor.roles == {Role.DEVELOPER}


@pytest.mark.parametrize(
    "overrides",
    [
        {"exp": datetime.now(UTC) - timedelta(minutes=1)},
        {"iss": "https://wrong-issuer.local"},
        {"aud": "wrong-audience"},
        {"tenant_id": None},
        {"roles": "developer"},
    ],
)
def test_invalid_jwt_claims_are_rejected(issuer_material, overrides):
    private_key, jwks = issuer_material
    with pytest.raises(Exception) as error:
        verifier(jwks).verify(issue_token(private_key, **overrides))
    assert getattr(error.value, "status_code", None) == 401


def test_invalid_signature_is_rejected(issuer_material):
    _, jwks = issuer_material
    wrong_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with pytest.raises(Exception) as error:
        verifier(jwks).verify(issue_token(wrong_private_key))
    assert getattr(error.value, "status_code", None) == 401


def test_api_uses_bearer_jwt_and_rejects_viewer_create(monkeypatch, issuer_material):
    private_key, jwks = issuer_material
    monkeypatch.delenv("PLATFORM_AUTH_MODE", raising=False)
    monkeypatch.setenv("PLATFORM_JWT_ISSUER", ISSUER)
    monkeypatch.setenv("PLATFORM_JWT_AUDIENCE", AUDIENCE)
    monkeypatch.setenv("PLATFORM_JWKS_URL", "http://local.test/jwks")
    monkeypatch.setattr(JWTVerifier, "_fetch_jwks", staticmethod(lambda _: jwks))
    token = issue_token(private_key, roles=["viewer"])
    response = TestClient(app).post(
        "/api/v1/environments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "viewer-api",
            "team": "team-demo",
            "environment_type": "development",
            "cost_center": "ENG",
            "idempotency_key": "viewer-auth-request-001",
        },
    )
    assert response.status_code == 201
    assert response.json()["state"] == "REJECTED"


def test_headers_require_explicit_development_opt_in(monkeypatch):
    monkeypatch.setenv("PLATFORM_AUTH_MODE", "headers")
    monkeypatch.delenv("PLATFORM_ALLOW_INSECURE_HEADERS", raising=False)
    response = TestClient(app).get("/api/v1/catalog")
    assert response.status_code == 503
