"""Servicos de CRUD de times, membros e time ativo com isolamento estrito por dono."""

from __future__ import annotations

import json

import asyncpg

from app.db import Database
from app.errors import AppError
from app.schemas import (
    ActiveTeamResponse,
    DeleteTeamResponse,
    TeamMemberIn,
    TeamMemberOut,
    TeamOut,
    TeamSaveRequest,
    TeamsListResponse,
)
from app.services.riot_client import RiotAccount, RiotClient

_TEAM_NOT_FOUND_MSG = "Time não encontrado."
_MIN_MEMBERS_MSG = "Um time precisa de pelo menos 2 jogadores distintos."


def _parse_team_id(raw_id: str) -> int:
    try:
        value = int(raw_id)
    except (TypeError, ValueError) as exc:
        raise AppError(404, _TEAM_NOT_FOUND_MSG) from exc
    if value <= 0:
        raise AppError(404, _TEAM_NOT_FOUND_MSG)
    return value


def _record_to_team_out(row: asyncpg.Record) -> TeamOut:
    raw_members = row["members"]
    if isinstance(raw_members, str):
        members_list = json.loads(raw_members)
    else:
        members_list = list(raw_members or [])

    return TeamOut(
        id=str(row["id"]),
        name=row["name"],
        tag=row["tag"],
        logoPath=row["logoPath"] or "",
        members=[
            TeamMemberOut(id=str(m["id"]), nick=m["nick"], tag=m["tag"])
            for m in members_list
        ],
    )


async def _get_user_default_region(db: Database, user_id: int) -> str:
    region = await db.fetchval(
        """
        SELECT a.regiao
        FROM usuarios u
        JOIN atletas a ON a.puuid = u.atleta_puuid
        WHERE u.id = $1
        """,
        user_id,
    )
    return str(region) if region else "BR"


async def _resolve_distinct_members(
    riot_client: RiotClient,
    members_in: list[TeamMemberIn],
    default_region: str,
) -> list[RiotAccount]:
    # 1) Remove duplicados por nick#tag preservando a ordem informada.
    seen_nick_tag: set[tuple[str, str]] = set()
    unique_inputs: list[TeamMemberIn] = []
    for member in members_in:
        key = (member.nick.lower(), member.tag.lower())
        if key in seen_nick_tag:
            continue
        seen_nick_tag.add(key)
        unique_inputs.append(member)

    if len(unique_inputs) < 2:
        raise AppError(422, _MIN_MEMBERS_MSG)

    # 2) Resolve PUUID via RiotClient e deduplica tambem por PUUID preservando ordem.
    resolved: list[RiotAccount] = []
    seen_puuids: set[str] = set()
    for member in unique_inputs:
        account = await riot_client.resolve_account(member.nick, member.tag, default_region)
        if account.puuid in seen_puuids:
            continue
        seen_puuids.add(account.puuid)
        resolved.append(account)

    if len(resolved) < 2:
        raise AppError(422, _MIN_MEMBERS_MSG)

    return resolved


async def _upsert_team_members(
    conn: asyncpg.Connection,
    team_id: int,
    accounts: list[RiotAccount],
) -> None:
    for order_idx, account in enumerate(accounts):
        await conn.execute(
            """
            INSERT INTO atletas (puuid, nick, tag, regiao, nivel, icone_url)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (puuid) DO UPDATE SET
                nick = EXCLUDED.nick,
                tag = EXCLUDED.tag,
                atualizado_em = NOW()
            """,
            account.puuid,
            account.nick,
            account.tag,
            account.region,
            account.level,
            account.icon_url,
        )
        await conn.execute(
            """
            INSERT INTO time_membros (time_id, atleta_puuid, ordem)
            VALUES ($1, $2, $3)
            """,
            team_id,
            account.puuid,
            order_idx,
        )


async def list_teams(db: Database, *, user_id: int) -> TeamsListResponse:
    rows = await db.fetch(
        """
        SELECT t.id,
               t.nome AS name,
               t.sigla AS tag,
               t.logo_url AS "logoPath",
               COALESCE(
                   json_agg(
                       json_build_object('id', a.puuid, 'nick', a.nick, 'tag', a.tag)
                       ORDER BY m.ordem ASC
                   ) FILTER (WHERE a.puuid IS NOT NULL),
                   '[]'::json
               ) AS members
        FROM times t
        LEFT JOIN time_membros m ON m.time_id = t.id
        LEFT JOIN atletas a ON a.puuid = m.atleta_puuid
        WHERE t.dono_usuario_id = $1
        GROUP BY t.id
        ORDER BY t.id ASC
        """,
        user_id,
    )
    active_team_id = await db.fetchval(
        "SELECT time_ativo_id FROM usuarios WHERE id = $1",
        user_id,
    )
    teams = [_record_to_team_out(r) for r in rows]
    return TeamsListResponse(
        teams=teams,
        activeTeamId=str(active_team_id) if active_team_id is not None else "",
    )


async def create_team(
    db: Database,
    riot_client: RiotClient,
    *,
    user_id: int,
    payload: TeamSaveRequest,
) -> TeamOut:
    default_region = await _get_user_default_region(db, user_id)
    accounts = await _resolve_distinct_members(riot_client, payload.members, default_region)

    async with db.transaction() as conn:
        # logoPath enviado pelo cliente e ignorado de proposito (so muda via upload da Etapa 4).
        team_row = await conn.fetchrow(
            """
            INSERT INTO times (dono_usuario_id, nome, sigla, logo_url)
            VALUES ($1, $2, $3, '')
            RETURNING id, nome, sigla, logo_url
            """,
            user_id,
            payload.name,
            payload.tag,
        )
        team_id = int(team_row["id"])
        await _upsert_team_members(conn, team_id, accounts)

        # Primeiro time criado vira o time ativo automaticamente.
        await conn.execute(
            """
            UPDATE usuarios
            SET time_ativo_id = $1, atualizado_em = NOW()
            WHERE id = $2 AND time_ativo_id IS NULL
            """,
            team_id,
            user_id,
        )

    return TeamOut(
        id=str(team_id),
        name=team_row["nome"],
        tag=team_row["sigla"],
        logoPath=team_row["logo_url"] or "",
        members=[
            TeamMemberOut(id=a.puuid, nick=a.nick, tag=a.tag)
            for a in accounts
        ],
    )


async def update_team(
    db: Database,
    riot_client: RiotClient,
    *,
    user_id: int,
    raw_team_id: str,
    payload: TeamSaveRequest,
) -> TeamOut:
    team_id = _parse_team_id(raw_team_id)
    default_region = await _get_user_default_region(db, user_id)
    accounts = await _resolve_distinct_members(riot_client, payload.members, default_region)

    async with db.transaction() as conn:
        existing = await conn.fetchrow(
            """
            SELECT id, logo_url
            FROM times
            WHERE id = $1 AND dono_usuario_id = $2
            FOR UPDATE
            """,
            team_id,
            user_id,
        )
        if existing is None:
            raise AppError(404, _TEAM_NOT_FOUND_MSG)

        # Mantem logo_url atual no banco; ignora logoPath vindo do cliente.
        updated = await conn.fetchrow(
            """
            UPDATE times
            SET nome = $1, sigla = $2, atualizado_em = NOW()
            WHERE id = $3 AND dono_usuario_id = $4
            RETURNING id, nome, sigla, logo_url
            """,
            payload.name,
            payload.tag,
            team_id,
            user_id,
        )
        await conn.execute("DELETE FROM time_membros WHERE time_id = $1", team_id)
        await _upsert_team_members(conn, team_id, accounts)

    return TeamOut(
        id=str(updated["id"]),
        name=updated["nome"],
        tag=updated["sigla"],
        logoPath=updated["logo_url"] or "",
        members=[
            TeamMemberOut(id=a.puuid, nick=a.nick, tag=a.tag)
            for a in accounts
        ],
    )


async def delete_team(
    db: Database,
    *,
    user_id: int,
    raw_team_id: str,
) -> DeleteTeamResponse:
    team_id = _parse_team_id(raw_team_id)

    async with db.transaction() as conn:
        current_active = await conn.fetchval(
            "SELECT time_ativo_id FROM usuarios WHERE id = $1 FOR UPDATE",
            user_id,
        )
        deleted_id = await conn.fetchval(
            """
            DELETE FROM times
            WHERE id = $1 AND dono_usuario_id = $2
            RETURNING id
            """,
            team_id,
            user_id,
        )
        if deleted_id is None:
            raise AppError(404, _TEAM_NOT_FOUND_MSG)

        if current_active == team_id:
            next_team_id = await conn.fetchval(
                """
                SELECT id FROM times
                WHERE dono_usuario_id = $1
                ORDER BY id ASC
                LIMIT 1
                """,
                user_id,
            )
            await conn.execute(
                """
                UPDATE usuarios
                SET time_ativo_id = $1, atualizado_em = NOW()
                WHERE id = $2
                """,
                next_team_id,
                user_id,
            )

    return DeleteTeamResponse(teamId=str(team_id))


async def set_active_team(
    db: Database,
    *,
    user_id: int,
    raw_team_id: str,
) -> ActiveTeamResponse:
    cleaned = raw_team_id.strip()
    if not cleaned:
        await db.execute(
            "UPDATE usuarios SET time_ativo_id = NULL, atualizado_em = NOW() WHERE id = $1",
            user_id,
        )
        return ActiveTeamResponse(activeTeamId="")

    team_id = _parse_team_id(cleaned)
    owned_id = await db.fetchval(
        "SELECT id FROM times WHERE id = $1 AND dono_usuario_id = $2",
        team_id,
        user_id,
    )
    if owned_id is None:
        raise AppError(404, _TEAM_NOT_FOUND_MSG)

    await db.execute(
        "UPDATE usuarios SET time_ativo_id = $1, atualizado_em = NOW() WHERE id = $2",
        team_id,
        user_id,
    )
    return ActiveTeamResponse(activeTeamId=str(team_id))
