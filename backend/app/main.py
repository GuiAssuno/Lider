"""Ponto de entrada da API LIDER (FastAPI)."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import Settings, get_settings
from app.db import Database
from app.errors import AppError
from app.routers import auth, me, teams
from app.services.riot_client import RiotClient

logger = logging.getLogger("lider.api")


def _format_validation_error(exc: RequestValidationError) -> str:
    errors = exc.errors()
    if not errors:
        return "Dados inválidos na requisição."

    first = errors[0]
    err_type = str(first.get("type", ""))
    msg = str(first.get("msg", ""))
    loc = [str(part) for part in first.get("loc", ()) if part != "body"]
    field_name = loc[-1] if loc else ""

    if msg.startswith("Value error, "):
        return msg.removeprefix("Value error, ")
    if "email" in field_name and ("email" in err_type or "value_error" in err_type):
        return "Informe um e-mail válido."
    if err_type == "missing":
        return f"Campo obrigatório ausente: {field_name}." if field_name else "Dados obrigatórios ausentes."
    if err_type == "json_invalid":
        return "Corpo JSON inválido."
    return msg or "Dados inválidos na requisição."


def create_app(settings_override: Settings | None = None) -> FastAPI:
    settings = settings_override or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        logging.basicConfig(
            level=getattr(logging, settings.log_level.upper(), logging.INFO),
            format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        )
        db = Database(settings.database_url)
        await db.connect()
        app.state.settings = settings
        app.state.db = db
        app.state.riot_client = RiotClient(
            mode=settings.riot_mode,
            api_key=settings.riot_api_key,
            timeout_seconds=settings.riot_timeout_seconds,
        )
        try:
            yield
        finally:
            await db.close()

    app = FastAPI(
        title="LÍDER API",
        version="0.2.0",
        description="API REST do launcher analítico de League of Legends (Etapa 2: Autenticação e Times).",
        lifespan=lifespan,
    )

    @app.exception_handler(AppError)
    async def handle_app_error(_request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content={"message": exc.message})

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        _request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={"message": _format_validation_error(exc)},
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(
        _request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        detail = exc.detail if isinstance(exc.detail, str) else "Requisição inválida."
        if exc.status_code == 404 and detail == "Not Found":
            detail = "Recurso não encontrado."
        elif exc.status_code == 405:
            detail = "Método HTTP não permitido."
        return JSONResponse(status_code=exc.status_code, content={"message": detail})

    @app.exception_handler(Exception)
    async def handle_unexpected_error(_request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Erro inesperado na requisicao: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"message": "Erro interno no servidor."},
        )

    @app.get("/health", tags=["Sistema"])
    async def health(request: Request) -> dict[str, str]:
        await request.app.state.db.fetchval("SELECT 1")
        return {"status": "ok"}

    app.include_router(auth.router)
    app.include_router(me.router)
    app.include_router(teams.router)

    return app


app = create_app()
