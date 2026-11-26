"""Esquemas Pydantic de entrada e saida alinhados ao contrato do launcher (resources/mock/)."""

from __future__ import annotations

import re

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.config import MAX_MEMBERS_PER_TEAM, VALID_REGIONS

_TAG_PATTERN = re.compile(r"^[A-Za-z0-9]{2,5}$")


class ErrorResponse(BaseModel):
    message: str


class ProfileOut(BaseModel):
    email: str
    nick: str = ""
    tag: str = ""
    region: str = ""
    level: int = 0
    iconUrl: str = ""


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        if isinstance(value, str):
            return value.strip().lower()
        return value

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if len(value) < 8:
            raise ValueError("A senha deve ter pelo menos 8 caracteres.")
        if len(value) > 128:
            raise ValueError("A senha deve ter no máximo 128 caracteres.")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        if isinstance(value, str):
            return value.strip().lower()
        return value

    @field_validator("password")
    @classmethod
    def validate_password_non_empty(cls, value: str) -> str:
        if not value:
            raise ValueError("Informe a senha.")
        return value


class AuthResponse(BaseModel):
    accessToken: str
    refreshToken: str
    tokenType: str = "bearer"
    expiresIn: int
    profile: ProfileOut
    needsLink: bool


class RefreshRequest(BaseModel):
    refreshToken: str = Field(min_length=1)


class TokenPairResponse(BaseModel):
    accessToken: str
    refreshToken: str
    tokenType: str = "bearer"
    expiresIn: int


class LogoutRequest(BaseModel):
    refreshToken: str | None = None


class MeResponse(BaseModel):
    profile: ProfileOut
    needsLink: bool
    activeTeamId: str = ""


class LinkRiotAccountRequest(BaseModel):
    nick: str
    tag: str
    region: str = "BR"

    @field_validator("nick")
    @classmethod
    def validate_nick(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned or len(cleaned) > 64:
            raise ValueError("Informe um Nick válido (até 64 caracteres).")
        return cleaned

    @field_validator("tag")
    @classmethod
    def validate_tag(cls, value: str) -> str:
        cleaned = value.strip().lstrip("#")
        if not cleaned or len(cleaned) > 16:
            raise ValueError("Informe uma Tag válida (até 16 caracteres).")
        return cleaned

    @field_validator("region")
    @classmethod
    def validate_region(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if cleaned not in VALID_REGIONS:
            valid = ", ".join(VALID_REGIONS)
            raise ValueError(f"Região inválida. Use uma das opções: {valid}.")
        return cleaned


class LinkRiotAccountResponse(BaseModel):
    profile: ProfileOut
    needsLink: bool = False


class ActiveTeamRequest(BaseModel):
    teamId: str = ""

    @field_validator("teamId", mode="before")
    @classmethod
    def normalize_team_id(cls, value: object) -> str:
        if value is None:
            return ""
        return str(value).strip()


class ActiveTeamResponse(BaseModel):
    activeTeamId: str


class TeamMemberIn(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str | None = None
    nick: str
    tag: str

    @field_validator("nick")
    @classmethod
    def validate_nick(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned or len(cleaned) > 64:
            raise ValueError("Informe o Nick de todos os jogadores.")
        return cleaned

    @field_validator("tag")
    @classmethod
    def validate_tag(cls, value: str) -> str:
        cleaned = value.strip().lstrip("#")
        if not cleaned or len(cleaned) > 16:
            raise ValueError("Informe a Tag de todos os jogadores.")
        return cleaned


class TeamMemberOut(BaseModel):
    id: str
    nick: str
    tag: str


class TeamSaveRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str
    tag: str
    # Aceito para compatibilidade com o launcher atual, mas ignorado de proposito.
    # O logo real sera gravado exclusivamente pelo endpoint de upload (Etapa 4).
    logoPath: str | None = None
    members: list[TeamMemberIn]

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Informe o nome do time.")
        if len(cleaned) > 80:
            raise ValueError("O nome do time deve ter no máximo 80 caracteres.")
        return cleaned

    @field_validator("tag")
    @classmethod
    def validate_tag(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if not _TAG_PATTERN.match(cleaned):
            raise ValueError("A abreviação deve ter de 2 a 5 letras ou números.")
        return cleaned

    @field_validator("members")
    @classmethod
    def validate_members_count(cls, value: list[TeamMemberIn]) -> list[TeamMemberIn]:
        if len(value) > MAX_MEMBERS_PER_TEAM:
            raise ValueError(
                f"Um time pode receber no máximo {MAX_MEMBERS_PER_TEAM} jogadores por envio."
            )
        return value


class TeamOut(BaseModel):
    id: str
    name: str
    tag: str
    logoPath: str = ""
    members: list[TeamMemberOut]


class TeamResponse(BaseModel):
    team: TeamOut


class TeamsListResponse(BaseModel):
    teams: list[TeamOut]
    activeTeamId: str = ""


class DeleteTeamResponse(BaseModel):
    teamId: str
