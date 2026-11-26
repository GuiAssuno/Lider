-- =============================================================================
--  Migracao 001: Esquema inicial do projeto LIDER (PostgreSQL)
--  - Chave estrangeira corrigida: usuarios.atleta_puuid -> atletas(puuid)
--  - Tabela refresh_tokens (uso unico, armazenado apenas como hash SHA-256)
--  - Coluna ordem em time_membros (posicao do jogador no elenco)
--  - lineup_hash CHAR(64) em partida_time_resumo
--  - Clausulas ON DELETE, restricoes CHECK e indices em todas as chaves
-- =============================================================================

CREATE TABLE atletas (
    puuid          VARCHAR(78)  PRIMARY KEY,
    nick           VARCHAR(64)  NOT NULL,
    tag            VARCHAR(16)  NOT NULL,
    regiao         VARCHAR(10)  NOT NULL DEFAULT 'BR'
                   CHECK (regiao IN ('BR', 'NA', 'EUW', 'EUNE', 'LAN', 'KR')),
    nivel          INTEGER      NOT NULL DEFAULT 1 CHECK (nivel >= 1),
    icone_url      VARCHAR(500) NOT NULL DEFAULT '',
    criado_em      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_atletas_nick_tag ON atletas (LOWER(nick), LOWER(tag));

CREATE TABLE usuarios (
    id             BIGSERIAL    PRIMARY KEY,
    email          VARCHAR(255) NOT NULL,
    senha_hash     TEXT         NOT NULL,
    atleta_puuid   VARCHAR(78)  REFERENCES atletas(puuid) ON DELETE SET NULL,
    time_ativo_id  BIGINT,
    criado_em      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_usuarios_email_lower ON usuarios (LOWER(email));
CREATE INDEX idx_usuarios_atleta_puuid ON usuarios (atleta_puuid);

CREATE TABLE refresh_tokens (
    id           BIGSERIAL   PRIMARY KEY,
    usuario_id   BIGINT      NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash   CHAR(64)    NOT NULL UNIQUE,
    expira_em    TIMESTAMPTZ NOT NULL,
    usado_em     TIMESTAMPTZ,
    revogado_em  TIMESTAMPTZ,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_usuario ON refresh_tokens (usuario_id);
CREATE INDEX idx_refresh_tokens_expira  ON refresh_tokens (expira_em);

CREATE TABLE times (
    id               BIGSERIAL    PRIMARY KEY,
    dono_usuario_id  BIGINT       NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nome             VARCHAR(80)  NOT NULL CHECK (char_length(BTRIM(nome)) > 0),
    sigla            VARCHAR(5)   NOT NULL CHECK (char_length(sigla) BETWEEN 2 AND 5),
    logo_url         VARCHAR(500) NOT NULL DEFAULT '',
    criado_em        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    atualizado_em    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_times_dono ON times (dono_usuario_id);

ALTER TABLE usuarios
    ADD CONSTRAINT fk_usuarios_time_ativo
    FOREIGN KEY (time_ativo_id) REFERENCES times(id) ON DELETE SET NULL;

CREATE TABLE time_membros (
    time_id        BIGINT      NOT NULL REFERENCES times(id) ON DELETE CASCADE,
    atleta_puuid   VARCHAR(78) NOT NULL REFERENCES atletas(puuid) ON DELETE CASCADE,
    ordem          SMALLINT    NOT NULL CHECK (ordem >= 0),
    adicionado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (time_id, atleta_puuid),
    UNIQUE (time_id, ordem)
);

CREATE INDEX idx_time_membros_atleta ON time_membros (atleta_puuid);

-- =============================================================================
--  Tabelas base de dominio para as proximas etapas (5, 6 e 7)
-- =============================================================================

CREATE TABLE campeoes (
    id             INTEGER      PRIMARY KEY,
    chave          VARCHAR(64)  NOT NULL UNIQUE,
    nome           VARCHAR(80)  NOT NULL,
    icone_url      VARCHAR(500) NOT NULL DEFAULT '',
    patch          VARCHAR(20)  NOT NULL DEFAULT '',
    atualizado_em  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE campeao_tags (
    campeao_id  INTEGER     NOT NULL REFERENCES campeoes(id) ON DELETE CASCADE,
    tag         VARCHAR(32) NOT NULL,
    peso        SMALLINT    NOT NULL CHECK (peso BETWEEN 1 AND 5),
    PRIMARY KEY (campeao_id, tag)
);

CREATE INDEX idx_campeao_tags_tag ON campeao_tags (tag);

CREATE TABLE partidas (
    id           VARCHAR(64) PRIMARY KEY,
    regiao       VARCHAR(10) NOT NULL,
    fila_id      INTEGER     NOT NULL,
    patch        VARCHAR(20) NOT NULL,
    duracao_seg  INTEGER     NOT NULL CHECK (duracao_seg >= 0),
    inicio_em    TIMESTAMPTZ NOT NULL,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_partidas_inicio ON partidas (inicio_em DESC);
CREATE INDEX idx_partidas_fila_patch ON partidas (fila_id, patch);

CREATE TABLE partida_participantes (
    partida_id     VARCHAR(64) NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
    atleta_puuid   VARCHAR(78) NOT NULL REFERENCES atletas(puuid) ON DELETE RESTRICT,
    lado           SMALLINT    NOT NULL CHECK (lado IN (100, 200)),
    campeao_id     INTEGER     REFERENCES campeoes(id) ON DELETE RESTRICT,
    rota           VARCHAR(16),
    vitoria        BOOLEAN     NOT NULL,
    abates         SMALLINT    NOT NULL DEFAULT 0 CHECK (abates >= 0),
    mortes         SMALLINT    NOT NULL DEFAULT 0 CHECK (mortes >= 0),
    assistencias   SMALLINT    NOT NULL DEFAULT 0 CHECK (assistencias >= 0),
    farm           INTEGER     NOT NULL DEFAULT 0 CHECK (farm >= 0),
    ouro           INTEGER     NOT NULL DEFAULT 0 CHECK (ouro >= 0),
    dano_campeoes  INTEGER     NOT NULL DEFAULT 0 CHECK (dano_campeoes >= 0),
    visao          INTEGER     NOT NULL DEFAULT 0 CHECK (visao >= 0),
    gd_15          INTEGER,
    csd_15         INTEGER,
    PRIMARY KEY (partida_id, atleta_puuid)
);

CREATE INDEX idx_partida_part_atleta  ON partida_participantes (atleta_puuid);
CREATE INDEX idx_partida_part_campeao ON partida_participantes (campeao_id);

CREATE TABLE partida_time_resumo (
    partida_id              VARCHAR(64) NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
    time_id                 BIGINT      NOT NULL REFERENCES times(id) ON DELETE CASCADE,
    lado                    SMALLINT    NOT NULL CHECK (lado IN (100, 200)),
    vitoria                 BOOLEAN     NOT NULL,
    lineup_hash             CHAR(64)    NOT NULL,
    membros_qtd             SMALLINT    NOT NULL CHECK (membros_qtd >= 2),
    maior_vantagem_ouro     INTEGER,
    maior_desvantagem_ouro  INTEGER,
    primeira_torre_seg      INTEGER,
    primeiro_dragao_seg     INTEGER,
    primeiro_barao_seg      INTEGER,
    tipo_composicao         VARCHAR(32),
    PRIMARY KEY (partida_id, time_id)
);

CREATE INDEX idx_partida_time_resumo_time   ON partida_time_resumo (time_id);
CREATE INDEX idx_partida_time_resumo_lineup ON partida_time_resumo (time_id, lineup_hash);
