"""Testes unitarios (nao dependem de PostgreSQL)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.config import MAX_MEMBERS_PER_TEAM
from app.errors import AppError
from app.schemas import LinkRiotAccountRequest, RegisterRequest, TeamMemberIn, TeamSaveRequest
from app.security import (
    create_access_token,
    decode_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.services.riot_client import RiotClient


def test_argon2_hash_and_verify() -> None:
    hashed = hash_password("SenhaForte123!")
    assert hashed != "SenhaForte123!"
    assert hashed.startswith("$argon2id$")
    assert verify_password("SenhaForte123!", hashed) is True
    assert verify_password("SenhaErrada", hashed) is False
    assert verify_password("qualquer-coisa", None) is False


def test_jwt_create_and_decode() -> None:
    secret = "segredo-de-teste-com-mais-de-32-bytes"
    token, expires_in = create_access_token(
        user_id=42,
        email="coach@lider.gg",
        secret=secret,
        expires_minutes=15,
    )
    assert expires_in == 900
    payload = decode_access_token(token, secret=secret)
    assert payload["sub"] == "42"
    assert payload["email"] == "coach@lider.gg"
    assert payload["type"] == "access"

    with pytest.raises(AppError) as exc_info:
        decode_access_token(token, secret="outro-segredo-completamente-diferente")
    assert exc_info.value.status_code == 401


def test_refresh_token_hashing() -> None:
    raw = generate_refresh_token()
    hashed = hash_refresh_token(raw)
    assert len(hashed) == 64
    assert hashed == hash_refresh_token(raw)
    assert hashed != raw


@pytest.mark.asyncio
async def test_riot_client_fake_is_deterministic() -> None:
    client = RiotClient(mode="fake")
    acc1 = await client.resolve_account("PlayerOne", "BR1", "BR")
    acc2 = await client.resolve_account("playerone", "br1", "BR")
    acc3 = await client.resolve_account("PlayerTwo", "BR1", "BR")

    assert acc1.puuid == acc2.puuid
    assert acc1.puuid != acc3.puuid
    assert len(acc1.puuid) <= 78


def test_schema_validations() -> None:
    reg = RegisterRequest(email="  Coach@Lider.GG ", password="password123")
    assert reg.email == "coach@lider.gg"

    with pytest.raises(ValidationError):
        RegisterRequest(email="coach@lider.gg", password="curta")

    linked = LinkRiotAccountRequest(nick="  Faker ", tag="#KR1", region="kr")
    assert linked.nick == "Faker"
    assert linked.tag == "KR1"
    assert linked.region == "KR"

    with pytest.raises(ValidationError):
        LinkRiotAccountRequest(nick="Faker", tag="KR1", region="MARS")

    too_many = [TeamMemberIn(nick=f"P{i}", tag="BR1") for i in range(MAX_MEMBERS_PER_TEAM + 1)]
    with pytest.raises(ValidationError):
        TeamSaveRequest(name="Mega Time", tag="MEGA", members=too_many)
