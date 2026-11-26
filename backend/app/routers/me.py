"""Rotas do usuario autenticado: perfil, vinculo Riot e time ativo."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.db import Database
from app.deps import AuthenticatedUser, get_current_user, get_db, get_riot_client
from app.schemas import (
    ActiveTeamRequest,
    ActiveTeamResponse,
    LinkRiotAccountRequest,
    LinkRiotAccountResponse,
    MeResponse,
)
from app.services import auth_service, team_service
from app.services.riot_client import RiotClient

router = APIRouter(prefix="/me", tags=["Perfil"])


@router.get("", response_model=MeResponse)
async def get_profile(
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> MeResponse:
    return await auth_service.get_me(db, user_id=user.id)


@router.put("/riot-account", response_model=LinkRiotAccountResponse)
async def link_riot_account(
    body: LinkRiotAccountRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
    riot_client: RiotClient = Depends(get_riot_client),
) -> LinkRiotAccountResponse:
    return await auth_service.link_riot_account(
        db,
        riot_client,
        user_id=user.id,
        nick=body.nick,
        tag=body.tag,
        region=body.region,
    )


@router.put("/active-team", response_model=ActiveTeamResponse)
async def update_active_team(
    body: ActiveTeamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> ActiveTeamResponse:
    return await team_service.set_active_team(
        db,
        user_id=user.id,
        raw_team_id=body.teamId,
    )
