"""Rotas de autenticacao: cadastro, login, renovacao de sessao e logout."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response, status

from app.config import Settings
from app.db import Database
from app.deps import get_db, get_settings
from app.schemas import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPairResponse,
)
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["Autenticação"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    body: RegisterRequest,
    db: Database = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
    return await auth_service.register_user(
        db,
        settings,
        email=str(body.email),
        password=body.password,
    )


@router.post("/login", response_model=AuthResponse)
async def login(
    body: LoginRequest,
    db: Database = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
    return await auth_service.login_user(
        db,
        settings,
        email=str(body.email),
        password=body.password,
    )


@router.post("/refresh", response_model=TokenPairResponse)
async def refresh(
    body: RefreshRequest,
    db: Database = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> TokenPairResponse:
    return await auth_service.refresh_session(
        db,
        settings,
        raw_refresh_token=body.refreshToken,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    body: LogoutRequest | None = None,
    db: Database = Depends(get_db),
) -> Response:
    await auth_service.logout_user(
        db,
        raw_refresh_token=body.refreshToken if body else None,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
