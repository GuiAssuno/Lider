"""Testes de integracao: autenticacao, sessao, refresh de uso unico e perfil Riot."""

from __future__ import annotations

import httpx
import pytest


@pytest.mark.asyncio
async def test_register_duplicate_and_login_flow(client: httpx.AsyncClient) -> None:
    resp = await client.post(
        "/auth/register",
        json={"email": "Coach@Lider.gg", "password": "Password123"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["accessToken"]
    assert data["refreshToken"]
    assert data["needsLink"] is True
    assert data["profile"]["email"] == "coach@lider.gg"

    # E-mail repetido (case-insensitive)
    dup = await client.post(
        "/auth/register",
        json={"email": "coach@lider.gg", "password": "OutraPassword123"},
    )
    assert dup.status_code == 409
    assert dup.json() == {"message": "E-mail já cadastrado."}

    # Login valido
    login = await client.post(
        "/auth/login",
        json={"email": "coach@lider.gg", "password": "Password123"},
    )
    assert login.status_code == 200
    assert login.json()["needsLink"] is True

    # Mensagem identica para e-mail inexistente e senha errada
    wrong_pass = await client.post(
        "/auth/login",
        json={"email": "coach@lider.gg", "password": "SenhaErrada"},
    )
    unknown_email = await client.post(
        "/auth/login",
        json={"email": "naoexiste@lider.gg", "password": "Password123"},
    )
    assert wrong_pass.status_code == 401
    assert unknown_email.status_code == 401
    assert wrong_pass.json() == unknown_email.json() == {"message": "E-mail ou senha inválidos."}


@pytest.mark.asyncio
async def test_refresh_rotation_and_reuse_detection(client: httpx.AsyncClient) -> None:
    reg = await client.post(
        "/auth/register",
        json={"email": "sessao@lider.gg", "password": "Password123"},
    )
    assert reg.status_code == 201
    rt1 = reg.json()["refreshToken"]

    # Primeira rotacao funciona
    r1 = await client.post("/auth/refresh", json={"refreshToken": rt1})
    assert r1.status_code == 200
    rt2 = r1.json()["refreshToken"]
    assert rt2 != rt1

    # Reutilizar rt1 falha e revoga toda a cadeia (incluindo rt2)
    reuse = await client.post("/auth/refresh", json={"refreshToken": rt1})
    assert reuse.status_code == 401
    assert "message" in reuse.json()

    after_revoke = await client.post("/auth/refresh", json={"refreshToken": rt2})
    assert after_revoke.status_code == 401


@pytest.mark.asyncio
async def test_logout_revokes_token_and_returns_204(client: httpx.AsyncClient) -> None:
    reg = await client.post(
        "/auth/register",
        json={"email": "logout@lider.gg", "password": "Password123"},
    )
    rt = reg.json()["refreshToken"]

    out = await client.post("/auth/logout", json={"refreshToken": rt})
    assert out.status_code == 204
    assert out.content == b""

    retry = await client.post("/auth/refresh", json={"refreshToken": rt})
    assert retry.status_code == 401


@pytest.mark.asyncio
async def test_me_and_link_riot_account(client: httpx.AsyncClient) -> None:
    reg = await client.post(
        "/auth/register",
        json={"email": "riot@lider.gg", "password": "Password123"},
    )
    token = reg.json()["accessToken"]
    headers = {"Authorization": f"Bearer {token}"}

    me_before = await client.get("/me", headers=headers)
    assert me_before.status_code == 200
    assert me_before.json()["needsLink"] is True

    linked = await client.put(
        "/me/riot-account",
        headers=headers,
        json={"nick": "Nicktag", "tag": "BR1", "region": "BR"},
    )
    assert linked.status_code == 200
    body = linked.json()
    assert body["needsLink"] is False
    assert body["profile"]["nick"] == "Nicktag"
    assert body["profile"]["tag"] == "BR1"
    assert body["profile"]["region"] == "BR"

    me_after = await client.get("/me", headers=headers)
    assert me_after.status_code == 200
    assert me_after.json()["needsLink"] is False
    assert me_after.json()["profile"]["nick"] == "Nicktag"
