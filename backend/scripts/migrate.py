"""Executor idempotente de migracoes SQL do projeto LIDER.

Uso (a partir da pasta backend/):
    python scripts/migrate.py
    python scripts/migrate.py --test
    python scripts/migrate.py --url postgresql://lider:lider@127.0.0.1:5432/lider
"""

from __future__ import annotations

import argparse
import asyncio
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import asyncpg

from app.config import get_settings

MIGRATIONS_DIR = ROOT / "migrations"


async def apply_migrations(database_url: str, *, reset: bool = False) -> list[str]:
    """Aplica todas as migracoes pendentes em ordem alfabetica.

    Retorna os nomes dos arquivos aplicados nesta execucao.
    Se `reset=True`, limpa o schema public antes (uso exclusivo em testes).
    """
    conn = await asyncpg.connect(database_url)
    applied_now: list[str] = []
    try:
        if reset:
            await conn.execute("DROP SCHEMA IF EXISTS public CASCADE;")
            await conn.execute("CREATE SCHEMA public;")

        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version     VARCHAR(255) PRIMARY KEY,
                applied_em  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
            )
            """
        )

        rows = await conn.fetch("SELECT version FROM schema_migrations")
        already_applied = {r["version"] for r in rows}

        sql_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
        for sql_file in sql_files:
            version = sql_file.name
            if version in already_applied:
                continue

            sql = sql_file.read_text(encoding="utf-8")
            async with conn.transaction():
                await conn.execute(sql)
                await conn.execute(
                    "INSERT INTO schema_migrations (version) VALUES ($1)",
                    version,
                )
            applied_now.append(version)

        return applied_now
    finally:
        await conn.close()


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Aplica migracoes SQL no PostgreSQL.")
    parser.add_argument("--url", help="URL de conexao PostgreSQL (sobrepoe .env).")
    parser.add_argument(
        "--test",
        action="store_true",
        help="Usa TEST_DATABASE_URL em vez de DATABASE_URL.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    settings = get_settings()
    if args.url:
        db_url = args.url
    elif args.test:
        db_url = settings.test_database_url
    else:
        db_url = settings.database_url

    applied = asyncio.run(apply_migrations(db_url))
    if applied:
        for name in applied:
            print(f"[OK] Migracao aplicada: {name}")
    else:
        print("[OK] Nenhuma migracao pendente.")


if __name__ == "__main__":
    main()
