"""Seguranca: hash de senha Argon2id (tempo constante), JWT de acesso e refresh tokens."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Any

from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
import jwt

from app.errors import AppError

_HASHER = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)

# Hash ficticio pre-calculado para garantir o mesmo tempo de resposta
# quando o e-mail nao existe no banco (evita enumeracao de contas).
_DUMMY_PASSWORD_HASH = _HASHER.hash("dummy-password-for-constant-time-login")


def hash_password(password: str) -> str:
    return _HASHER.hash(password)


def verify_password(password: str, stored_hash: str | None) -> bool:
    """Verifica senha sempre executando Argon2id, mesmo se stored_hash for None."""
    target_hash = stored_hash if stored_hash else _DUMMY_PASSWORD_HASH
    try:
        matched = _HASHER.verify(target_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False
    return bool(stored_hash) and matched


def password_needs_rehash(stored_hash: str) -> bool:
    return _HASHER.check_needs_rehash(stored_hash)


def create_access_token(
    *,
    user_id: int,
    email: str,
    secret: str,
    algorithm: str = "HS256",
    expires_minutes: int = 15,
) -> tuple[str, int]:
    now = datetime.now(timezone.utc)
    expires_delta = timedelta(minutes=expires_minutes)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "type": "access",
        "iat": now,
        "exp": now + expires_delta,
    }
    token = jwt.encode(payload, secret, algorithm=algorithm)
    return token, int(expires_delta.total_seconds())


def decode_access_token(
    token: str,
    *,
    secret: str,
    algorithm: str = "HS256",
) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, secret, algorithms=[algorithm])
    except jwt.ExpiredSignatureError as exc:
        raise AppError(401, "Sessão expirada. Faça login novamente.") from exc
    except jwt.InvalidTokenError as exc:
        raise AppError(401, "Token de acesso inválido.") from exc

    if payload.get("type") != "access" or not payload.get("sub"):
        raise AppError(401, "Token de acesso inválido.")
    return payload


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
