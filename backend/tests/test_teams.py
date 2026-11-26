"""Testes de integracao: CRUD de times, regras de negocio, time ativo e isolamento."""

from __future__ import annotations

import httpx
import pytest


async def _register_and_headers(client: httpx.AsyncClient, email: str) -> dict[str, str]:
    resp = await client.post(
        "/auth/register",
        json={"email": email, "password": "Password123"},
    )
    assert resp.status_code == 201
    return {"Authorization": f"Bearer {resp.json()['accessToken']}"}


@pytest.mark.asyncio
async def test_team_crud_dedup_logo_ignored_and_active_team(client: httpx.AsyncClient) -> None:
    headers = await _register_and_headers(client, "cap@lider.gg")

    # Cria time 1 com duplicado e logoPath local (deve ignorar logoPath e deduplicar mantendo ordem)
    create1 = await client.post(
        "/teams",
        headers=headers,
        json={
            "name": "Raven Esports",
            "tag": "rvn",
            "logoPath": "file:///C:/fakepath/logo.png",
            "members": [
                {"nick": "PlayerOne", "tag": "BR1"},
                {"nick": "playerone", "tag": "br1"},
                {"nick": "PlayerTwo", "tag": "BR1"},
                {"nick": "PlayerThree", "tag": "BR1"},
            ],
        },
    )
    assert create1.status_code == 201
    t1 = create1.json()["team"]
    assert t1["name"] == "Raven Esports"
    assert t1["tag"] == "RVN"
    assert t1["logoPath"] == ""
    assert [m["nick"] for m in t1["members"]] == ["PlayerOne", "PlayerTwo", "PlayerThree"]

    # Primeiro time vira ativo automaticamente
    listed = await client.get("/teams", headers=headers)
    assert listed.status_code == 200
    assert listed.json()["activeTeamId"] == t1["id"]
    assert len(listed.json()["teams"]) == 1

    # Cria time 2 (nao sobrescreve time ativo)
    create2 = await client.post(
        "/teams",
        headers=headers,
        json={
            "name": "Noite Eterna",
            "tag": "NTE",
            "members": [
                {"nick": "Lunar", "tag": "BR1"},
                {"nick": "Sombra", "tag": "BR1"},
            ],
        },
    )
    assert create2.status_code == 201
    t2 = create2.json()["team"]

    # Troca time ativo para time 2
    sw = await client.put("/me/active-team", headers=headers, json={"teamId": t2["id"]})
    assert sw.status_code == 200
    assert sw.json() == {"activeTeamId": t2["id"]}

    # Edita time 2 alterando ordem dos membros
    upd = await client.put(
        f"/teams/{t2['id']}",
        headers=headers,
        json={
            "name": "Noite Eterna Prime",
            "tag": "NTP",
            "logoPath": "https://malicioso.example/x.png",
            "members": [
                {"nick": "Sombra", "tag": "BR1"},
                {"nick": "Eclipse", "tag": "BR1"},
                {"nick": "Lunar", "tag": "BR1"},
            ],
        },
    )
    assert upd.status_code == 200
    assert upd.json()["team"]["logoPath"] == ""
    assert [m["nick"] for m in upd.json()["team"]["members"]] == ["Sombra", "Eclipse", "Lunar"]

    # Exclui o time ativo (t2) -> time ativo volta para t1
    deleted = await client.delete(f"/teams/{t2['id']}", headers=headers)
    assert deleted.status_code == 200
    assert deleted.json() == {"teamId": t2["id"]}

    listed_after = await client.get("/teams", headers=headers)
    assert listed_after.json()["activeTeamId"] == t1["id"]
    assert [t["id"] for t in listed_after.json()["teams"]] == [t1["id"]]


@pytest.mark.asyncio
async def test_team_validation_rules(client: httpx.AsyncClient) -> None:
    headers = await _register_and_headers(client, "rules@lider.gg")

    # Menos de 2 jogadores distintos (duplicado conta como 1)
    r1 = await client.post(
        "/teams",
        headers=headers,
        json={
            "name": "Solo Team",
            "tag": "SL",
            "members": [
                {"nick": "Unico", "tag": "BR1"},
                {"nick": "unico", "tag": "br1"},
            ],
        },
    )
    assert r1.status_code == 422
    assert "message" in r1.json()

    # Sigla invalida (< 2 ou > 5)
    r2 = await client.post(
        "/teams",
        headers=headers,
        json={
            "name": "Tag Ruim",
            "tag": "ABCDEF",
            "members": [
                {"nick": "A", "tag": "BR1"},
                {"nick": "B", "tag": "BR1"},
            ],
        },
    )
    assert r2.status_code == 422
    assert "message" in r2.json()


@pytest.mark.asyncio
async def test_user_isolation_between_owners(client: httpx.AsyncClient) -> None:
    headers_a = await _register_and_headers(client, "usera@lider.gg")
    headers_b = await _register_and_headers(client, "userb@lider.gg")

    created = await client.post(
        "/teams",
        headers=headers_a,
        json={
            "name": "Time do A",
            "tag": "TMA",
            "members": [
                {"nick": "Alpha", "tag": "BR1"},
                {"nick": "Beta", "tag": "BR1"},
            ],
        },
    )
    assert created.status_code == 201
    team_id = created.json()["team"]["id"]

    # Usuario B nao enxerga o time de A
    list_b = await client.get("/teams", headers=headers_b)
    assert list_b.status_code == 200
    assert list_b.json()["teams"] == []

    # Usuario B nao pode editar, excluir nem ativar o time de A
    upd_b = await client.put(
        f"/teams/{team_id}",
        headers=headers_b,
        json={
            "name": "Hack",
            "tag": "HCK",
            "members": [
                {"nick": "Alpha", "tag": "BR1"},
                {"nick": "Beta", "tag": "BR1"},
            ],
        },
    )
    assert upd_b.status_code == 404
    assert upd_b.json() == {"message": "Time não encontrado."}

    del_b = await client.delete(f"/teams/{team_id}", headers=headers_b)
    assert del_b.status_code == 404

    act_b = await client.put("/me/active-team", headers=headers_b, json={"teamId": team_id})
    assert act_b.status_code == 404
