"""Servicos de autenticacao, sessao (JWT + refresh de uso unico) e perfil Riot."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import asyncpg

from app.config import Settings
from app.db import Database
from app.errors import AppError
from app.schemas import (
    AuthResponse,
    LinkRiotAccountResponse,
    MeResponse,
    ProfileOut,
    TokenPairResponse,
)
from app.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    password_needs_rehash,
    verify_password,
)
from app.services.riot_client import RiotClient

_INVALID_CREDENTIALS_MSG = "E-mail ou senha inválidos."
_SESSION_EXPIRED_MSG = "Sessão expirada. Faça login novamente."


def _row_to_profile(row: asyncpg.Record) -> tuple[ProfileOut, bool]:
    has_athlete = row["atleta_puuid"] is not None
    profile = ProfileOut(
        email=row["email"],
        nick=row["nick"] or "",
        tag=row["tag"] or "",
        region=row["regiao"] or "",
        level=int(row["nivel"]) if row["nivel"] is not None else 0,
        iconUrl=row["icone_url"] or "",
    )
    return profile, (not has_athlete)


async def _fetch_user_profile_row(
    conn_or_db: Database | asyncpg.Connection,
    user_id: int,
) -> asyncpg.Record | None:
    return await conn_or_db.fetchrow(
        """
        SELECT u.id, u.email, u.atleta_puuid, u.time_ativo_id,
               a.nick, a.tag, a.regiao, a.nivel, a.icone_url
        FROM usuarios u
        LEFT JOIN atletas a ON a.puuid = u.atleta_puuid
        WHERE u.id = $1
        """,
        user_id,
    )


async def _issue_refresh_token(
    conn: asyncpg.Connection,
    *,
    user_id: int,
    refresh_days: int,
) -> str:
    raw_token = generate_refresh_token()
    token_hash = hash_refresh_token(raw_token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=refresh_days)
    await conn.execute(
        """
        INSERT INTO refresh_tokens (usuario_id, token_hash, expira_em)
        VALUES ($1, $2, $3)
        """,
        user_id,
        token_hash,
        expires_at,
    )
    return raw_token


async def register_user(
    db: Database,
    settings: Settings,
    *,
    email: str,
    password: str,
) -> AuthResponse:
    normalized_email = email.strip().lower()
    password_hash = hash_password(password)

    try:
        async with db.transaction() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO usuarios (email, senha_hash)
                VALUES ($1, $2)
                RETURNING id, email
                """,
                normalized_email,
                password_hash,
            )
            user_id = int(row["id"])
            refresh_token = await _issue_refresh_token(
                conn,
                user_id=user_id,
                refresh_days=settings.refresh_token_days,
            )
    except asyncpg.UniqueViolationError as exc:
        raise AppError(409, "E-mail já cadastrado.") from exc

    access_token, expires_in = create_access_token(
        user_id=user_id,
        email=normalized_email,
        secret=settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
        expires_minutes=settings.access_token_minutes,
    )
    profile = ProfileOut(email=normalized_email)
    return AuthResponse(
        accessToken=access_token,
        refreshToken=refresh_token,
        expiresIn=expires_in,
        profile=profile,
        needsLink=True,
    )


async def login_user(
    db: Database,
    settings: Settings,
    *,
    email: str,
    password: str,
) -> AuthResponse:
    normalized_email = email.strip().lower()
    row = await db.fetchrow(
        """
        SELECT u.id, u.email, u.senha_hash, u.atleta_puuid, u.time_ativo_id,
               a.nick, a.tag, a.regiao, a.nivel, a.icone_url
        FROM usuarios u
        LEFT JOIN atletas a ON a.puuid = u.atleta_puuid
        WHERE LOWER(u.email) = $1
        """,
        normalized_email,
    )

    stored_hash = row["senha_hash"] if row is not None else None
    if not verify_password(password, stored_hash):
        raise AppError(401, _INVALID_CREDENTIALS_MSG)

    assert row is not None
    user_id = int(row["id"])

    async with db.transaction() as conn:
        if password_needs_rehash(stored_hash):
            await conn.execute(
                "UPDATE usuarios SET senha_hash = $1, atualizado_em = NOW() WHERE id = $2",
                hash_password(password),
                user_id,
            )
        refresh_token = await _issue_refresh_token(
            conn,
            user_id=user_id,
            refresh_days=settings.refresh_token_days,
        )

    access_token, expires_in = create_access_token(
        user_id=user_id,
        email=row["email"],
        secret=settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
        expires_minutes=settings.access_token_minutes,
    )
    profile, needs_link = _row_to_profile(row)
    return AuthResponse(
        accessToken=access_token,
        refreshToken=refresh_token,
        expiresIn=expires_in,
        profile=profile,
        needsLink=needs_link,
    )


async def refresh_session(
    db: Database,
    settings: Settings,
    *,
    raw_refresh_token: str,
) -> TokenPairResponse:
    token_hash = hash_refresh_token(raw_refresh_token)
    now = datetime.now(timezone.utc)

    revoked = False
    user_id = 0
    user_email = ""
    new_refresh_token = ""

    async with db.transaction() as conn:
        row = await conn.fetchrow(
            """
            SELECT rt.id, rt.usuario_id, rt.expira_em, rt.usado_em, rt.revogado_em, u.email
            FROM refresh_tokens rt
            JOIN usuarios u ON u.id = rt.usuario_id
            WHERE rt.token_hash = $1
            FOR UPDATE OF rt
            """,
            token_hash,
        )
        if row is None:
            raise AppError(401, _SESSION_EXPIRED_MSG)

        user_id = int(row["usuario_id"])

        # Token de uso unico: tentativa de reuso ou uso apos revogacao invalida
        # todas as sessoes ativas do usuario por seguranca.
        # Nota: sai da transacao sem lancar excecao para confirmar o UPDATE de revogacao.
        if row["usado_em"] is not None or row["revogado_em"] is not None:
            await conn.execute(
                """
                UPDATE refresh_tokens
                SET revogado_em = NOW()
                WHERE usuario_id = $1 AND revogado_em IS NULL
                """,
                user_id,
            )
            revoked = True
        elif row["expira_em"] <= now:
            await conn.execute(
                "UPDATE refresh_tokens SET revogado_em = NOW() WHERE id = $1",
                row["id"],
            )
            revoked = True
        else:
            await conn.execute(
                "UPDATE refresh_tokens SET usado_em = NOW() WHERE id = $1",
                row["id"],
            )
            new_refresh_token = await _issue_refresh_token(
                conn,
                user_id=user_id,
                refresh_days=settings.refresh_token_days,
            )
            user_email = row["email"]

    if revoked:
        raise AppError(401, _SESSION_EXPIRED_MSG)

    access_token, expires_in = create_access_token(
        user_id=user_id,
        email=user_email,
        secret=settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
        expires_minutes=settings.access_token_minutes,
    )
    return TokenPairResponse(
        accessToken=access_token,
        refreshToken=new_refresh_token,
        expiresIn=expires_in,
    )


async def logout_user(db: Database, *, raw_refresh_token: str | None) -> None:
    if not raw_refresh_token:
        return
    token_hash = hash_refresh_token(raw_refresh_token)
    await db.execute(
        """
        UPDATE refresh_tokens
        SET revogado_em = NOW()
        WHERE token_hash = $1 AND revogado_em IS NULL
        """,
        token_hash,
    )


async def get_me(db: Database, *, user_id: int) -> MeResponse:
    row = await _fetch_user_profile_row(db, user_id)
    if row is None:
        raise AppError(401, _SESSION_EXPIRED_MSG)
    profile, needs_link = _row_to_profile(row)
    active_team_id = str(row["time_ativo_id"]) if row["time_ativo_id"] is not None else ""
    return MeResponse(
        profile=profile,
        needsLink=needs_link,
        activeTeamId=active_team_id,
    )


async def link_riot_account(
    db: Database,
    riot_client: RiotClient,
    *,
    user_id: int,
    nick: str,
    tag: str,
    region: str,
) -> LinkRiotAccountResponse:
    account = await riot_client.resolve_account(nick, tag, region)

    async with db.transaction() as conn:
        await conn.execute(
            """
            INSERT INTO atletas (puuid, nick, tag, regiao, nivel, icone_url)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (puuid) DO UPDATE SET
                nick = EXCLUDED.nick,
                tag = EXCLUDED.tag,
                regiao = EXCLUDED.regiao,
                nivel = EXCLUDED.nivel,
                icone_url = EXCLUDED.icone_url,
                atualizado_em = NOW()
            """,
            account.puuid,
            account.nick,
            account.tag,
            account.region,
            account.level,
            account.icon_url,
        )
        updated = await conn.fetchrow(
            """
            UPDATE usuarios
            SET atleta_puuid = $1, atualizado_em = NOW()
            WHERE id = $2
            RETURNING email
            """,
            account.puuid,
            user_id,
        )
        if updated is None:
            raise AppError(401, _SESSION_EXPIRED_MSG)

    profile = ProfileOut(
        email=updated["email"],
        nick=account.nick,
        tag=account.tag,
        region=account.region,
        level=account.level,
        iconUrl=account.icon_url,
    )
    return LinkRiotAccountResponse(profile=profile, needsLink=False)
