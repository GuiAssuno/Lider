# LÍDER Backend — API REST (Etapa 2)

API em **Python 3.11+ / FastAPI / PostgreSQL (`asyncpg`)** responsável pela autenticação, gestão de sessão (JWT + refresh token de uso único), vínculo de conta Riot e CRUD de times no formato consumido pelo launcher Qt (`frontend/resources/mock/`).

---

## Pré-requisitos

- **Python 3.11+**
- **PostgreSQL 16** (local ou via **Docker Desktop** com `docker-compose.yml`)

---

## Como rodar localmente (Windows)

Na pasta `backend/`:

```bat
docker compose up -d
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Antes de rodar a migração, gere um `JWT_SECRET` aleatório e coloque no `.env`:

```bat
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Aplique as migrações e suba a API:

```bat
python scripts\migrate.py
uvicorn app.main:app --reload
```

A documentação interativa (Swagger) fica disponível em:
- http://127.0.0.1:8000/docs

---

## Rotas implementadas (Etapa 2)

Todas as respostas de erro retornam `{"message": "texto em português"}`.

| Método e Rota | Autenticação | Descrição | Resposta |
|---|---|---|---|
| `GET /health` | Pública | Verifica saúde da API e conexão com PostgreSQL | `{"status":"ok"}` |
| `POST /auth/register` | Pública | Cria conta (Argon2id, senha >= 8 caracteres) | `201` `{accessToken, refreshToken, tokenType, expiresIn, profile, needsLink}` |
| `POST /auth/login` | Pública | Autentica (tempo constante e mensagem única de erro) | `200` `{accessToken, refreshToken, tokenType, expiresIn, profile, needsLink}` |
| `POST /auth/refresh` | Pública (refresh token) | Rotaciona refresh token (uso único com detecção de reuso) | `200` `{accessToken, refreshToken, tokenType, expiresIn}` |
| `POST /auth/logout` | Pública | Revoga refresh token | `204 No Content` |
| `GET /me` | Bearer JWT | Perfil atual, `needsLink` e `activeTeamId` | `200` `{profile, needsLink, activeTeamId}` |
| `PUT /me/riot-account` | Bearer JWT | Vincula Nick, Tag e Região (resolve PUUID) | `200` `{profile, needsLink}` |
| `PUT /me/active-team` | Bearer JWT | Define o time ativo do usuário | `200` `{activeTeamId}` |
| `GET /teams` | Bearer JWT | Lista times do usuário autenticado (mesmo formato de `teams.json`) | `200` `{teams:[...], activeTeamId}` |
| `POST /teams` | Bearer JWT | Cria time (mín. 2 jogadores distintos, máx. 30, sigla 2..5) | `201` `{team:{...}}` |
| `PUT /teams/{id}` | Bearer JWT | Atualiza time do usuário (preserva ordem dos membros) | `200` `{team:{...}}` |
| `DELETE /teams/{id}` | Bearer JWT | Exclui time do usuário e atualiza `activeTeamId` | `200` `{teamId}` |

---

## Pontos importantes

- **`RIOT_MODE=fake` (padrão em `.env.example`):** gera PUUIDs determinísticos a partir de `Nick#Tag` sem depender de rede ou chave da Riot. Quando tiver uma chave no Developer Portal, troque para `RIOT_MODE=real` e preencha `RIOT_API_KEY`.
- **Logo ignorado na Etapa 2:** o campo `logoPath` enviado pelo launcher é descartado de propósito; a URL real do logo será definida pelo endpoint multipart da Etapa 4.
- **Isolamento de dados:** todas as consultas de time filtram por `dono_usuario_id = usuário autenticado`.

---

## Testes automatizados

> **Atenção:** os testes de integração recriam o schema do banco configurado em `TEST_DATABASE_URL` (padrão `lider_test`, criado automaticamente pelo `docker-compose.yml`). Nunca aponte `TEST_DATABASE_URL` para o banco principal.

```bat
.venv\Scripts\activate
pytest -v
```

Para rodar apenas os testes unitários (sem PostgreSQL):

```bat
pytest -v tests/test_security_unit.py
```
