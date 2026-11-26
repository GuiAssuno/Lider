"""Dependencias compartilhadas das rotas FastAPI."""

from __future__ import annotations

from dataclasses import dataclass

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings
from app.db import Database
from app.errors import AppError
from app.security import decode_access_token
from app.services.riot_client import RiotClient

_BEARER_SCHEME = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    id: int
    email: str


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_db(request: Request) -> Database:
    return request.app.state.db


def get_riot_client(request: Request) -> RiotClient:
    return request.app.state.riot_client


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_BEARER_SCHEME),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer" or not credentials.credentials:
        raise AppError(401, "Autenticação necessária.")

    payload = decode_access_token(
        credentials.credentials,
        secret=settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    try:
        user_id = int(payload["sub"])
    except (KeyError, TypeError, ValueError) as exc:
        raise AppError(401, "Token de acesso inválido.") from exc

    return AuthenticatedUser(id=user_id, email=str(payload.get("email", "")))
