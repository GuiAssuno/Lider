"""Resolucao de contas Riot (Nick#Tag -> PUUID) em modo fake (dev) ou real."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
from urllib.parse import quote

import httpx

from app.errors import AppError

_REGION_TO_CLUSTER: dict[str, str] = {
    "BR": "americas",
    "NA": "americas",
    "LAN": "americas",
    "EUW": "europe",
    "EUNE": "europe",
    "KR": "asia",
}


@dataclass(frozen=True)
class RiotAccount:
    puuid: str
    nick: str
    tag: str
    region: str
    level: int = 1
    icon_url: str = ""


class RiotClient:
    """Resolve Nick#Tag em PUUID.

    - RIOT_MODE=fake: gera um PUUID deterministico a partir de Nick#Tag (sem rede).
    - RIOT_MODE=real: consulta account-v1 da Riot API via HTTPS.
    """

    def __init__(
        self,
        *,
        mode: str = "fake",
        api_key: str = "",
        timeout_seconds: float = 10.0,
    ) -> None:
        self.mode = mode
        self.api_key = api_key
        self.timeout_seconds = timeout_seconds

    async def resolve_account(
        self,
        nick: str,
        tag: str,
        region: str = "BR",
    ) -> RiotAccount:
        clean_nick = nick.strip()
        clean_tag = tag.strip().lstrip("#")
        clean_region = region.strip().upper() or "BR"

        if self.mode == "fake":
            return self._resolve_fake(clean_nick, clean_tag, clean_region)
        return await self._resolve_real(clean_nick, clean_tag, clean_region)

    @staticmethod
    def _resolve_fake(nick: str, tag: str, region: str) -> RiotAccount:
        # PUUID deterministico baseado em nick#tag (independente de maiusculas/minusculas),
        # cabendo no limite VARCHAR(78) da Riot.
        seed = f"{nick.lower()}#{tag.lower()}".encode("utf-8")
        digest = hashlib.sha256(seed).hexdigest()
        puuid = f"fake_{digest}"
        return RiotAccount(
            puuid=puuid,
            nick=nick,
            tag=tag,
            region=region,
            level=1,
            icon_url="",
        )

    async def _resolve_real(self, nick: str, tag: str, region: str) -> RiotAccount:
        if not self.api_key:
            raise AppError(
                503,
                "Serviço da Riot indisponível: chave da API não configurada no servidor.",
            )

        cluster = _REGION_TO_CLUSTER.get(region, "americas")
        encoded_nick = quote(nick, safe="")
        encoded_tag = quote(tag, safe="")
        url = (
            f"https://{cluster}.api.riotgames.com/riot/account/v1/accounts/"
            f"by-riot-id/{encoded_nick}/{encoded_tag}"
        )

        try:
            async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                response = await client.get(url, headers={"X-Riot-Token": self.api_key})
        except httpx.TimeoutException as exc:
            raise AppError(504, "Tempo esgotado ao consultar a Riot API.") from exc
        except httpx.HTTPError as exc:
            raise AppError(502, "Não foi possível comunicar com a Riot API.") from exc

        if response.status_code == 404:
            raise AppError(404, f"Conta Riot {nick}#{tag} não encontrada.")
        if response.status_code == 429:
            raise AppError(429, "Limite de consultas à Riot API atingido. Tente novamente em instantes.")
        if response.status_code in (401, 403):
            raise AppError(502, "Falha de autenticação do servidor com a Riot API.")
        if response.status_code >= 400:
            raise AppError(502, "Erro ao consultar a Riot API.")

        data = response.json()
        puuid = str(data.get("puuid", "")).strip()
        if not puuid:
            raise AppError(502, "Resposta inesperada da Riot API.")

        return RiotAccount(
            puuid=puuid,
            nick=str(data.get("gameName") or nick),
            tag=str(data.get("tagLine") or tag),
            region=region,
            level=1,
            icon_url="",
        )
