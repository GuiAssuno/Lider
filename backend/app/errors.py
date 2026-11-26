"""Excecoes de dominio traduzidas para JSON {"message": "..."}."""

from __future__ import annotations


class AppError(Exception):
    """Erro esperado com codigo HTTP e mensagem voltada ao usuario."""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.message = message
