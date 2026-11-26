"""Rotas CRUD de times do usuario autenticado."""

from __future__ import annotations

from fastapi import APIRouter, Depends, status

from app.db import Database
from app.deps import AuthenticatedUser, get_current_user, get_db, get_riot_client
from app.schemas import (
    DeleteTeamResponse,
    TeamResponse,
    TeamSaveRequest,
    TeamsListResponse,
)
from app.services import team_service
from app.services.riot_client import RiotClient

router = APIRouter(prefix="/teams", tags=["Times"])


@router.get("", response_model=TeamsListResponse)
async def list_teams(
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> TeamsListResponse:
    return await team_service.list_teams(db, user_id=user.id)


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create_team(
    body: TeamSaveRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
    riot_client: RiotClient = Depends(get_riot_client),
) -> TeamResponse:
    team = await team_service.create_team(
        db,
        riot_client,
        user_id=user.id,
        payload=body,
    )
    return TeamResponse(team=team)


@router.put("/{team_id}", response_model=TeamResponse)
async def update_team(
    team_id: str,
    body: TeamSaveRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
    riot_client: RiotClient = Depends(get_riot_client),
) -> TeamResponse:
    team = await team_service.update_team(
        db,
        riot_client,
        user_id=user.id,
        raw_team_id=team_id,
        payload=body,
    )
    return TeamResponse(team=team)


@router.delete("/{team_id}", response_model=DeleteTeamResponse)
async def delete_team(
    team_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    db: Database = Depends(get_db),
) -> DeleteTeamResponse:
    return await team_service.delete_team(
        db,
        user_id=user.id,
        raw_team_id=team_id,
    )
