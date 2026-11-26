É fácil, porque o frontend já foi feito para isso. Você só escreve uma classe em C++ no cliente e a API no servidor, sem mexer em nenhuma tela. Os trechos abaixo são esqueletos que escrevi agora e não compilei nem rodei.

## 1. A regra de ouro: o app nunca fala com o banco

```
Launcher (Qt)  ──HTTPS + JSON──▶  API (backend)  ──▶  PostgreSQL
                                       │
                                       └──▶  Riot API (chave secreta fica aqui)
```

Se o app acessasse o PostgreSQL direto, a senha do banco e a chave da Riot iriam dentro do executável, e qualquer pessoa poderia extraí-las. A API é quem valida, calcula e fala com o banco.

## 2. O que fica em cada lado

| No backend | No frontend (já pronto) |
|---|---|
| Login, senha, RSO, tokens | Telas e navegação |
| Validação real (mínimo de 2 jogadores, dono do time) | Validação rápida de UX |
| Consultas ao banco e agregações (win rate, sinergias, recordes) | Exibir os dados |
| Chamadas à Riot API e sincronização do histórico | Ponte com o cliente do LoL (LCU), que é local |
| Motor de sugestão do draft, diagnósticos de treino | Estado de tela e animações |
| Upload e redimensionamento de logos | Escolher o arquivo e exibir |

## 3. Mapa de endpoints

Cada valor do enum `Endpoint` vira uma rota HTTP:

| Método no frontend | Rota sugerida |
|---|---|
| `loginWithCredentials` | `POST /auth/login` |
| `loginWithRiot` | `POST /auth/riot` |
| `linkRiotAccount` | `PUT /me/riot-account` |
| `fetchTeams` | `GET /teams` |
| `saveTeam` | `POST /teams` (novo) ou `PUT /teams/{id}` |
| `deleteTeam` | `DELETE /teams/{id}` |
| `fetchTeamAnalysis` | `GET /teams/{id}/analysis` |
| `fetchPlayerStats` | `GET /teams/{id}/players/{puuid}` |
| `fetchDraftCatalog` | `GET /draft/catalog` |
| `analyzeDraft` | `POST /teams/{id}/draft/analyze` |
| `fetchTraining` | `GET /teams/{id}/training` |
| `syncMatchHistory` | `POST /teams/{id}/sync` |

**O ponto principal:** cada resposta precisa ter o mesmo formato JSON dos arquivos em `resources/mock/`. A conversão do banco para esse JSON é trabalho do backend. Listas vêm embrulhadas, por exemplo `{"teams":[...]}`, e erros devem trazer `{"message":"texto para o usuário"}`.

## 4. Ligando no frontend: uma classe

Primeiro adicione o módulo de rede no `CMakeLists.txt`:

```cmake
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)
target_link_libraries(lider PRIVATE Qt6::Network)
```

Depois crie `src/services/HttpBackendService.{h,cpp}`, herdando de `IBackendService`. Este é o coração dela:

```cpp
void HttpBackendService::send(Endpoint ep, const QByteArray &verb,
                              const QString &path, const QJsonObject &body)
{
    QNetworkRequest req(QUrl(m_base + path));            // m_base = "https://api.seudominio.com"
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(10000);
    if (!m_token.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());

    QNetworkReply *r = m_net.sendCustomRequest(req, verb, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(r, &QNetworkReply::finished, this, [this, r, ep] {
        r->deleteLater();
        const QJsonObject obj = QJsonDocument::fromJson(r->readAll()).object();
        if (r->error() != QNetworkReply::NoError) {
            emit requestFailed(ep, obj.value("message").toString(r->errorString()));
            return;
        }
        if (ep == Endpoint::Login)                       // guarda o token da sessão
            m_token = obj.value("accessToken").toString();
        emit responseReady(ep, obj.toVariantMap());
    });
}

void HttpBackendService::fetchTeams()                 { send(Endpoint::Teams, "GET", "/teams"); }
void HttpBackendService::deleteTeam(const QString &id){ send(Endpoint::DeleteTeam, "DELETE", "/teams/" + id); }
void HttpBackendService::loginWithCredentials(const QString &e, const QString &p)
{ send(Endpoint::Login, "POST", "/auth/login", {{"email", e}, {"password", p}}); }
```

Os demais métodos seguem o mesmo padrão de uma linha. Para ativar, troque em `main.cpp`:

```cpp
// MockBackendService backend;
HttpBackendService backend("https://api.seudominio.com");
```

Pontos de atenção:
- **Autenticação:** use JWT de acesso curto (15 min) mais token de renovação. Guarde o token no cofre do Windows, por exemplo com a biblioteca QtKeychain, e nunca em arquivo de texto.
- **HTTPS obrigatório**, tanto em desenvolvimento quanto em produção.
- **Respostas fora de ordem:** o draft já trata isso com o campo `seq`. O backend precisa devolver o mesmo `seq` que recebeu em `analyze`.

## 5. Onde fica a lógica e o acesso ao banco

Use a linguagem que você domina. Como seu SQL é PostgreSQL, o exemplo é em Python/FastAPI, mas Node (NestJS) ou C# servem igual:

```python
@app.get("/teams")
async def list_teams(user=Depends(current_user)):
    rows = await db.fetch("""
        SELECT t.id, t.nome AS name, t.sigla AS tag, t.logo_url AS "logoPath",
               COALESCE(json_agg(json_build_object('id', a.puuid, 'nick', a.nick, 'tag', a.tag))
                        FILTER (WHERE a.puuid IS NOT NULL), '[]') AS members
        FROM times t
        LEFT JOIN time_membros m ON m.time_id = t.id
        LEFT JOIN atletas a ON a.puuid = m.atleta_puuid
        WHERE t.dono_usuario_id = $1
        GROUP BY t.id""", user.id)
    return {"teams": [dict(r) for r in rows], "activeTeamId": str(user.time_ativo_id or "")}
```

Regras que valem para todas as rotas:
- **Sempre filtre pelo dono** (`dono_usuario_id = usuário do token`). Sem isso, um usuário acessa times de outro só trocando o número na URL.
- **Use consultas parametrizadas** (`$1`), nunca concatene texto.
- **Estatísticas pesadas** (sinergias, win rate por campeão): calcule em jobs agendados e grave em tabelas agregadas. A rota só lê o resultado pronto.
- **Riot API:** chame só pelo servidor, com fila e controle de limite de requisições.

## 6. Logo do time

O frontend hoje envia o caminho local do arquivo (`file:///...`). Na versão real o fluxo fica assim:

1. O usuário escolhe a imagem e o app valida formato e 2 MB (já feito).
2. O app salva o time por `POST /teams` (JSON, sem imagem).
3. Em seguida envia a imagem por `POST /teams/{id}/logo` (multipart).
4. O servidor valida de novo, redimensiona, grava e devolve a URL.
5. A tela mostra a URL. O componente `Avatar` já aceita `https://...` em `source`, sem mudar nada.

**Backend (FastAPI + Pillow):**

```python
@app.post("/teams/{team_id}/logo")
async def upload_logo(team_id: int, file: UploadFile, user=Depends(current_user)):
    data = await file.read()
    if len(data) > 2 * 1024 * 1024:
        raise HTTPException(413, "A imagem excede 2 MB.")
    try:
        img = Image.open(io.BytesIO(data)); img.verify()
        img = Image.open(io.BytesIO(data))
    except Exception:
        raise HTTPException(400, "Arquivo não é uma imagem válida.")
    if img.format not in ("PNG", "JPEG", "WEBP"):
        raise HTTPException(400, "Use PNG, JPG ou WebP.")
    img = ImageOps.fit(img.convert("RGBA"), (256, 256))
    name = f"{uuid4().hex}.webp"                       # nome aleatório: nunca use o nome enviado
    img.save(f"/var/www/logos/{name}", "WEBP", quality=85)
    url = f"https://cdn.seudominio.com/logos/{name}"
    ok = await db.execute("UPDATE times SET logo_url=$1 WHERE id=$2 AND dono_usuario_id=$3",
                          url, team_id, user.id)
    return {"logoPath": url}
```

Em produção prefira um armazenamento de objetos (S3, Cloudflare R2) atrás de um CDN, em vez de disco do servidor.

**Frontend (envio multipart):**

```cpp
void HttpBackendService::uploadLogo(const QString &teamId, const QUrl &file)
{
    auto *mp = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart part;
    part.setHeader(QNetworkRequest::ContentDispositionHeader,
                   R"(form-data; name="file"; filename="logo")");
    auto *f = new QFile(file.toLocalFile(), mp);
    f->open(QIODevice::ReadOnly);
    part.setBodyDevice(f);
    mp->append(part);

    QNetworkRequest req(QUrl(m_base + "/teams/" + teamId + "/logo"));
    req.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());
    QNetworkReply *r = m_net.post(req, mp);
    mp->setParent(r);
    connect(r, &QNetworkReply::finished, this, [this, r, teamId] {
        r->deleteLater();
        if (r->error() == QNetworkReply::NoError) fetchTeams();   // recarrega com a nova URL
    });
}
```

No `saveTeam`, ao receber a resposta do `POST /teams`, você chama `uploadLogo` se `logoPath` ainda for um `file://`.

**Cache:** o QML baixa imagens de URL, mas não guarda em disco por padrão. Para os ícones não serem baixados toda vez, registre um `QNetworkDiskCache` no motor QML. Faça isso depois que o fluxo básico funcionar.

## 7. Ícones de campeões

Os ícones vêm do Data Dragon da Riot (`ddragon.leagueoflegends.com/cdn/<patch>/img/champion/<chave>.png`). Seu campo `icone_url` já guarda isso. O backend devolve a URL em cada campeão e o frontend só preenche o `source` do `ChampionIcon`.

## 8. Ordem de trabalho sugerida

1. Corrigir o SQL (aqueles pontos de antes) e subir o PostgreSQL.
2. Criar a API com `/auth/login` e `/teams` apenas.
3. Escrever o `HttpBackendService` só com esses dois métodos, mantendo o mock para o resto. Dá para misturar enquanto você avança.
4. Adicionar logo, depois análise, depois draft e treino.
5. Por último, a sincronização com a Riot API.

Se quiser, o próximo passo útil é eu escrever o `HttpBackendService` completo, com todos os métodos do contrato. Também posso listar o JSON exato que cada rota deve devolver, tirado dos arquivos mock.


Sim, o frontend se conecta ao backend por API (HTTPS + JSON). Os JSONs locais continuam úteis, mas só para poucos casos.

## 1. API ou JSON local?

**API é o caminho principal**, por quatro motivos:
- Os dados são de várias pessoas e mudam o tempo todo: partidas novas, patches, times editados.
- A chave da Riot e a senha do banco não podem estar dentro de um executável que fica na máquina do usuário.
- As regras (quem é dono do time, mínimo de 2 jogadores) precisam ser validadas no servidor, porque o cliente pode ser adulterado.
- O cálculo pesado (sinergias, win rate por campeão) é feito uma vez no servidor, não em cada PC.

**JSON local ainda serve para:**

| Uso | Exemplo |
|---|---|
| Desenvolvimento e testes | `resources/mock/` (o que já existe) |
| Cache offline | último catálogo de campeões, para abrir o app sem internet |
| Configurações do usuário | time ativo, tamanho da janela, idioma |
| Dados estáticos que quase não mudam | ordem oficial do draft, lista de regiões |

**Não use JSON local** para dados de times, partidas e estatísticas. Eles vêm sempre da API (com cache temporário, se quiser).

## 2. Visão geral: quem faz o quê

```
 [Riot API]──────────┐
 [Data Dragon CDN]───┤
                     ▼
 [Worker de coleta] ──▶ [PostgreSQL] ◀──▶ [API REST] ◀──HTTPS──▶ [Launcher Qt]
   (roda no servidor)    (seu SQL)        (regras + auth)              ▲
                                                                      │ local, só leitura
                                                               [Cliente do LoL (LCU)]
```

São cinco peças:
1. **Banco (PostgreSQL):** guarda tudo. Você já tem o esquema.
2. **API REST:** o único que o launcher enxerga. Autentica, valida e entrega JSON.
3. **Worker de coleta:** processo separado que busca partidas na Riot e alimenta o banco.
4. **Launcher (Qt):** o que já foi feito. Só mostra e envia ações.
5. **Ponte LCU:** código local no launcher que lê o cliente do LoL durante o draft.

## 3. O que acontece em cada fluxo

**Login**
1. O usuário digita e-mail e senha → `POST /auth/login`.
2. A API confere o hash da senha e devolve `accessToken` (curto) e `refreshToken`.
3. O launcher guarda os tokens no cofre do Windows e manda `Authorization: Bearer ...` nas próximas chamadas.
4. Em seguida o launcher chama `GET /teams` para montar o app.

**Criar time:** o launcher valida o formulário e chama `POST /teams`. A API valida de novo, grava em `times` e `time_membros`, resolve cada nick#tag em PUUID pela Riot API (`account-v1`) e devolve o time. Depois vem o upload do logo (`POST /teams/{id}/logo`).

**Ver a análise do time:** `GET /teams/{id}/analysis`. A API **não calcula na hora**: lê tabelas já agregadas e devolve o JSON no formato do `analysis.json`.

**Draft ao vivo:**
1. A ponte LCU lê a seleção de campeões no cliente (local, sem internet).
2. A cada mudança, o launcher manda `POST /teams/{id}/draft/analyze` com os picks e bans, junto com o `seq`.
3. A API devolve tipo de composição, sugestões e insights em menos de 1 s.

**Fim de partida:** a ponte LCU avisa → o launcher chama `POST /teams/{id}/sync` → o worker busca a partida nova na Riot, grava no banco e atualiza as agregações.

## 4. Como os dados chegam ao banco (a parte mais trabalhosa)

1. **Resolver jogadores:** `account-v1` (nick#tag → PUUID), depois `summoner-v4` e `league-v4` para nível e elo.
2. **Listar partidas:** `match-v5` traz os IDs por PUUID, filtrando por fila.
3. **Detalhar cada partida:** `match-v5` para kills, ouro, dano, visão e objetivos. Para `gd_15` e `csd_15` você precisa da **timeline** da partida (`match-v5` timeline).
4. **Gravar** em `partidas`, `partida_participantes` e `partida_time_resumo`.
5. **Agregar:** jobs calculam win rate de duplas/trios, matchups, recordes e comebacks, e gravam em tabelas de resumo.
6. **Respeitar limites:** a chave de desenvolvimento permite cerca de 20 requisições por segundo e 100 a cada 2 minutos. Por isso precisa de **fila com controle de ritmo e novas tentativas**.

Dois pontos de política da Riot a verificar antes de investir muito:
- Para produção você precisa **registrar o produto** no portal de desenvolvedores e pedir uma chave de produção.
- O **login com Riot (RSO)** exige aprovação deles. Comece só com e-mail e senha e vincule a conta pelo nick#tag.

## 5. Etapas de construção, em ordem

| # | Etapa | Onde se faz | Resultado |
|---|---|---|---|
| 0 | Registrar o app no portal da Riot e pegar a chave | developer.riotgames.com | Chave de desenvolvimento |
| 1 | Corrigir o SQL e subir o PostgreSQL | Servidor ou Docker local | Banco pronto |
| 2 | Criar a API com `/auth/login` e `/teams` | Projeto de backend novo (Python, Node ou C#) | Login e times reais |
| 3 | Escrever o `HttpBackendService` só para esses endpoints | `src/services/` do launcher | Launcher falando com a API |
| 4 | Upload de logo | API e launcher | Logos reais |
| 5 | Worker de coleta de partidas | Backend (processo separado) | Banco com histórico |
| 6 | Agregações e `/analysis` | Backend | Telas de Análise com dados reais |
| 7 | Catálogo de campeões, tags e ícones | Backend + Data Dragon | `/draft/catalog` |
| 8 | Motor de composição e `/draft/analyze` | Backend | Draft inteligente real |
| 9 | Ponte LCU real | Launcher (C++) | Draft ao vivo |
| 10 | Diagnósticos e metas de treino | Backend | Telas de Treino reais |
| 11 | Instalador, atualização automática e assinatura de código | Launcher | App distribuível |
| 12 | Hospedagem, HTTPS, backups, monitoramento | Servidor | Produção |

**Dica:** faça as etapas 1 a 3 primeiro e mantenha o mock no resto. O launcher funciona misturado, parte real e parte simulada, e você vê progresso desde o início.

## 6. O que você precisa ter

- **Conhecimento:** uma linguagem de backend, SQL, noções de HTTP e JWT. O C++ do launcher você só mexe na classe de rede.
- **Contas e acessos:** conta de desenvolvedor Riot, um servidor (VPS ou nuvem), domínio com certificado HTTPS.
- **Ferramentas:** PostgreSQL, um gerenciador de migrações (Alembic, Flyway ou similar), Postman ou Insomnia para testar a API.
- **Segurança básica:** senhas com Argon2 ou bcrypt, chave da Riot em variável de ambiente, rate limit no login, backup diário do banco.
- **Custo inicial:** uma VPS pequena já basta para começar.

## 7. Onde fica cada tipo de código

| Lugar | O que vai lá |
|---|---|
| `E:\VsCode\Lider` (o que você tem) | Telas, controllers, `HttpBackendService`, ponte LCU |
| Projeto novo `lider-api` | Rotas, autenticação, regras, consultas SQL |
| Projeto novo `lider-worker` (ou pasta dentro da API) | Coleta da Riot, agregações, jobs agendados |
| Repositório `lider-db` (ou pasta de migrações) | Scripts SQL versionados |

Posso detalhar a etapa 2 agora: estrutura de pastas da API, rotas de login e times, e o JSON exato de cada resposta. Para isso preciso saber qual linguagem de backend você prefere (Python, Node ou C#).

Vou montar a API de verdade e testá-la contra um PostgreSQL real aqui, em vez de só descrever o código.

O `mkdir` com chaves não funciona neste shell e a pasta não foi criada. Recrio as pastas e reenvio os arquivos.

Os 7 testes passaram contra PostgreSQL real. Agora um teste de fumaça com o servidor de verdade (uvicorn + `.env` + migração), como você vai rodar.

Servidor funcionando de ponta a ponta. Escrevo o README e empacoto.

O README não foi gravado (o comando anterior foi interrompido). Gravo de novo e regenero o zip.

A etapa 2 está pronta e testada: a API de login e times está no `lider-api.zip`. Os 7 testes passaram contra um PostgreSQL real e fiz um teste de fumaça com o servidor rodando (cadastro, vínculo da conta, criação e listagem de time). Não testei no Windows nem no seu Docker. O modo `real` da Riot API também não foi testado, porque eu não tenho chave.

## Python ou Node?

Escolhi só **Python** (FastAPI), por três motivos:
- As etapas seguintes (coleta de partidas, agregações, motor de composição do draft) são trabalho de dados, onde o Python é mais forte.
- Com uma linguagem só, você mantém um ambiente e um deploy em vez de dois.
- O Node só compensaria se você precisasse de conexões em tempo real com muitos clientes ou quisesse compartilhar código com um site em TypeScript. Isso não é o caso agora.

## Como rodar

No `cmd` do Windows, dentro da pasta `lider-api` (precisa de Docker Desktop e Python 3.11+):

```bat
docker compose up -d
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python scripts\migrate.py
uvicorn app.main:app --reload
```

Antes do `migrate`, abra o `.env` e troque o `JWT_SECRET` por um valor aleatório (o comando para gerar está no `README.md`). Depois abra http://127.0.0.1:8000/docs, onde dá para testar todas as rotas pelo navegador.

## O que a API faz

- **Rotas:** cadastro, login, renovação de sessão, logout, perfil, vínculo de Nick/Tag/Região, time ativo e CRUD de times (`GET`, `POST`, `PUT`, `DELETE`). A lista completa está no README.
- **Formato de resposta:** igual ao dos JSONs mock do launcher (`{"teams":[...]}`, `{"team":{...}}` e assim por diante). Os erros vêm sempre como `{"message":"..."}`, que é o que o `HttpBackendService` vai ler.
- **Senha e sessão:**
  - A senha é guardada com Argon2id.
  - O token de acesso dura 15 minutos.
  - O token de renovação só vale uma vez e fica no banco apenas como hash.
- **Login:** a mensagem de erro é a mesma para e-mail inexistente e senha errada, e o tempo de resposta também, para não revelar quais e-mails existem.
- **Isolamento entre usuários:** toda consulta de time filtra pelo dono. Um usuário que tenta acessar o time de outro recebe "não encontrado", e isso está coberto por teste.
- **Regras de time validadas no servidor:** mínimo de 2 jogadores distintos, sigla de 2 a 5 letras, duplicados removidos. O primeiro time vira o ativo automaticamente.
- **Banco:** o `migrations/001_init.sql` é o seu esquema corrigido.
  - Corrigi a chave estrangeira invertida entre atletas e usuários.
  - O `lineup_hash` passou para 64 caracteres.
  - Defini `ON DELETE` em todas as chaves e adicionei as restrições e índices que citei antes.
  - Adicionei a tabela `refresh_tokens` e uma coluna `ordem` em `time_membros`, porque o launcher usa a posição do jogador para atribuir a função.

## Pontos para você saber

- **PUUID de mentira em desenvolvimento:** com `RIOT_MODE=fake` (o padrão do `.env.example`), a API gera um PUUID falso a partir de Nick#Tag. Quando você tiver a chave da Riot, mude para `real`. O launcher não precisa saber disso.
- **Logo ignorado por enquanto:** o campo `logoPath` que o launcher envia é descartado de propósito. A URL do logo só será definida pelo endpoint de upload da etapa 4, para o cliente não conseguir gravar qualquer endereço.
- **Limite de 30 jogadores por envio:** é uma proteção técnica contra abuso, porque cada nick#tag vira uma consulta à Riot. A regra de negócio não define máximo.
- **Time ativo no launcher:** hoje o launcher guarda o time ativo só no computador. Para sincronizar com o servidor, o `HttpBackendService` precisa chamar `PUT /me/active-team` quando o usuário trocar de time. Isso entra na etapa 3.
- **O que ainda falta:** limite de tentativas de login (rate limit) e o login com Riot (RSO), que exige aprovação da Riot.
- **Os testes apagam o banco:** eles recriam o banco indicado em `TEST_DATABASE_URL`. Use sempre um banco separado, como `lider_test`.

O próximo passo natural é a etapa 3: escrever o `HttpBackendService` no launcher para esses endpoints, mantendo o mock no resto. Quer que eu faça?


# Etapa 3: conectar o launcher à API

Aqui você vai escrever, no launcher, a classe que fala com a API, sem mexer em nenhuma tela. Descrevo o que fazer, onde e por quê, e você escreve o código (ou peça depois). O que está aqui é um plano que ainda não implementei nem testei.

## 1. O objetivo e o que muda

Hoje o `main.cpp` entrega ao app um `MockBackendService`. Na etapa 3 ele passa a receber um serviço que, para alguns endpoints, fala com a API real e, para o resto, continua usando o mock.

Endpoints que passam a ser reais:
- login e cadastro
- vínculo da conta Riot
- listar, criar, editar e excluir times
- definir o time ativo

Continuam mock por enquanto: análise, jogador, draft, treino e sincronização de histórico, porque ainda não existem no servidor.

## 2. Três lacunas entre o launcher atual e a API

O contrato `IBackendService` foi desenhado antes da API. Três coisas precisam ser acrescentadas:

1. **Cadastro.** A tela de login tem o modo "Cadastrar", mas o contrato só tem login. Falta um método de cadastro, um valor no enum de endpoints e uma função no `AppController` que a tela chame. A API exige senha de 8 ou mais caracteres, então ajuste o texto de dica da tela, que hoje diz "4+".
2. **Time ativo.** Hoje o launcher guarda o time ativo só em `QSettings`. Falta um método no contrato que chame `PUT /me/active-team`. Decida quem manda: recomendo o servidor como fonte da verdade, usando `QSettings` apenas como cache.
3. **Sessão expirada.** Falta um sinal no contrato, algo como `sessionExpired`, para a API avisar que o login acabou. O `AppController` ouve esse sinal e faz logout com uma mensagem clara.

## 3. Arquitetura: um roteador entre dois serviços

Crie duas classes novas em `src/services/`:

- **`HttpBackendService`**: implementa `IBackendService` e só conhece rede, tokens e tradução de respostas.
- **`RoutedBackendService`**: também implementa `IBackendService`, recebe os dois serviços (real e mock) e tem uma tabela "endpoint → qual serviço atende". Ela repassa as chamadas e reemite os sinais de ambos.

Essa divisão é melhor do que fazer o serviço HTTP chamar o mock por dentro. Conforme você implementa endpoints no servidor, basta mudar uma linha da tabela. No final, o mock e o roteador saem e nada mais muda.

No `main.cpp`, escolha o serviço por uma variável de ambiente com a URL da API (por exemplo `LIDER_API_URL`). Se ela existir, usa o roteador. Se não, usa só o mock, e você continua podendo demonstrar o app sem servidor.

No `CMakeLists.txt`, adicione o módulo `Network` do Qt e os dois novos arquivos.

## 4. O que o `HttpBackendService` precisa fazer

**Montar requisições.** URL base mais caminho, cabeçalho `Authorization: Bearer ...` quando houver token, corpo JSON apenas nas rotas que têm corpo, e timeout (10 segundos é razoável). Uma função central de envio atende todos os métodos; cada método do contrato vira uma linha que diz verbo, caminho e corpo.

**Mapear cada chamada:**

| Método do contrato | Verbo e rota | Observação |
|---|---|---|
| login | `POST /auth/login` | Guarda os tokens; não repasse tokens para a UI |
| cadastro | `POST /auth/register` | Mesma resposta do login |
| vincular conta | `PUT /me/riot-account` | Resposta já traz `profile` e `needsLink` |
| listar times | `GET /teams` | Formato igual ao mock |
| salvar time | `POST /teams` se o `id` estiver vazio, senão `PUT /teams/{id}` | Resposta `{team}` |
| excluir time | `DELETE /teams/{id}` | |
| time ativo | `PUT /me/active-team` | Novo método |

**Ler respostas.** Num erro 4xx a biblioteca de rede acusa erro, mas o corpo ainda chega. Leia o campo `message` do JSON e emita como mensagem de falha. Se não houver corpo (servidor fora do ar, timeout), emita uma mensagem em português como "Sem conexão com o servidor". Em sucesso, converta o JSON em mapa e emita junto com o endpoint.

**Cuidar dos tokens.** É a parte mais delicada:
- **Token de acesso**: fica só em memória.
- **Token de renovação**: deve ir para o cofre do sistema (no Windows, o Gerenciador de Credenciais, usando a biblioteca QtKeychain). Não use `QSettings` para isso, porque grava em texto legível.
- **Renovação automática**: quando uma chamada voltar 401 e não for de login, renove uma vez e repita a chamada original. Se a renovação falhar, emita `sessionExpired`.
- **Uma renovação por vez**: o token de renovação da API só vale uma vez. Se duas chamadas receberem 401 ao mesmo tempo e cada uma pedir renovação, a segunda falha e derruba a sessão sem motivo. Mantenha um marcador "renovação em andamento" e coloque as demais chamadas numa fila até ela terminar.
- **Logout**: chame `POST /auth/logout`, apague o token guardado, limpe o token em memória e descarte respostas que cheguem depois.

**Abrir o app já logado.** Na inicialização, se existir token de renovação guardado, tente renovar, depois busque o perfil (`GET /me`) e os times. Isso exige uma função de "restaurar sessão" no `AppController`, chamada ao abrir o app.

## 5. Detalhes que costumam dar problema

- **IDs são texto.** A API devolve `id` de time como string; o launcher já trata assim.
- **Resposta sem corpo.** O logout responde 204. Não tente ler JSON dali.
- **Tokens na resposta de login.** Remova os campos de token do mapa antes de emitir o sinal, para não circularem pelo QML.
- **Liberar respostas.** Cada resposta de rede precisa ser liberada ao terminar, senão há vazamento de memória.
- **HTTP versus HTTPS.** Em `127.0.0.1` durante o desenvolvimento, HTTP puro é aceitável. Em produção, só HTTPS. No Windows o Qt usa o Schannel do sistema, então normalmente não precisa instalar OpenSSL.
- **Logo.** O launcher ainda envia o caminho local do arquivo no campo `logoPath`. A API ignora esse campo de propósito, então o logo só funciona de verdade na etapa 4.
- **Dados mistos.** Enquanto análise e draft forem mock, o elenco mostrado no painel do time (PlayerOne a PlayerFive) não bate com o time real que você cadastrou. É esperado nessa fase.

## 6. Ordem de trabalho com pontos de verificação

1. **Preparação:** suba a API e confirme `/docs` no navegador. Faça login pelo próprio `/docs` para ver o formato real das respostas.
2. **Contrato:** acrescente cadastro, time ativo e `sessionExpired`; implemente nos dois serviços (no mock, o cadastro pode só imitar sucesso). O app deve compilar e rodar igual a antes.
3. **`HttpBackendService` só com login:** ligue pelo roteador só esse endpoint. Verificação: login com usuário real funciona, senha errada mostra a mensagem da API, e com o servidor desligado aparece "Sem conexão".
4. **Vínculo de conta e times:** liste, crie, edite e exclua. Verificação: criar time com 1 jogador mostra a mensagem de erro vinda do servidor; fechar e reabrir o app mostra os mesmos times.
5. **Tokens e sessão:** guarde o token de renovação, renove automaticamente, restaure sessão ao abrir. Para testar sem esperar 15 minutos, suba a API com o tempo do token de acesso em 1 minuto.
6. **Testes de borda:** use duas contas e confirme que uma não vê o time da outra; reutilize um token de renovação antigo e veja o logout forçado; derrube o servidor no meio de uma ação.

## 7. O que testar manualmente no final

- Cadastro de e-mail novo leva ao passo de vincular Nick/Tag/Região.
- E-mail repetido mostra "E-mail já cadastrado."
- Primeiro time criado já vira o ativo.
- Trocar o time ativo, fechar e reabrir o app mantém a escolha.
- Excluir o time ativo não deixa o app quebrado.

Quando terminar essa etapa, a etapa 4 é o upload de logo, que mexe nos dois lados. Se quiser, na próxima mensagem detalho o contrato novo (assinaturas e enum) em prosa, ou revisamos juntos o que você escrever quando travar em algum ponto.


# Etapa 4: logo do time (upload de imagem)

Seguindo o mesmo formato da etapa 3, descrevo o plano em prosa. Nada disto foi implementado ou testado ainda.

## 1. Como está hoje

- No launcher, o diálogo de time já deixa escolher a imagem e valida o formato (PNG, JPG ou WebP) e o limite de 2 MB. A imagem escolhida só aparece como pré-visualização local, usando o caminho do arquivo no seu computador.
- Na API, o campo `logoPath` enviado pelo launcher é **ignorado de propósito**. A coluna `logo_url` do time fica sempre vazia.

A etapa 4 liga as duas pontas: o arquivo sobe para o servidor, o servidor o trata e devolve um endereço público, e o launcher passa a exibir esse endereço.

## 2. O fluxo completo

1. O usuário escolhe a imagem e clica em Salvar.
2. O launcher envia primeiro os dados do time (criar ou editar), como já faz.
3. A API responde com o time salvo, incluindo o `id`.
4. Se havia uma imagem nova pendente, o launcher a envia numa segunda chamada própria para aquele time.
5. A API valida de verdade, redimensiona, grava o arquivo, atualiza o time e devolve o endereço.
6. O launcher recarrega a lista de times e a tela mostra o logo.

O upload vem depois do salvamento porque, ao criar um time, o `id` só existe depois que a API responde. Também mantém as duas operações simples: uma só de dados e outra só de arquivo.

## 3. Lado do servidor

### 3.1 A rota
Dois endpoints novos:
- enviar logo: `POST /teams/{id}/logo`, corpo no formato de formulário com arquivo (multipart);
- remover logo: `DELETE /teams/{id}/logo`. É opcional, mas útil se você quiser um botão "remover".

Ambos exigem login e conferem que o time pertence ao usuário, igual às demais rotas de time. A biblioteca de multipart já está no `requirements.txt`.

### 3.2 Regra de ouro: não confie em nada que veio do cliente
A validação do launcher é só conveniência; um atacante pode chamar a API direto. Por isso o servidor refaz tudo:

- **Tamanho:** limite de 2 MB conferido durante a leitura, não depois de carregar tudo na memória. Rejeite cedo pelo cabeçalho de tamanho e pare de ler ao passar do limite.
- **Tipo real:** não confie na extensão nem no tipo declarado. Abra o arquivo com a biblioteca de imagens (Pillow) e confira o formato que ela detecta. Aceite só PNG, JPEG e WebP. **Recuse SVG** e GIF animado: SVG pode carregar script e é vetor clássico de ataque.
- **Imagens "bomba":** um arquivo pequeno pode declarar dimensões gigantes e esgotar a memória ao ser decodificado. Defina um limite de pixels (por exemplo 4000 × 4000) e deixe o Pillow recusar acima disso. Rejeite também resolução absurdamente pequena (por exemplo menos de 64 px de lado).
- **Abrir duas vezes:** a verificação de integridade do Pillow consome a imagem. É preciso verificar e depois reabrir para processar.
- **Orientação:** fotos de celular trazem uma marca de rotação nos metadados. Aplique a rotação antes de descartar os metadados, senão o logo sai deitado.

### 3.3 Tratamento da imagem
Em vez de guardar o arquivo original, **recodifique**: isso remove metadados (localização GPS, nome da câmera) e qualquer conteúdo escondido no arquivo. Decisões que você precisa tomar:

- **Tamanho final:** 256 × 256 é suficiente para logos de interface. Se quiser telas de alta densidade, 512.
- **Corte ou preenchimento:** cortar o centro garante um quadrado cheio, mas pode cortar parte do escudo do time. Preencher mantendo as proporções, com fundo transparente, preserva a imagem inteira. Recomendo **preencher**, porque logos de times costumam ter texto nas bordas.
- **Formato de saída:** WebP é leve e mantém transparência; é a escolha natural aqui.
- **Animações:** pegue só o primeiro quadro.

### 3.4 Onde guardar o arquivo
Três opções, em ordem de complexidade:

| Opção | Quando usar | Observação |
|---|---|---|
| Pasta no servidor | Desenvolvimento e primeiros testes | Servida pela própria API; perde-se tudo se o servidor for recriado |
| Armazenamento de objetos (S3, Cloudflare R2 etc.) | Produção | Barato, durável, escala |
| Armazenamento + CDN | Produção com muitos usuários | Imagens chegam mais rápido |

Mesmo começando com a pasta local, **separe a lógica de gravação em uma peça só** (um "armazenamento" com operações salvar e apagar). Assim, trocar a pasta por S3 depois muda um lugar e não as rotas.

### 3.5 Como nomear e servir
- Gere um nome aleatório a cada envio (por exemplo um identificador aleatório com a extensão `.webp`). Nunca use o nome que veio do cliente: isso evita sobrescrever arquivos de outros e ataques de caminho.
- Como o nome muda a cada upload, o endereço também muda. Isso resolve de graça o problema de a imagem antiga ficar no cache do launcher.
- Como o conteúdo de um nome nunca muda, você pode servir com cache longo e marcado como imutável.
- **Guarde no banco o caminho relativo**, não o endereço completo, e componha o endereço a partir de uma configuração (`LOGO_BASE_URL`). Se um dia você trocar de CDN ou de domínio, não precisa alterar os dados.
- A coluna `logo_url` tem 500 caracteres, o que sobra.

### 3.6 Limpeza
- Ao trocar o logo, apague o arquivo antigo (depois de gravar o novo e atualizar o banco, nessa ordem, para nunca ficar sem logo se algo falhar no meio).
- Ao excluir um time, apague o arquivo também. O banco já remove as linhas em cascata, mas o arquivo está fora do banco e precisa de remoção explícita.
- Se um processo falhar no meio e deixar arquivos órfãos, uma rotina periódica que compara arquivos e banco resolve. Não precisa existir agora.

### 3.7 Limites e infraestrutura
- Limite de tentativas: uploads são caros. Defina um teto por usuário (por exemplo 10 por hora).
- **Proxy reverso:** se colocar Nginx ou similar na frente, ele tem um limite padrão de corpo de requisição (1 MB no Nginx) que vai recusar seus 2 MB antes de a API ver. Ajuste esse limite.
- Em produção, as imagens devem sair por HTTPS e de um endereço público; o launcher só precisa conseguir abri-las.

## 4. Lado do launcher

### 4.1 Mudanças no contrato
- Um novo endpoint no enum e um método de enviar logo, que recebe o `id` do time e o arquivo.
- O mock implementa esse método como "sucesso sem fazer nada", para o app continuar rodando sem servidor.

### 4.2 Onde mora a lógica
Recomendo que o **serviço de rede** cuide do encadeamento "salvar time → enviar logo". Ele recebe o time com o arquivo pendente, guarda esse arquivo enquanto espera a resposta do salvamento e, ao receber o `id`, dispara o envio. Assim a interface e o `AppController` não precisam saber que são duas chamadas.

### 4.3 Qual caminho é novo e qual já existe
O campo do logo pode conter:
- um caminho local (`file://...`): é uma imagem recém-escolhida, **precisa enviar**;
- um endereço da internet (`https://...`): é o logo que já está no servidor, **não reenvie**.

Ao editar um time sem trocar o logo, o launcher manda o endereço antigo; o serviço deve reconhecer que não há nada para subir. Sem essa distinção, cada edição reenviaria a imagem.

### 4.4 O envio em si
- A requisição é multipart, com um único campo de arquivo.
- O objeto que representa o arquivo precisa viver até o envio terminar, então amarre o tempo de vida dele à resposta de rede. É um erro comum e causa travamento ou envio vazio.
- Defina timeout maior que o das demais chamadas, porque o envio é mais lento.
- Envie o mesmo cabeçalho de autenticação, e a renovação automática de token da etapa 3 deve valer para esta chamada também. Cuidado: ao repetir a requisição depois de renovar o token, é preciso reabrir o arquivo, porque o fluxo anterior já foi consumido.

### 4.5 Mostrar o resultado
- Depois do sucesso, recarregue a lista de times. Como o endereço do logo mudou, os componentes que o exibem atualizam sozinhos.
- Os componentes de avatar já aceitam endereços da internet, então **não precisam de mudança**. Eles decodificam a imagem já reduzida, o que economiza memória.
- **Cache em disco:** por padrão o Qt baixa a imagem de novo a cada abertura do app. Para evitar isso, registre um cache em disco na rede do QML. Faça isso só depois de tudo funcionando.
- Mantenha a pré-visualização local no diálogo enquanto o envio acontece.

### 4.6 Falhas parciais
O ponto mais fácil de esquecer: o time pode ser **salvo com sucesso e o logo falhar** (arquivo recusado, queda de rede). Nesse caso:
- não desfaça o time;
- mostre uma mensagem específica, como "Time salvo, mas o logo não pôde ser enviado: motivo";
- deixe o usuário tentar de novo editando o time.

## 5. Ordem de trabalho com pontos de verificação

1. **Servidor, só a rota e o armazenamento local.** Teste pelo `/docs`: envie uma imagem boa e confira que o endereço é devolvido e que abre no navegador.
2. **Validações.** Teste com: arquivo de texto renomeado para `.png`, imagem acima de 2 MB, SVG, imagem corrompida, imagem enorme em pixels. Todos devem voltar com mensagem clara em português.
3. **Segurança.** Com duas contas, tente enviar logo para o time da outra: deve dar "não encontrado". Chame sem login: deve dar 401.
4. **Troca e exclusão.** Envie um segundo logo e confira que o arquivo antigo sumiu. Exclua o time e confira que o arquivo também sumiu.
5. **Testes automatizados** para todos os casos acima, no mesmo estilo dos existentes.
6. **Contrato e serviço de rede no launcher**, primeiro com um caminho fixo de teste.
7. **Fluxo completo na interface:** criar time com logo, editar sem trocar o logo (não deve reenviar), trocar o logo, falha forçada.
8. **Cache e acabamento.**

## 6. O que testar manualmente no final

- Criar time com logo e ver o logo na lista e no cabeçalho do painel.
- Fechar e reabrir o app: o logo continua lá.
- Editar o nome sem mexer no logo: nada é reenviado.
- Escolher um arquivo de 5 MB: a mensagem aparece (no launcher, e no servidor se você burlar a checagem).
- Derrubar o servidor durante o envio: mensagem de falha clara, time preservado.

## 7. Decisões que dependem de você

1. **Onde guardar os arquivos no começo:** pasta local ou direto um serviço de armazenamento na nuvem?
2. **Corte ou preenchimento** do logo (minha recomendação: preenchimento).
3. **Tamanho final:** 256 ou 512.
4. **Botão de remover logo** entra nesta etapa ou fica para depois?

Respondendo essas quatro, a etapa fica fechada. Depois dela vem a etapa 5, o coletor de partidas, que é a maior de todas: ela fala com a API da Riot e alimenta o banco.

Antes de descrever, vou conferir na documentação da Riot os pontos que costumam mudar: limites de requisição, regras de chave de produção e endpoints atuais.

Registro: a etapa 4 está fechada com armazenamento local, preenchimento, 512 px e o botão de remover logo fica para depois.

# Etapa 5: coletor de partidas (worker)

É a maior etapa do projeto. Ela puxa as partidas da Riot e alimenta o banco que as telas de Análise, Draft e Treino vão ler. Tudo abaixo é plano em prosa, sem código, e nada foi implementado ou testado. Os dados da Riot que cito vieram de consulta à documentação oficial agora; confirme no portal antes de decidir algo caro.

## 1. Antes de escrever código: a política da Riot

Pesquisei porque esta etapa pode mudar o que o seu produto pode ter.

**Chaves e limites**
- A chave de desenvolvimento desativa a cada 24 horas, e um produto aberto ao público, mesmo em alfa ou beta, não pode rodar com chave pessoal.
- Chaves pessoais e de desenvolvimento permitem 20 requisições por segundo e 100 a cada 2 minutos, e os limites valem por região.
- A chave de produção começa em 500 requisições a cada 10 segundos e 30.000 a cada 10 minutos, e geralmente exige um protótipo funcional.
- Além do limite geral, cada método da API tem limite próprio, e o cliente deve respeitar o cabeçalho Retry-After quando receber erro 429.
- A chave não pode ficar no código de um binário distribuído, e o acesso deve ser por HTTPS. Isso confirma que a chave fica só no servidor.

**Registro e obrigações**
- Todo produto precisa ser registrado e auditado no Developer Portal, e mudanças de funcionalidade também passam por auditoria.
- Também é exigido um acesso gratuito para os jogadores.
- Há um aviso legal que precisa ficar visível no produto. O launcher ainda não tem esse texto. Você precisa copiar o texto oficial da política e colocá-lo em um rodapé ou tela "Sobre".
- O uso de logos da Riot é restrito aos casos inevitáveis. Os mockups usam o "L" da Riot como avatar; prefira um ícone próprio.
- Mostre o Riot ID (nick#tag), não o antigo nome de invocador.
- Partidas personalizadas não podem ser exibidas publicamente sem o jogador optar. Como o seu escopo é ranqueada, basta nunca ingerir essa fila.

**O que pode conflitar com o seu design**
- Entre os usos aprovados estão ferramentas de treino em que o jogador vê o próprio histórico e estatísticas agregadas. O seu launcher de análise de equipe se encaixa bem nisso.
- Porém produtos não podem usar informação ausente do cliente do jogo que dê vantagem competitiva, e aplicativos que ditam decisões do jogador não são aprovados. O produto pode destacar decisões e oferecer várias opções, mas não deve remover a decisão do jogador. Ele também deve ampliar, e não reduzir, a diversidade de decisões, como composições e campeões.
- Uma página da Riot sobre outro jogo (2XKO) lista como não aprovados a agregação de win rate em grande volume de partidas e níveis de habilidade, o "scouting" e a agregação de estatísticas de ranqueada. Não sei se isso vale igual para o LoL, e a Riot decide caso a caso.

Na prática, isso pesa sobre duas partes do seu desenho:
1. **Sugestões de campeões com win rate global**, como o "Rell 72,4%" do mockup. Isso exige agregar dados de muita gente e pode ser lido como "dizer o que jogar". Uma alternativa mais segura é basear as sugestões só no histórico do próprio time e em características estáticas dos campeões, mostrando várias opções.
2. **Dados de adversários.** O esquema guarda o PUUID de quem joga contra o time, para calcular matchups. Guarde isso, mas nunca exiba a identidade de adversários na interface; mostre apenas o campeão e as diferenças de ouro e farm.

**Ação antes de investir semanas:** registre o produto no portal agora, descreva-o como ferramenta de treino e análise do histórico da própria equipe, e pergunte à Riot, pela mensagem do portal, se as sugestões do draft são aceitáveis. Em paralelo, verifique você mesmo as páginas de política, porque minhas buscas retornaram trechos fragmentados.

Tratamento de dados pessoais (nick, PUUID e histórico de pessoas que talvez nem usem o app) também entra na LGPD. Isso exige política de privacidade e forma de exclusão de dados. Vale conversar com um advogado.

## 2. O que o coletor faz

Um processo separado, rodando o tempo todo no servidor, que repete este ciclo:

1. Recebe um pedido ("atualizar o time X"), vindo de três origens: criação do time (carga inicial), botão ou fim de partida no launcher, e agendamento periódico.
2. Descobre quais partidas novas existem para cada jogador do time.
3. Baixa os detalhes de cada partida nova, e a linha do tempo só quando ela for necessária.
4. Grava tudo no banco, de forma que repetir o processo nunca duplique dados.
5. Recalcula os resumos do time (win rate por conjunto, campeões, recordes etc.).
6. Marca o time como sincronizado.

Rode-o **separado da API web**. Se a API reiniciar por uma atualização, as sincronizações em andamento não podem morrer junto.

## 3. As peças

**Fila de tarefas no próprio PostgreSQL.** Uma tabela de tarefas (tipo, time, estado, tentativas, próxima tentativa). O worker pega uma tarefa por vez com bloqueio que impede dois workers de pegarem a mesma. Não precisa de Redis nem RabbitMQ no começo.

**Limitador de requisições.** É o centro do worker. Todas as chamadas à Riot passam por ele. Regras:
- Controla as duas janelas ao mesmo tempo (a curta e a longa).
- Mantém contadores separados por região.
- Reage ao 429 esperando pelo tempo que a Riot indicar.
- Pode usar os cabeçalhos de resposta de limite para se ajustar (confirme os nomes exatos na documentação).

Com **um único processo**, o limitador pode ficar na memória. Com vários processos, ele precisa de um estado compartilhado. Comece com um só.

**Cliente da Riot.** Uma camada fina que sabe rotear (cada região do jogo tem um cluster regional para partidas) e traduz respostas e erros. As chamadas que você vai usar:
- obter a conta por nick#tag e por PUUID;
- listar IDs de partidas por PUUID, com filtros de fila e período, e até 100 por página;
- obter uma partida;
- obter a linha do tempo da partida;
- obter nível e ícone do jogador;
- obter as ligas (elo) por PUUID.

**Processadores** (transformam respostas da Riot em linhas do banco), **agregadores** (recalculam resumos) e um **agendador** simples (um laço que enfileira times com sincronização atrasada).

## 4. O caminho de um time, passo a passo

1. **Jogadores do time.** Para cada membro, lê o PUUID e a "marca d'água" (data da última sincronização).
2. **Listar IDs novos.** Pede a lista de partidas filtrada pela fila e pelo período desde a marca d'água, página por página, até acabar. Na primeira vez, defina até onde voltar (ver decisões, seção 11).
3. **Descartar o que já existe.** Compara os IDs com a tabela de partidas; só o que for novo segue. Como os membros jogam juntos, a mesma partida aparece várias vezes. Junte os IDs de todos os membros antes de baixar, para baixar cada partida uma vez só.
4. **Baixar a partida** e decidir se ela interessa: guardar as de qualquer membro (para estatísticas individuais "solo versus equipe") e marcar as em que dois ou mais membros jogaram no mesmo lado (as que valem para o time).
5. **Baixar a linha do tempo** só para as partidas em que ela é necessária.
6. **Gravar em uma transação única:** a partida, os 10 participantes, o resumo do time, o conjunto de jogadores. Qualquer falha desfaz tudo daquela partida.
7. **Atualizar a marca d'água** do membro só depois de gravar.

## 5. Como se calculam os dados derivados

- **Patch:** vem da versão do jogo na partida (os dois primeiros números).
- **Função (rota):** a partida já informa a posição de cada participante; use-a, e aceite que em casos raros ela vem errada ou vazia.
- **Diferença de ouro e de farm aos 15 minutos:** a linha do tempo traz um quadro por minuto com ouro total e farm de cada jogador. Pega o quadro do minuto 15 e compara cada jogador com o seu adversário direto de rota. Se a partida terminou antes de 15 minutos, grava vazio, não zero.
- **Tempos de objetivos:** saem dos eventos da linha do tempo (primeira torre, primeiro dragão, primeiro barão, arauto), com o horário de cada um.
- **Contagem de objetivos e do controle de objetivos (71% da tela):** vêm do resumo por equipe da partida. É preciso definir a fórmula (por exemplo, objetivos do time divididos pelo total de objetivos da partida).
- **Maior vantagem e maior desvantagem de ouro:** soma o ouro de cada lado em cada minuto e guarda o maior valor a favor e o maior contra.
- **Throw e comeback:** são definições suas, por exemplo "derrota depois de ter liderado por mais de 3.000 de ouro" e "vitória depois de ter perdido por mais de 3.000". Deixe os limites em configuração, para ajustar sem refazer o banco.
- **Tipo da composição:** soma as características dos campeões do time (Dive, Poke etc.). Isso depende da tabela de características dos campeões, que você precisa montar à mão; ela é o tema da etapa 7.
- **Duos, trios e quartetos:** gerados a partir dos membros do time presentes em cada partida (todas as combinações de 2 a 5). Lembre da tabela de membros por partida que eu sugeri na revisão do SQL.

## 6. Mudanças no banco (migração 002)

O esquema atual não cobre tudo que as telas mostram. Falta:
- contagens de objetivos por equipe (dragões, barões, arautos, torres) e os tempos de arauto e vastilarvas;
- bans por partida (para o draft);
- membros do time por partida (para os conjuntos de jogadores);
- marca d'água por jogador e por time, com estado da última sincronização;
- tabela de tarefas;
- tabelas de resumo prontas para as telas (por conjunto de jogadores, por campeão, recordes, por matchup).

Além disso:
- **Guardar o JSON bruto da partida** em uma tabela separada pode valer a pena, porque se você mudar uma fórmula, reprocessa sem refazer milhares de chamadas à Riot. Cobra espaço em disco; decida pelo seu volume.
- Cuidado com a política de dados da Riot ao decidir por quanto tempo guardar o bruto.

## 7. O que dá errado, e como o worker reage

| Situação | Reação |
|---|---|
| 429 (limite) | Espera o tempo indicado, sem contar como falha |
| 5xx ou queda de rede | Tenta de novo com espera crescente e aleatória, com teto de tentativas |
| 404 em partida | Marca como inexistente e segue |
| 401/403 (chave inválida ou expirada) | Pausa tudo e avisa você; não tente em loop |
| JSON com formato inesperado | Registra a partida problemática e segue com as demais |
| Processo interrompido no meio | Tarefa volta à fila; como a gravação é idempotente, repetir é seguro |

Pontos de projeto que valem ouro:
- Cada gravação tem que ser **idempotente**: rodar duas vezes dá o mesmo resultado.
- A marca d'água só avança depois de gravar.
- Mude o nick#tag de um jogador? O PUUID não muda. Atualize periodicamente nick e tag a partir do PUUID, e use sempre o PUUID como identidade.

## 8. Ligação com a API e o launcher

- **Disparo:** a rota de sincronização do time apenas **cria a tarefa** e responde na hora com "aceito". Quem trabalha é o worker.
- **Progresso:** acrescente uma rota para consultar o estado ("na fila", "processando 40 de 120", "concluído", "erro"). O launcher mostra isso em vez de um simples aviso.
- **Proteções:** não aceite nova sincronização do mesmo time enquanto há uma em andamento, e imponha um intervalo mínimo (por exemplo 5 minutos) entre pedidos manuais.
- **Carga inicial:** disparada ao criar o time, em segundo plano. As telas devem mostrar "coletando dados" até haver o suficiente.
- **Um exemplo de custo:** um time de 5 jogadores com 100 partidas cada e muitas partidas em comum gera algo como 600 chamadas (detalhe mais linha do tempo). Na chave pessoal, com 100 requisições a cada 2 minutos, isso leva por volta de 12 minutos. Planeje a interface para esperas assim.

## 9. Estrutura e execução

- Pasta nova no mesmo repositório da API (por exemplo `worker/`), **reaproveitando** configuração e acesso ao banco da API.
- Módulos: cliente da Riot, limitador, tarefas, processadores, agregadores, agendador.
- Em desenvolvimento, rode em um terminal separado. Em produção, como serviço próprio (contêiner ou serviço do sistema) com reinício automático.
- Registre logs com contadores: tarefas na fila, chamadas por minuto, quantas deram 429, quantas falharam. Isso é o seu painel de saúde.

## 10. Como testar

1. **Respostas gravadas.** Salve de 3 a 5 partidas reais (e suas linhas do tempo) como arquivos e escreva testes dos cálculos em cima delas. Inclua casos estranhos: partida de menos de 15 minutos, jogador que saiu, função vazia.
2. **Servidor falso da Riot.** Um pequeno servidor local que devolve 429, 500 e respostas lentas, para provar que o limitador e as novas tentativas funcionam sem gastar a sua cota.
3. **Teste de idempotência:** processe a mesma partida duas vezes e confirme que o banco não muda.
4. **Teste real e curto:** com a sua própria conta e as últimas 20 partidas, comparando os números com o que você vê no cliente do jogo.

## 11. Ordem de trabalho com verificações

1. Registrar o produto e perguntar sobre as sugestões do draft (seção 1).
2. Migração 002 e tabela de tarefas.
3. Cliente da Riot + limitador, testados contra o servidor falso.
4. Processador de partida (sem linha do tempo) para uma única partida. Verificação: os números batem com o cliente do jogo.
5. Linha do tempo e cálculos derivados.
6. Fluxo do time completo, com marca d'água e idempotência.
7. Agregadores, um por tela (começando pelas Estatísticas).
8. Rotas de sincronização e progresso na API.
9. Agendador e monitoramento.

## 12. Decisões que dependem de você

1. **Filas:** só Solo/Duo e Flex, ou Clash também? (O seu documento diz "ranqueadas".)
2. **Profundidade da carga inicial:** últimas 100 partidas por jogador, ou desde o início da temporada?
3. **Definições de throw e comeback** (os limites de ouro e o minuto de referência).
4. **Região inicial:** apenas o Brasil no começo simplifica bastante o roteamento e os limites.
5. **Adversários:** concorda em guardá-los só para cálculo e nunca mostrar a identidade?
6. **JSON bruto:** guardar, ou descartar depois de processar?

Respondendo isso, fecho a etapa. A etapa 6 é a de agregações e da rota de análise que as telas consomem. Quer que eu comece por ela, ou prefere resolver antes o registro do produto na Riot?

Você não respondeu às decisões da etapa 5, então assumi estes padrões (me corrija se forem outros): filas Solo/Duo e Flex, últimas 100 partidas por jogador na carga inicial, só região BR, adversários guardados mas nunca exibidos. Isso afeta pouco esta etapa. Como nas anteriores, é um plano em prosa, sem código, e nada foi implementado nem testado.

# Etapa 6: agregações e rota de análise

O worker da etapa 5 deixa no banco partidas "cruas". Esta etapa transforma isso nos números que as telas de Análise mostram, e entrega por duas rotas: a análise do time e o perfil de cada jogador.

## 1. O que as telas esperam

O launcher já consome um formato fixo (os arquivos `analysis.json` e `players.json` do mock). A API tem que devolver exatamente essa estrutura:

- **Análise do time:** elenco, aba Geral (conjuntos de jogadores e partidas recentes), aba Estatísticas (indicadores, radar, marcos de objetivos, sinergias, composições, campeões, matchups, comebacks, throws, fechamento) e aba Recordes.
- **Jogador:** KDA, participação em abates, visão por minuto, farm por minuto, pool de campeões e comparação solo versus equipe.

Rotas: `GET /teams/{id}/analysis` e `GET /teams/{id}/players/{puuid}`. O mockup original também tinha um seletor de período (7D, 30D, 90D, 1A) que o launcher ainda não implementa; recomendo planejar o período como parâmetro desde já.

## 2. Decisão central: calcular quando?

| Estratégia | Como funciona | Quando serve |
|---|---|---|
| Na hora | A rota roda as consultas a cada pedido | Poucos dados; simples, mas a tela fica lenta quando crescer |
| **Instantâneo por time (recomendado)** | O worker, ao terminar uma sincronização, calcula tudo e guarda o resultado pronto em JSON | Leitura instantânea; um cálculo por sincronização |
| Tabelas de resumo | Resumos parciais gravados em tabelas e montados na rota | Escala maior, mais trabalho de manutenção |

O volume por time é pequeno (centenas ou milhares de partidas), então recalcular o time inteiro do zero a cada sincronização deve ser rápido. Meça em vez de supor. Guarde uma cópia por período (7 dias, 30 dias, 90 dias, 1 ano, tudo), cada uma com a versão do formato e a data de geração. A rota só lê e devolve.

Vantagens: rota simples, resposta imediata, e o "Última atualização" da tela sai de graça. Limite: não dá para o usuário filtrar de forma arbitrária (por exemplo "só este patch"). Se esse filtro for necessário depois, parte dos cálculos passa a ser feita na hora.

## 3. De onde vem cada número

| Bloco da tela | Fonte | Como calcular | Cuidado |
|---|---|---|---|
| Taxa de vitória | Resumo do time por partida | Vitórias ÷ partidas do período. Variação: compara com o período anterior do mesmo tamanho | Sem período anterior, não mostre variação |
| Ouro por minuto | Participantes | Ouro total dos membros ÷ minutos totais | Prefira a razão das somas à média das médias |
| Objetivos conquistados | Resumo por equipe | Média por partida | Precisa das contagens da migração da etapa 5 |
| Controle de objetivos (71%) | Resumo por equipe | Objetivos do time ÷ objetivos totais da partida | A fórmula é decisão sua |
| KDA coletivo | Participantes | (abates + assistências) ÷ mortes, com as somas do período | Mortes zero: use no mínimo 1 |
| Marcos (torre, dragão, barão…) | Tempos por partida | Mediana dos tempos | Ignore partidas em que o marco não ocorreu; não conte como zero |
| Sinergias de jogadores | Membros por partida | Win rate de cada dupla | Amostra mínima (seção 4) |
| Sinergias de campeões | Participantes | Win rate de cada par de campeões do time | Idem |
| Composições | Tipo de composição | Win rate por tipo | Depende da tabela de tags de campeões (etapa 7) |
| Campeões | Participantes | Win rate por campeão | Amostra mínima |
| Matchups por rota | Participantes | Campeão do time contra o adversário da mesma rota: win rate e médias de diferença de ouro e farm aos 15 min | Média só sobre partidas com linha do tempo; mostre a quantidade |
| Comebacks, throws, fechamento | Maior vantagem/desvantagem de ouro | Pelas definições de limite da etapa 5 | Limites ficam em configuração |
| Recordes | Partidas e participantes | Máximo ou mínimo de cada métrica, com a partida de origem | Desempate definido (por exemplo, o mais recente) |
| Partidas recentes | Resumo do time | Últimas N, com resultado, duração e placar | Só filas aceitas |
| Elenco | Atletas e ligas | Função, elo, win rate e KDA de cada um | O elo precisa de rotina própria de atualização |

**Dois itens do mockup não saem dos dados que você terá:**
- Nos recordes, o mock mostra "contra Sombras FC". A Riot não fornece nome de time em fila ranqueada, então esse texto não existe. Mostre data, campeão e patch.
- O radar normalizado de 0 a 100, e os comparativos "Média do Elo" e "Top 10%" do mockup, precisam de referência global. Isso exige dados de muita gente e esbarra no risco de política que apontei na etapa 5. Opções: normalizar o radar contra o histórico do próprio time, usar referências estáticas que você define, ou adiar os comparativos. Eu adiaria os comparativos.

## 4. Estatística básica que evita erro bobo

- **Amostra mínima.** Uma dupla com 2 vitórias em 2 partidas tem "100%", mas não significa nada. Defina um mínimo (por exemplo 8 a 10 partidas) para entrar em "melhores" e "piores". Abaixo disso, mostre "dados insuficientes".
- **Ordenar com cautela.** Mesmo acima do mínimo, 9 de 10 (90%) não é tão seguro quanto 90 de 100. Uma forma conhecida de lidar com isso é ordenar pelo limite inferior do intervalo de confiança do win rate (o método de Wilson), em vez do win rate puro. A tela continua mostrando o percentual normal; só a ordem muda.
- **Média ou mediana.** Para tempos (primeiro barão, duração), um valor extremo distorce a média. A mediana é mais robusta.
- **Ausente não é zero.** Partida sem linha do tempo ou que acabou antes dos 15 minutos não tem diferença aos 15 minutos. Guarde vazio e deixe de fora das médias.
- **Período anterior.** A variação (+4,2%) exige o mesmo tamanho de janela imediatamente antes. Defina isso explicitamente, e trate fuso horário ao cortar por data.
- **Filas separadas.** Não misture Solo/Duo e Flex em uma média sem decidir isso conscientemente; elas têm perfis diferentes.
- **Patches.** Win rates mudam entre patches. No começo ignore; guarde o patch para poder filtrar depois.

## 5. Como montar as consultas (conceitos)

Você não precisa de nada exótico, só de SQL bem usado:
- **Agrupamento com condição** para contar vitórias e derrotas na mesma passada.
- **Funções de janela** para séries temporais (as miniaturas dos cartões) e para comparar um período com o anterior.
- **Geração de séries de datas** para criar os baldes semanais, inclusive os vazios.
- **Junções** entre resumo do time, membros por partida e participantes, sempre começando pelo filtro do time para não varrer a base inteira.
- **Índices** nos campos de filtro (time, data, campeão, jogador). Confira com o plano de execução (`EXPLAIN ANALYZE`) em vez de adivinhar.
- Evite consultar dentro de laços ("N+1"): uma consulta por bloco, não uma por linha.

## 6. O fluxo de ponta a ponta

1. O worker termina uma sincronização.
2. Enfileira "recalcular análise do time".
3. O cálculo roda, um período por vez, e grava o instantâneo (JSON, versão do formato, data de geração).
4. A rota lê o instantâneo do período pedido e devolve.
5. O launcher mostra, com a data de atualização.

**Time recém-criado:** ainda não há instantâneo. A API deve responder claramente "em preparação", com o progresso da coleta (a rota de status da etapa 5). O launcher hoje não trata esse estado: precisará de uma tela de "coletando dados" e de reconsultar de tempos em tempos.

**Formato do contrato:**
- Inclua um campo com a versão do formato, para poder mudar no futuro.
- Campos novos devem ser opcionais, para não quebrar versões antigas do launcher.
- Valores ausentes viajam como nulos explícitos, e números continuam como números.
- Os tempos do mock são texto ("11:42"). Para não mexer no launcher agora, a API devolve já formatado como o mock. Mais tarde vale migrar para segundos e deixar a tela formatar.

## 7. Segurança e privacidade

- Todas as rotas filtram pelo dono do time, como as demais.
- Nenhuma identidade de adversário aparece no JSON, apenas campeões e métricas.
- A rota do jogador só responde para quem é membro de um time do usuário logado.
- Aplique limite de requisições, porque ela é a rota mais consultada.

## 8. Como testar

1. **Banco de teste com números calculáveis à mão.** Monte partidas fictícias (por exemplo 10 partidas, 6 vitórias) onde você sabe a resposta de cada bloco. Confirme um a um.
2. **Casos de borda:** time sem partidas, com uma só, jogador sem linha do tempo, empate em recorde, período vazio, partida de menos de 15 minutos.
3. **Coerência:** vitórias mais derrotas sempre igual ao total; a soma dos conjuntos bate com o número de partidas do time.
4. **Desempenho:** gere milhares de partidas sintéticas e meça tempo de recálculo e de resposta da rota.
5. **Conferência com a realidade:** pegue um time seu, real, e compare alguns números com o que você vê no cliente do jogo.

## 9. Ordem de trabalho com verificações

1. Fechar as decisões da seção 10 (sem elas, as fórmulas mudam depois).
2. Banco de teste sintético com resultados conhecidos.
3. Bloco mais simples primeiro (indicadores gerais) e comparar com o cálculo manual.
4. Demais blocos, um por vez, cada um com seu teste.
5. Jogador individual.
6. Instantâneo por período e rota de leitura.
7. Estado "em preparação".
8. No launcher: trocar o mock da análise pela API, e depois acrescentar o seletor de período e a tela de espera.

## 10. Decisões que dependem de você

1. **Períodos:** 7D, 30D, 90D, 1A e tudo, ou menos?
2. **Amostra mínima** para rankings (sugiro entre 8 e 10).
3. **Fórmula do controle de objetivos.**
4. **Radar e comparativos:** referência no próprio histórico, referência estática ou adiar?
5. **Marcos:** mediana (recomendo) ou média?
6. **Recordes sem nome do adversário:** aceita mostrar data, campeão e patch?
7. **Instantâneo por time (recomendo) ou cálculo na hora?**

Com isso fechado, a próxima é a etapa 7: catálogo de campeões, tabela de características e o motor que classifica a composição do draft. Ela é onde o risco de política das sugestões que levantei na etapa 5 volta a pesar, então vale ter a resposta da Riot antes de começar. Quer seguir para ela?

Antes de descrever, vou conferir dois pontos que costumam mudar: a estrutura atual do Data Dragon e o que a Riot diz sobre ferramentas que usam o cliente do jogo.

Como nas etapas anteriores, é um plano em prosa, sem código, e nada foi implementado nem testado. Os fatos sobre Data Dragon e regras da Riot vêm de consulta que fiz agora; confirme nas páginas oficiais antes de decidir algo caro.

# Etapa 7: catálogo de campeões e motor de composição

Esta etapa entrega o que a tela de Draft mostra: a lista de campeões com ícones, a classificação do estilo da composição (Dive, Poke…), os pontos fortes e de atenção, as sugestões e os insights.

## 1. Visão geral

São três peças:
1. **Catálogo:** campeões, ícones, ids e patch atual, vindos do Data Dragon.
2. **Tabela de características:** o seu conhecimento do jogo transformado em dados (quanto cada campeão "é" Dive, Poke etc.).
3. **Motor de composição:** uma função que recebe o draft atual e devolve a análise.

Duas rotas: `GET /draft/catalog` e `POST /teams/{id}/draft/analyze`.

## 2. Primeiro, a política (resumo do que importa aqui)

- Numa postagem oficial da Riot, antes de lançar um aplicativo que use a API do cliente do jogo é preciso avisá-los, e só endpoints de uma lista aprovada são permitidos. Essa postagem é antiga e a política pode ter mudado; confirme na página atual do portal. O seu draft ao vivo depende disso, então avise a Riot cedo, junto com o registro do produto da etapa 5.
- Um guia de conformidade de terceiros (Overwolf, não é a Riot) diz que, na seleção de campeões da Solo/Duo, nomes de jogadores fora do seu grupo devem ser ocultados, por exemplo como "Aliado 1". Isso reflete a regra da Riot, mas confirme na fonte oficial. Na tela do launcher, mostre o nome real só de quem está no seu grupo ou cadastrado no time, e use rótulos genéricos para os demais.
- O mesmo guia lista como proibidos avisos de pico de poder, cronômetros de ultimate e rastreio de recarga de feitiços. O launcher não tem nada disso; mantenha assim.
- Produtos não podem usar informação que não esteja no cliente do jogo e que dê vantagem competitiva, e aplicativos que ditam decisões do jogador não são aprovados. O produto pode destacar decisões e oferecer várias opções, mas não deve tirar a decisão do jogador. Isso molda o desenho das sugestões (seção 5).
- A Riot pede o uso dos recursos do Data Dragon no produto. Use-o para ícones e nomes.

## 3. O catálogo (Data Dragon)

**O que ele é.** O Data Dragon é uma rede pública de dados estáticos do jogo; não exige chave nem login. Ele é atualizado manualmente depois de cada patch, então um campeão novo pode demorar um pouco a aparecer. Cada campeão traz um id em texto (como "Ahri"), uma chave numérica da Riot (como 103), tags de classe, notas de 1 a 10 de ataque, defesa e magia, e a URL do retrato quadrado. Há também uma lista de versões de patch, da mais nova para a mais antiga.

**Decisões de modelagem**
- **A chave numérica é a identidade.** Os dados de partida da Riot e o cliente do jogo falam em número. O seu banco já usa o id numérico como chave da tabela de campeões, o que está certo. O id em texto serve para montar a URL do ícone.
- **Conversão na borda.** O launcher guarda ids em texto (como "camille"). Mantenha assim: a ponte com o cliente do jogo (etapa 9) converte o número recebido no id em texto usando o catálogo. Assim as telas não mudam.
- **Cuidado com nomes diferentes do id.** Alguns campeões têm id em texto diferente do nome exibido. Nunca derive um do outro; leia os dois do catálogo.
- **Versão do patch.** Não escreva o formato do patch no código: leia a versão mais recente da lista oficial. O "25.22" do mock é só exemplo.
- **Idioma.** Baixe os textos em português do Brasil.

**Rotina de sincronização.** Um job periódico (por exemplo a cada hora) que:
1. Consulta a lista de versões.
2. Se há versão nova, baixa o catálogo desse patch.
3. Insere campeões novos e atualiza os existentes; nunca apaga (partidas antigas apontam para eles).
4. Guarda a versão atual e a data.

**Campeão desconhecido.** O worker pode encontrar, numa partida, um campeão que ainda não está no catálogo (lançamento recente). Não derrube a coleta: guarde o número, mostre um nome genérico e dispare uma atualização do catálogo.

**Ícones.** Duas opções:

| Opção | Vantagem | Desvantagem |
|---|---|---|
| Apontar direto para o Data Dragon | Zero armazenamento | Depende da disponibilidade deles; a URL muda a cada patch |
| Copiar para o seu armazenamento | Controle e velocidade | Mais trabalho e espaço |

Recomendo apontar direto no começo, e o launcher guarda em cache no disco (como combinado na etapa 4).

**Funções (rotas do jogo).** O Data Dragon dá classes (Lutador, Mago), não as rotas em que cada campeão joga. Para o seletor "Topo/Selva/Meio…" você precisa de uma lista própria de rotas possíveis por campeão (principal e secundárias). Mantenha-a na tabela de características, curada à mão.

## 4. A tabela de características

É a parte mais importante e a mais trabalhosa, porque é conhecimento, não código.

**Defina primeiro o vocabulário.** Poucas dimensões, cada uma com definição escrita. Ponto de partida: Dive, Poke, Desengaje, Split Push e Front-to-back, que já aparecem no seu documento. Para os pontos fortes e de atenção você vai precisar de mais algumas, por exemplo controle de grupo, linha de frente, limpeza de onda, escala para o fim do jogo e mistura de dano físico e mágico. Quanto menos dimensões, mais fácil manter e validar.

**Pesos.** O seu esquema aceita de 1 a 5, e ausência significa zero. Regra prática: 5 é "o campeão é isso", 3 é "faz bem", 1 é "faz um pouco".

**Como produzir 170 e tantas linhas**
1. Uma planilha versionada no repositório (não só no banco), com uma linha por campeão.
2. Primeiro rascunho feito por você, aproveitando as notas do Data Dragon como ponto de partida para dano e defesa.
3. Revisão por alguém experiente (um treinador ou jogador de elo alto). Dois pares de olhos pegam muita besteira.
4. Um script de importação que valida: todo campeão do catálogo tem pelo menos uma característica, os pesos estão no intervalo, não há campeão inexistente.
5. Um número de versão da tabela, para saber com qual versão cada análise foi feita.

**Manutenção.** Revise a cada campeão novo e a cada patch grande com mudança de papel (retrabalhos). Marque campeões sem revisão recente como "a revisar".

**Não tente automatizar por aprendizado de máquina agora.** Exige muitos dados globais (a limitação de política que já discutimos) e é difícil de explicar para o usuário. Comece com regras claras.

## 5. O motor de composição

### Princípios
- **Função pura:** recebe o estado do draft e o catálogo, devolve a análise. Sem acesso a rede ou banco dentro do cálculo. Isso torna os testes simples e a resposta rápida (o requisito é menos de 1 segundo; em memória fica na casa de milissegundos).
- **Regras como dados:** os limites que disparam "pouca limpeza de onda" ou "dependência de engage" ficam em tabela de configuração, não espalhados no código. Quem entende de jogo ajusta sem mexer em programação.
- **Determinístico:** mesma entrada, mesma saída.

### Passo a passo do cálculo
1. **Somar as características** dos campeões do seu time e normalizar em porcentagem. Essas são as barras da tela.
2. **Classificar:** o estilo dominante é o de maior porcentagem. Se a diferença para o segundo for pequena, devolva "Híbrida" em vez de forçar um rótulo.
3. **Draft incompleto:** com poucos picks a classificação é instável. Com 1 ou 2 campeões marque como provisória ou nem classifique.
4. **Pontos fortes e de atenção:** aplicar a tabela de regras sobre os totais.
5. **Sugestões:** veja abaixo.
6. **Estilo do inimigo:** a mesma conta sobre os picks visíveis do adversário. Essa informação está no cliente, então é legítima. **Não** consulte histórico de adversários na API da Riot: isso seria scouting, e a Riot lista isso entre usos não aprovados em páginas de outro jogo dela; para o LoL, confirme.

### Sobre o "78% de confiança"
Hoje o mock apresenta essa porcentagem como "confiança". O que o cálculo mede é o quanto a composição se encaixa num estilo, não a chance de vencer. Isso pode induzir erro e se aproxima de "dizer o que fazer". Sugiro rotular como **"Aderência ao estilo"** na interface.

### Sugestões (o ponto de política mais sensível)
O mockup mostra "Rell 72,4% ▲ +4,1%", que é win rate global. Isso exigiria agregar dados de muita gente (limitação da etapa 5) e soa como "o melhor pick". Alternativa alinhada às regras:
- Candidatos: campeões livres (não escolhidos nem banidos) que cabem nas rotas ainda abertas.
- Critérios de pontuação:
  - **encaixe**: o que falta na composição (por exemplo, desengaje);
  - **conforto do time**: partidas e win rate do **próprio time** com aquele campeão, com amostra mínima, e a quantidade de partidas sempre visível;
  - **relação com os adversários já escolhidos**, por características estáticas.
- Devolva **várias opções** (cinco, como no mockup), cada uma com o **motivo** ("fornece desengaje que falta", "seu time tem 7 partidas com ele").
- Evite palavras como "melhor" e não mostre win rate global.
- Se não houver dados do time para um campeão, simplesmente não mostre o número.

Antes de implementar, confirme com a Riot que esse formato é aceitável.

## 6. As rotas

**`GET /draft/catalog`**
- Devolve campeões (id em texto, chave numérica, nome, rotas, ícone, características), versão do patch e a ordem oficial do draft.
- Cacheável: inclua um identificador de versão do catálogo e permita ao launcher perguntar "mudou?" para economizar rede. O launcher guarda a última cópia no disco e abre o draft mesmo sem rede.
- **Separe o que é estático do que é do time.** No mock, a página "Tipos de Times" mistura descrição (estática) com win rate (do time). A descrição fica no catálogo; o win rate por estilo vem das agregações da etapa 6.

**`POST /teams/{id}/draft/analyze`**
- Recebe os picks e bans dos dois lados mais o número de sequência, e devolve a análise com o mesmo número.
- Confere que o time é do usuário.
- Limite de requisições generoso (o draft dispara várias por minuto), mas existente.
- Valida a entrada: no máximo 5 picks e 5 bans por lado, ids existentes, sem repetição.

**Counters:** os matchups por rota que a tela mostra vêm das agregações do time (etapa 6), não do motor.

## 7. Mudanças no launcher

- Trocar o catálogo mock pela rota, com cache em disco.
- O seletor de campeões e as telas passam a usar a URL do ícone; o componente de ícone já aceita uma URL.
- Tratar campeão desconhecido (nome genérico).
- Rótulo "Aderência ao estilo" e retirada dos percentuais de win rate global nas sugestões.
- Nomes de jogadores durante a seleção de campeões conforme a regra de anonimato (seção 2).
- Mensagem de "sem conexão" no modo manual quando a análise não puder ser obtida.

## 8. Como testar

1. **Casos de referência.** Monte 20 a 30 composições conhecidas (um time claramente de Dive, um de Poke, um de Split) com a classificação esperada. Isso vira um teste automático que protege contra regressões quando você mexer em pesos.
2. **Bordas:** zero, um e dois picks; todos de um mesmo estilo; empate entre estilos; campeão desconhecido; campeão repetido ou banido; as cinco rotas cheias.
3. **Propriedades:** as porcentagens somam 100; a ordem dos picks não muda o resultado; a mesma entrada dá a mesma saída.
4. **Importação da tabela:** testes que quebram se faltar campeão, peso fora do intervalo ou rota inválida.
5. **Sincronização do catálogo:** use um arquivo do Data Dragon guardado para simular campeão novo, renomeado e patch novo.
6. **Desempenho:** medir o tempo da análise com a pior entrada.
7. **Validação humana (a mais importante).** Pegue de 20 a 30 drafts reais do seu time, peça a um treinador que classifique o estilo de cada um e compare com o motor. Conte a concordância e ajuste pesos onde discordar. Esse é o único jeito honesto de saber se o motor presta; o que ele produz são heurísticas, não previsões.
8. **No launcher:** use a simulação e o modo manual, e teste com o servidor fora do ar.

## 9. Ordem de trabalho com verificações

1. Confirmar com a Riot a política de sugestões e de uso do cliente (seção 2).
2. Definir o vocabulário de características e começar a planilha.
3. Rotina de sincronização do catálogo. Verificação: o banco bate com o Data Dragon.
4. Rota do catálogo e cache no launcher. Verificação: o draft abre sem rede depois da primeira vez.
5. Importar a tabela de características com validação.
6. Motor: classificação e barras primeiro; depois regras de pontos fortes; por último sugestões.
7. Casos de referência e validação humana (itere pesos).
8. Rota de análise com número de sequência e limites.
9. Ajustes no launcher e testes ponta a ponta com a simulação.

## 10. Decisões que dependem de você

1. **Quais dimensões** entram no vocabulário (lista inicial: Dive, Poke, Desengaje, Split, Front-to-back, e quais mais).
2. **Quem faz a curadoria** da tabela e quem revisa.
3. **Rotas de cada campeão:** só a principal ou principal mais secundárias?
4. **Sugestões:** aceita o formato baseado no time e sem win rate global?
5. **Rótulo "Aderência ao estilo"** no lugar de "confiança"?
6. **Onde roda o motor:** no servidor (recomendado: uma fonte única, mais fácil de atualizar, acesso aos dados do time) ou dentro do launcher (zero latência e funciona offline, mas sem dados do time e mais difícil de atualizar)?
7. **Ícones:** apontar direto para o Data Dragon ou copiar para o seu armazenamento?

Depois de responder essas decisões e as da etapa 6, as etapas 8 em diante ficam mais claras. A próxima planejada é a ponte real com o cliente do jogo (etapa 9), que depende da resposta da Riot sobre o uso da API do cliente. Quer seguir para ela, ou prefere fechar antes as decisões pendentes das etapas 5, 6 e 7?


Antes de descrever, vou conferir como o cliente do jogo expõe os dados e o que a Riot permite hoje nessa API.

Registro das descobertas: li a política oficial da Riot para o LoL, e ela corrige dois pontos das etapas anteriores, que listo na seção 1. Como antes, é um plano em prosa, sem código, e nada foi implementado nem testado.

*(Na minha numeração, a etapa 7 já cobriu o catálogo e o motor de composição, que no plano original eram duas. Por isso a próxima é a 9.)*

# Etapa 9: ponte real com o cliente do LoL

Esta etapa troca o `MockLcuBridge` por uma classe que lê o cliente do jogo no computador do usuário. Ela alimenta o draft ao vivo, o selo de conexão e o gatilho de sincronização no fim da partida.

## 1. Política: o que a Riot diz sobre esta API

Li a página oficial de políticas do LoL agora.

- **Não é suportada.** A API do cliente não tem suporte oficial para aplicativos de terceiros; a Riot não garante documentação, disponibilidade nem aviso de mudanças. Esta é a peça mais frágil do projeto. Ela pode quebrar numa atualização do jogo sem aviso.
- **A Riot precisa saber.** Quem usa a API do cliente deve registrar o aplicativo (ou anotar no existente) e informar quais endpoints usa e como.
- **Integridade do jogo.** Produtos não podem usar informação ausente do cliente que dê vantagem competitiva, nem criar vantagem injusta, nem tirar decisões do jogador (podem destacar decisões e oferecer várias opções), e devem ampliar, não reduzir, a diversidade de escolhas.
- **Jogadores ocultos.** Produtos não podem identificar ou analisar jogadores que o próprio jogo mantém ocultos. Isso vale direto para a seleção de campeões em fila ranqueada (seção 5).
- **Não aprovado.** Informação específica da partida que o jogador não conheceria, e aplicativos que ditam decisões.
- **Ranking.** Produtos não podem criar alternativas aos sistemas oficiais de ranking, como calculadoras de MMR ou ELO. Evite qualquer "nota" de jogador que pareça um ranking próprio.

**Duas correções ao que eu disse antes**
1. **Patch.** O Data Dragon lista como mais recente a versão 16.23.1 (e a atualização dele depois de cada patch é manual, então pode demorar.). O "25.22" do mock está fora de época. Leia sempre a lista de versões; nunca fixe o formato.
2. **Catálogo.** Modos especiais, como o League Classic, ficam em pastas separadas do Data Dragon, com chaves próprias (por exemplo "Jade_Ahri"). Na etapa 7, ignore essas pastas e use só os dados do jogo base.

**Pendência de produto:** o aviso legal de que o produto não é endossado pela Riot precisa estar bem visível. Copie o texto exato da seção "Developer API Policy" da página e coloque no rodapé do launcher. Ainda não está lá.

## 2. O que a ponte precisa ler (e só isso)

Mantenha a lista mínima, pois você terá de informá-la à Riot.

| Dado | Endpoint |
|---|---|
| Fase atual do jogo | `/lol-gameflow/v1/gameflow-phase` |
| Sessão da seleção de campeões | `/lol-champ-select/v1/session` |
| Quem está logado no cliente | `/lol-summoner/v1/current-summoner` (um exemplo citado em bibliotecas; confirme) |
| Fila e id da partida em curso | `/lol-gameflow/v1/session` (confirme os campos) |

O último e o terceiro servem a duas proteções: confirmar que a conta aberta é a mesma vinculada ao usuário do launcher (evita analisar a conta errada) e dedupar o gatilho de fim de partida.

**Regra de ouro: somente leitura.** Nenhum envio ao cliente (nada de aceitar partida, escolher campeão ou importar runas). Isso reduz risco com a Riot e com o anticheat.

## 3. Como a conexão funciona

1. **Achar o cliente.** Há duas formas:
   - Ler um arquivo "lockfile" que o cliente grava; ele tem campos separados por dois-pontos (nome, processo, porta, senha, protocolo). O caminho padrão no Windows é a pasta "Riot Games\League of Legends", mas a instalação pode estar em outro lugar.
   - Ler a linha de comando do processo `LeagueClientUx`, de onde saem porta e senha. Funciona mesmo com instalação em pasta personalizada, mas é mais trabalhoso no Windows.

   Recomendo: processo primeiro, lockfile como alternativa, e como último recurso pedir ao usuário que aponte a pasta do jogo (guardada nas configurações).
2. **Conectar.** O cliente atende HTTPS e WebSocket seguro em 127.0.0.1 na porta encontrada. A autenticação é básica, com usuário "riot" e a senha do lockfile.
3. **Certificado.** O cliente usa certificado próprio. Bibliotecas aceitam certificados autoassinados apenas em loopback. Faça o mesmo: aceite exceção somente para 127.0.0.1 e para essa porta, nunca de forma global. A Riot publica um certificado raiz para o Game Client API (que também usa certificado próprio); teste se ele valida também o cliente e, se validar, prefira-o a ignorar erros.
4. **Assinar eventos.** Depois de abrir o WebSocket, envia-se uma mensagem de inscrição no evento "OnJsonApiEvent" e recebem-se mensagens com o endereço do recurso, o tipo (criação, atualização, remoção) e os dados. Filtre pelo endereço, e descarte o resto.
5. **Estado inicial.** Eventos só avisam mudanças. Ao conectar, faça uma consulta HTTP para saber a fase e a sessão atuais.
6. **Reconexão.** O cliente fecha, reinicia, cai. Se perder a conexão, volte a procurar a cada poucos segundos com espera crescente; verifique que o processo ainda existe para não usar um lockfile antigo.

No Qt: os módulos de rede e WebSockets (o `CMakeLists.txt` precisa do `Qt6::WebSockets`), tudo assíncrono no laço de eventos, sem bloquear a interface.

## 4. Do JSON do cliente ao modelo do launcher

Separe isto em uma peça pura, o **tradutor** (recebe JSON, devolve o `session` que o app já entende). Ela é a mais fácil de testar.

Pontos de tradução:
- **Aliado e inimigo** vêm de "meu time" e "time adversário", não da cor. Aliado pode ser o lado vermelho.
- **Campeão:** o cliente envia o número; converta para o id em texto do catálogo. Zero significa "ainda sem escolha". Desconhecido vira placeholder.
- **Bans e picks:** use as ações da sessão, que indicam tipo, concluído ou não, campeão e quem agiu. Decida se a **pré-seleção** (campeão sobre o qual o jogador está passando o mouse) aparece; ela é visível no cliente, então é legítima, mas deve ser mostrada como provisória.
- **Rotas:** hoje o launcher associa o jogador `i` à função `i`. No modo ao vivo, ordene pelas posições atribuídas pelo cliente; sem posição (modo normal ou cego), use a ordem das casas.
- **Cronômetro:** a sessão traz o tempo restante da fase e o relógio interno do cliente; use isso em vez dos 30 segundos fixos do mock.
- **Subfases:** planejamento, bans e picks, finalização; mapeie para rótulos da tela.
- **Fila suportada:** só ranqueada e flex (e outras que você definir). Em modo cego, ARAM etc., mostre "modo não suportado".

**Fase do jogo → estados do app:** fechado → Desconectado; aberto sem partida → Conectado; seleção → ChampSelect; em jogo ou reconectando → InGame; fim → EndOfGame. Ao entrar em EndOfGame, dispare a sincronização **uma vez por partida** (identificador da partida em curso), mesmo que a fase oscile. A API da Riot pode demorar a ter a partida disponível logo após o fim, então o worker da etapa 5 deve tentar de novo por alguns minutos.

**Dodge (alguém sai da seleção):** a fase volta para o saguão; o launcher precisa limpar o draft.

## 5. Nomes na seleção de campeões

Um guia de conformidade de terceiros diz que em Solo/Duo os nomes de quem não está no seu grupo devem aparecer como "Aliado N". Combinado com a regra de jogadores ocultos da Riot, a diretriz fica:
- Mostre nome só quando o próprio cliente o revelar (você e seu grupo).
- Nunca tente descobrir a identidade de jogador oculto cruzando outras consultas (por exemplo por PUUID).
- Do inimigo, mostre apenas campeões, nunca identidades.
- A análise do inimigo usa só o que está visível na tela de seleção.

## 6. Segurança e privacidade

- Senha e porta ficam só em memória; nunca em disco, log ou envio ao servidor (os logs devem ocultar a senha).
- Só 127.0.0.1.
- Ao servidor, envie apenas o necessário para a análise: ids de picks e bans, sem nomes nem identificadores de jogadores ocultos.
- Dê ao usuário uma opção clara para ligar ou desligar o "Draft ao vivo", com texto explicando o que é lido.
- Teste com o anticheat do jogo ativo (Vanguard); eu não consegui confirmar que a leitura da linha de comando do processo funciona sem restrições nele. Se não funcionar, o lockfile e a escolha manual da pasta cobrem.

## 7. Como lidar com uma API que pode quebrar sem aviso

- **Tradutor tolerante:** ignore campos desconhecidos, use valores padrão, nunca derrube o app por um JSON inesperado.
- **Degradação suave:** se a leitura falhar, o launcher volta ao modo Manual com uma mensagem clara.
- **Interruptor remoto:** uma configuração servida pela API que permita desligar o draft ao vivo para todos (caso a Riot peça ou o jogo mude). Isso é a única forma de reagir em horas.
- **Telemetria mínima e opcional:** só contagem de falhas de leitura e versão do cliente, sem dados de jogadores.
- **Rotina a cada patch:** repetir os testes de contrato com uma captura real nova.
- **Atualização do launcher** rápida (etapa 11), por isso ela importa.

## 8. Como testar

1. **Capturas reais.** Em partidas de verdade, grave os JSONs da sessão e da fase (ranqueada solo, flex, modo cego, ARAM, reconexão, dodge). Remova nomes e identificadores e use-os como arquivos de teste do tradutor.
2. **Servidor de cliente falso:** um programa local com HTTPS e WebSocket autoassinados que reproduz uma sessão gravada, para testar conexão, queda, reconexão, mensagens malformadas e lentidão, sem abrir o jogo.
3. **Casos manuais:** abrir o cliente depois do launcher; fechar o cliente no meio da seleção; dodge; reiniciar o cliente; instalação em pasta diferente; conta diferente da vinculada; cliente em outro idioma; e rodar com o anticheat ligado.
4. **Tela de diagnóstico** no launcher: estado da conexão, método de descoberta usado, hora do último evento, versão do cliente (sem senha), com botão para copiar. Isso economiza muito suporte.
5. **Beta pequeno** com 3 a 5 jogadores reais, antes de qualquer lançamento.

## 9. Ordem de trabalho com verificações

1. Registrar o produto e informar os endpoints à Riot (seções 1 e 2).
2. Capturar amostras reais em partidas (consultas manuais com as credenciais do cliente).
3. Tradutor + testes com as amostras. Verificação: reproduz o mesmo draft da tela do jogo.
4. Descoberta do cliente (processo, lockfile, pasta escolhida).
5. HTTP inicial + WebSocket + acompanhamento da fase. Verificação: o selo do launcher acompanha o cliente.
6. Ligar ao `DraftController` no modo ao vivo (rotas por posição, aliado/inimigo, cronômetro real, reset no dodge).
7. Gatilho de fim de partida, com deduplicação.
8. Reconexão e casos de borda.
9. Tela de diagnóstico e interruptor remoto.
10. Testes com anticheat e beta fechado.

## 10. Decisões que dependem de você

1. **Filas suportadas** no draft ao vivo.
2. **Pré-seleção:** mostrar ou só picks confirmados?
3. **Nomes:** concorda com mostrar só o que o cliente revela e "Aliado N" no resto?
4. **Plataforma:** só Windows no começo? (macOS usa outros caminhos.)
5. **Descoberta:** processo primeiro com lockfile como reserva, como recomendei?
6. **Telemetria** de falhas: entra, e com consentimento explícito?

---

# Visão ampla: o caminho todo

| # | Etapa | Estado | Depende de | Principal risco |
|---|---|---|---|---|
| 1 | Frontend (Qt) com dados mock | **Feito e testado** | — | — |
| 2 | API de login e times | **Feito e testado** | 1 | — |
| 3 | Launcher conectado à API | Plano passado | 2 | Renovação de token e falhas parciais |
| 4 | Upload de logo | Plano passado (local, preenchimento, 512) | 3 | Validação de imagem |
| 5 | Coletor de partidas | Plano passado | Registro na Riot, chave | Limites da API e política |
| 6 | Agregações e análise | Plano passado | 5 | Definições de fórmula |
| 7 | Catálogo e motor de composição | Plano passado | 5, tabela de tags | Curadoria e política das sugestões |
| 9 | Ponte com o cliente do LoL | **Esta mensagem** | 7 (catálogo) | API não suportada |
| 10 | Treino: diagnósticos, metas, evolução | A detalhar | 6 | Qualidade dos diagnósticos |
| 11 | Instalador, atualização automática, assinatura | A detalhar | Todas | Certificado de assinatura, reputação |
| 12 | Produção: hospedagem, segurança, LGPD, lançamento | A detalhar | Todas | Custos, legal, chave de produção |

**Caminho crítico:** registro do produto na Riot, depois coleta (5), depois agregações (6) e catálogo (7). Sem dados reais, as telas não têm o que mostrar. A ponte com o cliente (9) e o Treino (10) podem andar em paralelo depois disso.

**O que pode barrar o projeto, em ordem de risco:**
1. **Aprovação da Riot** (chave de produção e uso da API do cliente). Se vierem restrições, mudam as sugestões do draft e o escopo dos dados.
2. **Curadoria da tabela de campeões:** é trabalho de conhecimento contínuo, não de código.
3. **API do cliente instável:** exige a estratégia de contenção da seção 7.
4. **LGPD e consentimento** dos jogadores analisados: precisa de apoio jurídico.
5. **Limites de requisição** na fase de testes, que atrasam as cargas iniciais.

**O que resta nas etapas finais (resumo para você planejar):**
- **Etapa 10, Treino:** transformar os dados das etapas 5 e 6 em diagnósticos acionáveis ("tempo de contestação de dragão acima do ideal"), metas acompanháveis e gráficos de evolução. É regra de negócio e design de alertas mais do que infraestrutura. O maior desafio é definir "ideal" sem referências globais (por causa da política).
- **Etapa 11, Distribuição:** instalador do Windows, atualização automática, assinatura de código (sem ela o SmartScreen avisa e afasta usuários), política de versões, e canal de correção rápida para quando a API do cliente mudar.
- **Etapa 12, Produção:** hospedagem, HTTPS, backups testados, monitoramento e alertas, rate limit, política de privacidade e termos, exclusão de dados a pedido, registro final do produto na Riot, RSO (se aprovado), custos e plano de lançamento em fases (beta fechado, depois aberto).

Posso seguir para a etapa 10 na próxima mensagem. Se preferir, antes disso eu consolido numa só lista todas as decisões pendentes das etapas 4 a 9, para você fechar de uma vez.

Como nas etapas anteriores, é um plano em prosa, sem código, e nada foi implementado nem testado. Aqui há menos fatos externos a conferir e mais decisões de produto, então marco o que é opinião minha.

# Etapa 10: Treino (diagnósticos, metas e evolução)

Esta etapa transforma os números das etapas 5 e 6 em orientação: o que está errado, o que fazer a respeito e se está melhorando. É a parte que mais diferencia o produto, e também a mais fácil de fazer mal, porque o código é simples e o difícil é decidir o que é "ruim".

## 1. O que as telas esperam

- **Diagnóstico da equipe:** alertas com gravidade (crítico, atenção, informativo, positivo), título e explicação.
- **Diagnóstico individual:** os mesmos alertas por jogador.
- **Metas:** coletivas ou individuais, com valor atual, alvo, unidade e marca de concluída.
- **Evolução:** série ao longo do tempo de cada métrica, com uma referência para comparar e cor indicando se está bom ou ruim.

O formato já existe no arquivo `training.json` do mock, e a API deve devolver exatamente isso.

## 2. A política sob a ótica do Treino

Reli a página oficial da Riot nesta etapa.

- Ferramentas de treino em que o jogador vê o próprio histórico e estatísticas agregadas estão entre os usos aprovados. O Treino se encaixa bem nisso, desde que seja retrospectivo (análise depois da partida) e não instruções durante o jogo.
- Estatísticas agregadas sem jogadores específicos também aparecem como uso aprovado. Isso abre a porta para referências por elo, mas veja a seção 4.
- Produtos não podem criar alternativas ao ranking oficial, como calculadoras de MMR ou ELO. Por isso, **não crie uma nota geral por jogador** que pareça um ranking próprio. Mostre métricas e tendências, não um placar.
- Aplicativos que ditam decisões não são aprovados. Formule os diagnósticos como observações e focos de treino ("seu farm cai depois dos 15 minutos"), não como ordens de jogo.

Fora da política, há uma questão de privacidade interna: o diagnóstico individual expõe os pontos fracos de uma pessoa a quem administra o time. Decida quem vê o quê (seção 10).

## 3. O dicionário de métricas (a base de tudo)

Antes de qualquer alerta, defina um catálogo onde cada métrica tem:
- nome, definição escrita e fórmula;
- de onde vem o dado;
- direção (maior é melhor ou menor é melhor) e unidade;
- a quais funções se aplica (farm não faz sentido para suporte);
- amostra mínima.

Diagnósticos, metas e evolução usam **a mesma** definição. Assim o número do alerta é igual ao da meta e ao do gráfico.

**Classifique cada ideia por mensurabilidade antes de prometê-la:**

| Nível | Exemplos | Observação |
|---|---|---|
| A: direto da partida | Abates, mortes, farm total, pontuação de visão, dano, participação em abates | Confiável |
| B: quadros por minuto da linha do tempo | Ouro e farm no minuto 10 ou 15, diferença de rota | Confiável, mas só para partidas com linha do tempo |
| C: eventos da linha do tempo | Tempos de objetivos, mortes no começo, sentinelas colocadas | Confira na documentação quais eventos existem |
| D: não mensurável ou só aproximado | "Sincronia de recall", "tempo de contestação de dragão" | Posições vêm em intervalos de um minuto; recall provavelmente não é um evento público |

Os dois exemplos do mockup ("sincronia de Recall" e "contestação de dragão acima de 45s") caem no nível D, até onde sei. Verifique na documentação da linha do tempo. Se confirmar, troque-os por algo mensurável (por exemplo, "presença no primeiro dragão", como participação em abates ou mortes perto do tempo do objetivo, com a ressalva de ser aproximação) ou transforme em meta qualitativa.

**Lista inicial sugerida (8 a 10 métricas):** farm por minuto e farm aos 15 minutos; diferença de ouro aos 15 minutos; mortes antes dos 15 minutos; pontuação de visão por minuto; participação em abates; participação do dano versus participação do ouro; taxa de throw; velocidade de fechamento das vitórias; participação em objetivos; taxa de vitória quando se está na frente.

## 4. De onde vem o "ideal"

O diagnóstico só tem sentido comparado a uma referência. Há três fontes, em ordem de esforço:

1. **O próprio histórico** (recomendo começar aqui). Compara o período recente com os 30 ou 60 dias anteriores do mesmo jogador ou time. Não precisa de dados globais e é a leitura mais honesta: "você piorou" ou "melhorou".
2. **Referências estáticas por função e elo.** Valores que você mesmo cura, baseados em guias e experiência, guardados numa tabela versionada com a fonte anotada. É manual, mas simples e explicável.
3. **Amostra própria do elo.** Coletar partidas de jogadores do mesmo elo para calcular médias. Segundo a política, agregados sem jogadores específicos são aceitos, mas é caro em chamadas à API e em armazenamento, e exige chave de produção. Deixe para depois.

**Na interface, sempre diga de onde veio a referência** ("seu histórico", "referência estática do elo Ouro"). Isso evita enganar o usuário.

O elo médio do time vem das ligas dos jogadores (rotina de elo que o worker já precisa ter).

## 5. O motor de diagnóstico

Um motor de regras, no mesmo espírito do motor de composição da etapa 7:

**Uma regra contém:**
- a métrica;
- a comparação (contra referência, contra histórico ou contra alvo);
- a amostra mínima;
- como a distância vira gravidade;
- o texto do alerta com a explicação;
- um foco de treino sugerido.

As regras ficam em tabela de configuração versionada, não no código.

**Para o motor ser útil e não irritante:**
- **Amostra mínima.** Abaixo dela, não alerte; mostre "dados insuficientes". Dez partidas é um ponto de partida (decisão sua).
- **Mediana em vez de média** para métricas com valores extremos.
- **Limite de alertas.** Mostre os 3 a 5 mais importantes por área. Priorize por tamanho do desvio, confiança da amostra e peso que você der à métrica. Muitos alertas viram ruído e o usuário para de ler.
- **Sem repetição.** Se o mesmo alerta persiste, agrupe em vez de listar de novo.
- **Mostre também o que vai bem.** O mockup tem o estado "positivo", e reforço positivo mantém o usuário engajado.
- **Considere a função.** Cada regra declara a quais funções se aplica.
- **Explicável.** Todo alerta traz o valor, a referência, o tamanho da amostra e o período. Se possível, também uma lista das partidas que o sustentam (o "porquê" que convence um jogador cético).
- **Evite relação causal.** "Seu farm cai após os 15 minutos" é fato; "por isso você perde" é interpretação. Fique no fato.

**Quando roda:** no fim de cada sincronização, junto com o cálculo da análise da etapa 6, gravando um instantâneo para a rota apenas ler.

## 6. Metas

**Ciclo de vida:** criar, acompanhar, concluir, expirar ou abandonar.

**O que define uma meta:** métrica, alvo, escopo (time ou jogador), janela de avaliação, direção, prazo opcional e o valor inicial (a "linha de base", registrada na criação).

**Como calcular o progresso:** a distância percorrida entre a linha de base e o alvo. Atenção aos casos de borda: métricas em que menor é melhor, linha de base já igual ou melhor que o alvo, piora em relação à base (progresso negativo, que a tela deve tratar).

**Quando considerar concluída:**
- **Automática (recomendo):** atingiu o alvo de forma **sustentada**, por exemplo na média das últimas N partidas, e não numa partida isolada. Evita comemorar sorte.
- **Manual:** o mock hoje deixa marcar à mão. Mantenha isso apenas para metas **qualitativas** (por exemplo, "melhorar a comunicação no draft"), que não têm métrica.

**Modelos prontos:** ofereça metas sugeridas a partir de um diagnóstico ("criar meta" no próprio alerta), com alvo preenchido a partir da referência. É a forma mais natural de fechar o ciclo entre diagnosticar e treinar.

**Validação:** recuse alvos absurdos (muito acima do que a referência indica) com mensagem clara.

**Histórico:** guarde snapshots do progresso para o gráfico de evolução e para não perder o registro quando uma meta for concluída.

## 7. Evolução

- **Agrupamento:** por semana (ou por bloco de N partidas, o que dá curvas mais estáveis em quem joga pouco).
- **Suavização:** média móvel curta para reduzir o zigue-zague, sem esconder a tendência.
- **Referência** desenhada como linha de comparação, sempre rotulada.
- **Tendência:** só declare "subindo" ou "caindo" se a mudança passar de um limite mínimo e a amostra for suficiente.
- **Buracos:** semanas sem partidas aparecem como lacuna, não como zero.
- **Período:** o mockup tinha 7D, 30D, 90D e 1A; planeje como parâmetro, como na etapa 6.
- **Consistência:** o último ponto do gráfico deve bater com o número do diagnóstico e da meta.

## 8. Dados e rotas (conceito)

**Banco (migração 003):**
- referências por métrica, função, elo e versão, com a fonte;
- regras de diagnóstico versionadas;
- metas e o histórico de progresso;
- instantâneos de diagnóstico e de evolução por time e período, com a data de geração.

**Rotas:**
- consultar o Treino do time (diagnóstico, metas e evolução, com o parâmetro de período);
- criar, editar e excluir metas;
- consultar as partidas que sustentam um alerta (a "evidência").

Todas com filtro por dono do time, como as demais. A visibilidade do diagnóstico individual segue a decisão da seção 10.

**Estado "em preparação"** quando ainda não há dados suficientes, igual ao da análise.

## 9. Mudanças no launcher

- Trocar o mock pela API.
- **Criar, editar e excluir metas.** Hoje a tela só marca e desmarca; falta o diálogo de criação.
- Botão "criar meta" dentro de cada alerta.
- Mostrar a **origem da referência** e o **tamanho da amostra**.
- Tela de evidência ("ver as partidas que levaram a este alerta").
- Seletor de período.
- Estado de "dados insuficientes".
- Botões "útil" e "não útil" em cada alerta (ver seção 11). O launcher ainda não os tem.
- Texto de privacidade onde aparecer diagnóstico individual.

## 10. Decisões que dependem de você

1. **Lista de métricas da versão 1** (sugeri 10).
2. **Estratégia de referência:** começar com histórico próprio e referência estática, deixando a amostra do elo para depois?
3. **Quem vê o diagnóstico individual:** só o dono do time, o próprio jogador, ou ambos? (Se o jogador não tem conta no app, ele nem sabe que está sendo analisado.)
4. **Número máximo de alertas** por área e **amostra mínima**.
5. **Regra de conclusão de metas:** automática e sustentada, com manual só para qualitativas?
6. **O que fazer com "recall" e "contestação de dragão"** se a mensurabilidade não se confirmar.
7. **Botões de feedback** em cada alerta: entram na primeira versão?
8. **Tom das mensagens:** observação neutra, sem ordens, como sugeri?

## 11. Como validar que isso presta

1. **Contas à mão.** Para cada métrica, calcule num caso pequeno e compare.
2. **Retroteste:** rode as regras sobre histórico antigo do seu time e veja a frequência dos alertas. Se quase tudo dispara, os limites estão apertados; se nada dispara, folgados.
3. **Revisão por um treinador:** pergunte "este alerta é verdade? é útil?" sobre 30 a 50 alertas reais. Esse é o único teste que mede utilidade.
4. **Casos de borda:** amostra pequena, função onde a métrica não se aplica, valores empatados, jogador que mudou de função, meta com base igual ao alvo, períodos sem partida, fuso horário.
5. **Idempotência:** recalcular duas vezes dá o mesmo resultado.
6. **Coerência entre telas:** o mesmo número aparece igual no diagnóstico, na meta e na evolução.
7. **Feedback no beta:** use os botões "útil / não útil" para descobrir quais regras incomodam.

## 12. Ordem de trabalho com verificações

1. Fechar as decisões 1 a 4 (sem elas as regras mudam depois).
2. Escrever o dicionário de métricas e classificá-las por mensurabilidade.
3. Implementar as métricas (reaproveitando o que a etapa 6 já calcula). Verificação: contas à mão.
4. Tabela de referências estáticas e histórico próprio.
5. Motor de regras e instantâneo do diagnóstico.
6. Metas: modelo, progresso, conclusão sustentada e rotas.
7. Evolução.
8. Rota única do Treino com período e estado "em preparação".
9. Telas do launcher (metas, evidência, período, privacidade).
10. Retroteste e revisão com um treinador; ajuste de limites.
11. Feedback no beta.

## Onde estamos no mapa

Depois da etapa 10, o produto está completo em funcionalidades. As duas que faltam não criam funções; tornam o produto entregável:

- **Etapa 11, distribuição:** instalador do Windows, atualização automática, assinatura de código e canal de correção rápida (essencial por causa da fragilidade da API do cliente, vista na etapa 9).
- **Etapa 12, produção:** hospedagem, HTTPS, backups, monitoramento, política de privacidade e LGPD, registro final do produto na Riot, chave de produção, RSO e lançamento em fases.

Posso seguir para a etapa 11. Se preferir, antes disso consolido numa única lista todas as decisões pendentes das etapas 4 a 10 para você fechar de uma vez.

Antes de descrever, vou conferir o que mudou recentemente em assinatura de código para Windows e as opções de instalador e atualização, que são os pontos que mais mudam.

Como nas etapas anteriores, é um plano em prosa, sem código, e nada foi implementado nem testado. Pesquisei assinatura de código, licença do Qt e opções de instalador agora, porque tudo isso mudou nos últimos anos.

# Etapa 11: distribuição (instalar, atualizar, assinar)

O objetivo: uma pessoa baixa o instalador, instala sem alertas assustadores, recebe atualizações sozinha, e você consegue corrigir um problema em horas, não em semanas. Isso importa mais neste projeto por causa da API do cliente do LoL, que pode quebrar sem aviso (etapa 9).

## 1. Licença do Qt: decida antes de distribuir

É o ponto que mais surpreende quem distribui um app em Qt. Não é aconselhamento jurídico; é o que a Qt publica, e o ideal é um advogado revisar.

- No Qt de código aberto (LGPLv3), seu código pode continuar fechado se o app só usar o Qt como biblioteca, normalmente por ligação dinâmica. Com ligação estática, o app pode passar a ficar sujeito à LGPL. Por isso, **nunca compile estático**.
- É preciso entregar ao usuário o texto da licença LGPL e mostrar um aviso destacado de que o Qt é usado.
- É preciso fornecer o código-fonte completo das bibliotecas Qt usadas, sob o seu controle; um link para o código do projeto Qt não basta. Uma alternativa é uma oferta escrita de fornecimento.
- O usuário precisa poder religar o aplicativo com uma versão modificada do Qt, e você deve fornecer as instruções para isso. Na prática, isso exige entregar as DLLs do Qt separadas, como o `windeployqt` faz.
- Alguns módulos só existem sob GPL, como Qt Charts e Qt Data Visualization; usar um deles obrigaria o seu app a ser GPL. O launcher não usa nenhum (os gráficos são desenhados em Canvas); **mantenha assim** e confira qualquer módulo novo.
- Se o app não cumprir todos os requisitos da LGPL, ele não pode ser distribuído. Algumas lojas de aplicativos têm regras que conflitam com a LGPL, o que pesa contra a Microsoft Store com Qt aberto.
- Em caso de dúvida, a Qt indica a licença comercial como o caminho mais seguro. Ela é paga por desenvolvedor; peça cotação se a conformidade LGPL parecer trabalhosa.

**O que isso vira na prática:** DLLs dinâmicas, uma tela "Sobre" com o aviso e o texto da LGPL, uma página pública com a oferta do código-fonte do Qt (guarde uma cópia da versão exata que você usou) e um inventário de todas as bibliotecas de terceiros com suas licenças. Na mesma tela "Sobre" vai o aviso legal da Riot que já mencionei.

## 2. Build reprodutível

- **Compilação automática** (um serviço de integração contínua com máquina Windows), sempre em Release, com compilador e versão do Qt **fixados**. Eu testei o projeto com Qt 6.4; você usa a 6.12. Fixe a versão e teste de verdade nela.
- **Versionamento:** defina o esquema (o mockup usa quatro números, como 1.2.2.1) e use a mesma versão no executável, na tela e no atualizador. Mantenha um changelog em português.
- **Metadados do executável:** ícone, informações de versão e manifesto do Windows (nome do produto, empresa, versão). Isso reduz suspeitas de antivírus e dá cara de produto.
- **Símbolos de depuração (PDB):** arquive cada versão; sem eles, relatos de falha são ilegíveis.
- **Empacotamento das dependências:** o `windeployqt` com a pasta de QML; o runtime do Visual C++ (junto do instalador ou como pré-requisito); e remova módulos e plugins que não usa, para o download não ficar enorme.
- **O teste mais importante:** instalar e rodar numa máquina Windows **limpa** (uma VM sem Qt, Visual Studio nem nada de desenvolvimento). É onde aparecem DLLs faltando que na sua máquina nunca falham.

## 3. Instalador e atualização: as opções

| Opção | O que é | Pontos a favor | Pontos de atenção |
|---|---|---|---|
| **Qt Installer Framework** | Instalador do próprio Qt, com repositório de atualizações | Multiplataforma e feito para apps Qt | Visual datado; em geral baixa componentes inteiros, sem atualização diferencial (confirme) |
| **Velopack** | Instalador e atualizador moderno | Sem configuração, gera instalador, atualizações e pacotes diferenciais com um comando, escrito em Rust | Confirme se há suporte adequado para C++/Qt |
| **MSIX + App Installer** | Formato da Microsoft | Permite distribuição direta pelo seu site, com atualização automática por um arquivo `.appinstaller` | Exige assinatura; vale testar leitura do `lockfile` do LoL e a política de arquivos |
| **WinSparkle** | Atualizador clássico | Só para Windows; simples | Mais antigo; ainda precisa de um instalador à parte |
| **Microsoft Store** | Loja | Assinatura gratuita e atualização embutida no caminho MSIX | Na via de instalador MSI/EXE a loja não envia atualizações, exige certificação, e há o conflito com LGPL citado acima |
| **Atualizador próprio** | Você escreve | Controle total | Muito trabalho e risco de segurança; evite |

**Minha recomendação (opinião, não fato):** instalação **por usuário** (sem pedir administrador, pois muitos jogadores não têm), com atualização em segundo plano e, se possível, diferencial. Faça um protótipo de um dia de cada candidato (Qt IFW, Velopack, MSIX) e meça: instala sem administrador? Quanto demora atualizar? Qual o tamanho do download? Funciona com assinatura? Integra em C++? O launcher consegue ler o cliente do LoL depois de instalado assim? Decida com esses números.

## 4. Assinatura de código

Sem assinatura, o Windows exibe alertas fortes e antivírus desconfiam. Os fatos que verifiquei:

- O instalador e todos os arquivos executáveis precisam ser assinados com um certificado de uma autoridade confiável da Microsoft; certificado autoassinado não é aceito. Assine o instalador **e** o executável **e** as DLLs.
- **Reputação não é instantânea.** Desde 2024, certificados EV passam pelo mesmo acúmulo de reputação que os OV, e a reputação se acumula por arquivo ao longo do tempo. Uma página de fornecedor de certificados ainda afirma reputação imediata no EV (segundo ela,), o que contradiz a Microsoft. Eu confio na Microsoft. Conclusão prática: **pague por um OV**, não por um EV, e espere alertas nas primeiras versões.
- Relatos de desenvolvedores no fórum da Microsoft mostram o aviso reaparecendo a cada nova versão, mesmo com assinatura. Planeje isso: avise os usuários no primeiro lançamento ("Mais informações > Executar mesmo assim") e use o atualizador interno (seção 5).
- **O serviço da Microsoft provavelmente não serve para você.** O Azure Artifact Signing (antigo Trusted Signing) custa cerca de US$ 9,99 por mês, mas só atende organizações nos EUA, Canadá, UE e Reino Unido; pessoas físicas apenas nos EUA e Canadá. Você está no Brasil; confirme se isso mudou.
- **Alternativa:** um certificado OV de uma autoridade como DigiCert, Sectigo ou GlobalSign custa de US$ 150 a US$ 300 por ano e é emitido no mundo todo. Verifique se a autoridade emite para pessoa física no Brasil; muitas exigem empresa registrada (um CNPJ ou MEI pode resolver).
- **Chave em hardware.** Desde 1º de junho de 2023, certificados OV e EV exigem autenticação em dois fatores (token USB ou serviço de assinatura em nuvem). Você não pode simplesmente deixar um arquivo `.pfx` no servidor de build. Escolha um token físico (assinatura na sua máquina) ou um serviço de assinatura em nuvem da própria autoridade (permite automatizar).
- **Validade:** desde 1º de março de 2026 o máximo é 458 dias, então a renovação é anual e deve estar no calendário. Sempre aplique **carimbo de data e hora** na assinatura, para que versões antigas continuem válidas depois que o certificado vencer.
- **Tipo de chave:** a resposta de um moderador da Microsoft indica que os recursos de segurança do Windows aceitam só certificados RSA, não ECC. Confirme ao comprar.
- **Prazo:** a validação do certificado e a entrega do token podem levar de dias a semanas. **Comece a compra cedo**, em paralelo com o resto.

## 5. Atualização automática: o desenho

**Canais.** Estável e beta (opcional, só para quem pedir). Distribuição gradual: libere para 10%, depois 50%, depois todos, com opção de pausar.

**O que a API deve informar ao launcher** (uma rota de configuração):
- versão mais recente por canal;
- **versão mínima suportada** (força atualização quando o contrato da API muda);
- **interruptores remotos** (por exemplo, desligar o draft ao vivo, como combinado na etapa 9);
- avisos de manutenção.

O launcher envia sua versão em todas as requisições, para a API saber quem é antigo.

**Fluxo:**
1. Verifica ao abrir e a cada poucas horas.
2. Baixa em segundo plano, com retomada se cair.
3. Confere **integridade (hash) e assinatura** antes de qualquer execução.
4. Aplica ao reiniciar, com aviso claro ("Reiniciar para atualizar").
5. **Nunca reinicia durante seleção de campeões nem partida:** o atualizador consulta o estado da ponte do cliente.

**Falhas:** sem rede, disco cheio, antivírus bloqueando, download pela metade, atualização interrompida por queda de energia. A pior é ficar com um app quebrado: mantenha a versão anterior e **volte sozinho** se a nova não abrir.

**Segurança (o atualizador é um alvo clássico):** só HTTPS, pacotes assinados e verificados antes de rodar, impedir "versões antigas disfarçadas" (rejeitar downgrade sem autorização), proteger as credenciais de publicação com autenticação em dois fatores e permissões mínimas.

**API e launcher evoluem em ritmos diferentes.** Mantenha versões antigas da API funcionando por algumas versões do launcher e faça mudanças de banco compatíveis com ambos (acrescentar antes, remover só depois). Sem isso, um lançamento do servidor derruba quem ainda não atualizou.

## 6. Pipeline de lançamento

1. Etiqueta de versão no código.
2. Build automático (Release, versão fixa).
3. Testes automáticos.
4. Empacotamento.
5. Assinatura.
6. Envio a um armazenamento com CDN (S3, Cloudflare R2 etc.), junto com hashes.
7. Publicação no canal beta, depois no estável gradualmente.
8. Monitoramento da adoção e das falhas.

Guarde cada versão publicada (instalador, PDBs e inventário de licenças), com um changelog que o launcher mostra numa tela de "Novidades". Limite quem pode publicar.

## 7. Falhas e suporte em campo

- **Relatório de falhas:** capture o despejo de memória do Windows e envie com **consentimento explícito**, sem dados pessoais, com os símbolos guardados. Ferramentas como Crashpad ou serviços como Sentry fazem isso; confira o custo e a licença.
- **Registros locais** com rotação e **sem** senhas, tokens nem dados de jogadores ocultos.
- **Botão "Exportar diagnóstico":** reúne versão, sistema, estado da ponte do LoL (da tela de diagnóstico da etapa 9) e últimos erros. Isso reduz muito o vai e vem no suporte.
- **Métricas anônimas e opcionais:** versões em uso, sucesso das atualizações, sessões sem falha.
- Um link de suporte dentro do app (e-mail ou Discord).

## 8. Primeira execução e instalação

- Instalar em pasta do usuário (sem administrador), atalhos e desinstalador que pergunta se remove os dados locais.
- Início automático com o Windows **desligado** por padrão.
- Termos de uso e política de privacidade na primeira execução, com registro do aceite (LGPD; detalhe na etapa 12).
- Tela "Sobre" completa (seção 1).
- O launcher só faz conexões de saída e fala com o cliente do LoL pelo próprio computador (127.0.0.1), então normalmente não aciona o firewall.

## 9. Lista de testes de distribuição

1. VM Windows 10 e 11 limpa: instalar, abrir, desinstalar, reinstalar.
2. **Atualizar a partir da versão anterior e de duas versões atrás.**
3. Atualização interrompida (cortar a rede, matar o processo) e pacote corrompido.
4. Pacote ou arquivo de atualização **adulterado** deve ser recusado.
5. Rejeição de versão antiga.
6. Usuário sem administrador.
7. Defender e SmartScreen ligados; comportamento com o Smart App Control.
8. Primeira execução sem internet.
9. **Nome de usuário ou pasta com acento ou espaço** (por exemplo `C:\Users\João`): é comum no Brasil e quebra muitos programas.
10. Escalas de tela de 125%, 150% e 200%, e vários monitores.
11. Máquina com pouca memória e disco lento.
12. Rede com proxy ou bloqueio, e relógio do sistema errado (quebra a validação de HTTPS).
13. Instalar e atualizar com o LoL aberto; confirmar que o atualizador **não** reinicia durante a seleção.
14. Verificar a assinatura de todos os binários e que não há DLLs de depuração.
15. Confirmar que os arquivos de licença e o aviso do Qt estão presentes.
16. Beta fechado com 3 a 5 pessoas antes do primeiro lançamento.

## 10. Ordem de trabalho com verificações

1. Definir a via de licença do Qt (LGPL com conformidade, ou comercial) e consultar um advogado.
2. Fixar a versão do Qt e do compilador, montar o build automático. Verificação: roda numa VM limpa (sem assinatura).
3. Metadados do executável, tela "Sobre" e inventário de licenças.
4. **Iniciar a compra do certificado agora** (prazo longo).
5. Protótipos de instalador e atualizador, comparando as opções (seção 3).
6. Assinar dentro do pipeline.
7. Rota de configuração na API (versão atual, mínima, interruptores, canais).
8. Atualizador no launcher com as regras de segurança.
9. Relatório de falhas e exportação de diagnóstico.
10. Checklist completa e beta fechado; depois o primeiro lançamento gradual.

## 11. Decisões que dependem de você

1. **Licença do Qt:** LGPL aberta (com as obrigações acima) ou comercial?
2. **Tecnologia de instalador e atualizador:** decidir depois dos protótipos?
3. **Certificado:** pessoa física ou empresa (CNPJ/MEI)? Token físico ou assinatura em nuvem? Qual autoridade?
4. **Canal beta:** entra no começo?
5. **Instalação por usuário** (recomendada) ou para todos os usuários da máquina?
6. **Atualização:** silenciosa com aviso ao reiniciar, ou sempre pedindo confirmação?
7. **Relatório de falhas e métricas:** com consentimento explícito? Qual serviço?
8. **Hospedagem dos downloads** (e do site de download, que precisa de política de privacidade).
9. **Microsoft Store:** descartar por ora (minha sugestão, por causa de LGPL e certificação)?
10. **Esquema de versionamento.**

## Onde estamos no mapa

Resta uma etapa, a **12 (produção)**: hospedagem da API e do banco, HTTPS, backups testados, monitoramento e alertas, limites de uso, política de privacidade e termos, LGPD e exclusão de dados a pedido, registro final do produto na Riot com a chave de produção (e RSO, se aprovado), custos e plano de lançamento em fases. Ela amarra tudo o que foi aberto ao longo das outras.

Quer que eu siga para a etapa 12? Se preferir, antes disso eu consolido numa só lista todas as decisões pendentes das etapas 4 a 11.