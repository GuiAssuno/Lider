"""Configuracoes tipadas da API carregadas via variaveis de ambiente / .env."""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

VALID_REGIONS: tuple[str, ...] = ("BR", "NA", "EUW", "EUNE", "LAN", "KR")
MAX_MEMBERS_PER_TEAM = 30


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(
        default="postgresql://lider:lider@127.0.0.1:5432/lider",
        alias="DATABASE_URL",
    )
    test_database_url: str = Field(
        default="postgresql://lider:lider@127.0.0.1:5432/lider_test",
        alias="TEST_DATABASE_URL",
    )

    jwt_secret: str = Field(
        default="troque-por-um-segredo-aleatorio-seguro-antes-de-rodar",
        alias="JWT_SECRET",
    )
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    access_token_minutes: int = Field(default=15, ge=1, le=1440, alias="ACCESS_TOKEN_MINUTES")
    refresh_token_days: int = Field(default=30, ge=1, le=365, alias="REFRESH_TOKEN_DAYS")

    riot_mode: Literal["fake", "real"] = Field(default="fake", alias="RIOT_MODE")
    riot_api_key: str = Field(default="", alias="RIOT_API_KEY")
    riot_timeout_seconds: float = Field(default=10.0, gt=0, le=60, alias="RIOT_TIMEOUT_SECONDS")

    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    @field_validator("jwt_secret")
    @classmethod
    def validate_jwt_secret(cls, value: str) -> str:
        if len(value.strip()) < 16:
            raise ValueError("JWT_SECRET precisa ter pelo menos 16 caracteres.")
        return value


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
