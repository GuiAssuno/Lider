"""Fixtures compartilhadas para os testes de integracao (PostgreSQL isolado)."""

from __future__ import annotations

from collections.abc import AsyncIterator
from urllib.parse import urlparse

import httpx
import pytest
import pytest_asyncio

from app.config import Settings
from app.main import create_app
from scripts.migrate import apply_migrations


def _test_settings() -> Settings:
    base = Settings()
    db_name = urlparse(base.test_database_url).path.lstrip("/")
    if "test" not in db_name.lower() or base.test_database_url == base.database_url:
        raise RuntimeError(
            "TEST_DATABASE_URL deve apontar para um banco exclusivo de testes "
            "(ex.: lider_test) diferente de DATABASE_URL."
        )
    return Settings(
        DATABASE_URL=base.test_database_url,
        TEST_DATABASE_URL=base.test_database_url,
        JWT_SECRET="segredo-exclusivo-de-testes-com-mais-de-32-caracteres",
        ACCESS_TOKEN_MINUTES=15,
        REFRESH_TOKEN_DAYS=30,
        RIOT_MODE="fake",
        RIOT_API_KEY="",
    )


@pytest_asyncio.fixture
async def client() -> AsyncIterator[httpx.AsyncClient]:
    settings = _test_settings()
    try:
        await apply_migrations(settings.database_url, reset=True)
    except Exception as exc:  # pragma: no cover - ambiente sem Postgres
        pytest.skip(f"PostgreSQL de teste indisponivel ({settings.database_url}): {exc}")

    app = create_app(settings_override=settings)
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as ac:
            yield ac
