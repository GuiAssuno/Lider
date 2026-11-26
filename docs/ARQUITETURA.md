# Arquitetura, decisões e guia de integração

## 1. Por que Qt Quick (QML) + C++
A especificação lista **C++ com Qt6** como opção de launcher. Escolhi **Qt Quick** (e não Widgets) porque:
- renderização acelerada por GPU/scene graph, animações baratas e layouts responsivos nativos;
- UI declarativa e componentizada → fácil de escalar e de manter o visual neon dos mockups;
- C++ nas camadas de dados/integração (LCU, rede, cache) → consumo baixo de CPU/RAM (RNF-L04);
- um único executável nativo, sem runtime web (Electron) nem webview.

## 2. Camadas
```
 QML (qml/)  ──usa──▶  Controllers C++ (viewmodels/)  ──usam──▶  IBackendService / ILcuBridge (core/)
   telas, componentes      estado + regras de UI                     contratos assíncronos
                                                                              ▲
                                                           Mock* hoje  ·  Http*/Lcu* amanhã
```
- **QML não conhece rede nem LCU**: só lê propriedades dos controllers (`App`, `Analysis`, `Draft`, `Training`).
- **Controllers** (herdam `BaseController`: `loading`/`error`) guardam estado, validam entrada e chamam o contrato.
- **Contratos** são os únicos pontos que o backend real precisa implementar.
- `main.cpp` é o *composition root*: é o único lugar que escolhe as implementações concretas.

## 3. Performance e leveza
- Estilo **Basic** (o mais leve) com componentes 100% customizados; sem efeitos de sombra/blur em shader.
- **Páginas via `Loader`**: só a página aberta existe em memória; abas internas também são lazy.
- Animações só rodam quando necessário (ex.: `LoadingBar` e `ConfidenceRing` não animam em repouso).
- Imagens com `asynchronous` + `sourceSize` (decodificadas já reduzidas).
- Gráficos em `Canvas` redesenhados **apenas** quando os dados/tamanho mudam.
- Draft: *debounce* de 60 ms + número de sequência para descartar respostas atrasadas (RNF-D01).
- Janela sem moldura com redimensionamento/arraste pelo sistema (`startSystemMove/Resize`).
- Sidebar responsiva: recolhe automaticamente abaixo de 1100 px.

## 4. Integrar o backend real
1. Crie `src/services/HttpBackendService.{h,cpp}` herdando `IBackendService` (use `QNetworkAccessManager`, HTTPS).
2. Em cada método dispare a requisição e, ao concluir, emita `responseReady(Endpoint, payload)` com **o mesmo JSON**
   de `resources/mock/*.json`; em erro, `requestFailed(Endpoint, mensagem)`.
3. Em `main.cpp` troque `MockBackendService backend;` por `HttpBackendService backend;` e adicione o arquivo ao `CMakeLists.txt`.
4. Tokens/segredos: guarde com um cofre do SO (ex.: QtKeychain); nunca em `QSettings` em texto puro (RNF-L01).
5. Remova o recurso `mock_data` do CMake quando não precisar mais.

Mapa endpoint → payload esperado: ver comentários em `src/core/IBackendService.h`.
O `analyzeDraft` deve devolver o mesmo `seq` recebido.

## 5. Integrar a LCU API real
Implemente `LcuBridge : ILcuBridge` (ver cabeçalho `ILcuBridge.h`):
- detectar `LeagueClientUx.exe` e ler o *lockfile*; conectar por WebSocket seguro em `127.0.0.1`;
- assinar `/lol-champ-select/v1/session` e `/lol-gameflow/v1/gameflow-phase`;
- traduzir para o formato `session` documentado em `MockLcuBridge.cpp` (ids de campeão no padrão do Data Dragon);
- **somente leitura** (RNF-L05) — nenhuma escrita ao cliente.
- `gameEnded()` já dispara `syncMatchHistory` no backend (RF-L12). Troque no `main.cpp`.

## 6. Como estender (escalabilidade)
| Tarefa | Onde mexer |
|---|---|
| Nova tela | `qml/pages/NovaPage.qml` + `CMakeLists.txt` + entrada em `Routes.qml` (`pages` e `groups`) |
| Novo endpoint | novo valor em `Endpoint`, método no contrato, tratar em um controller |
| Novo módulo (ex.: Histórico) | novo controller herdando `BaseController` + registro em `main.cpp` |
| Branding/nome oficial | `Theme.qml` (cores/tokens) e textos "LÍDER" (Main/Sidebar/Login/TitleBar) |
| Ícones reais (SVG/fonte) | só `Icons.qml` |
| Ícones de campeões (Data Dragon) | preencher `source` em `ChampionIcon` (cache local, RNF-D03) |
| Idiomas | textos em português nas telas; strings C++ já usam `tr()` (adicionar `qsTr()` no QML ao internacionalizar) |

## 7. Rastreabilidade de requisitos
| Requisito | Situação |
|---|---|
| RF-L01/L02 login e vínculo Nick/Tag/Região | UI pronta (`LoginPage`); RSO real = backend |
| RF-L03/L04 perfil e edição | `Sidebar` + `ProfileDialog` |
| RF-L05/L06 navegação lateral | `Sidebar` + `Routes` |
| RF-L07..L10 times (CRUD, mín. 2, N membros, ativo) | `TeamsPage`, `TeamEditorDialog`, `AppController` |
| RF-L11/L12 LCU e sync ao fim da partida | contrato `ILcuBridge` + mock; selo de status |
| RNF-L02 logo PNG/JPG/WebP ≤ 2 MB | validado no cliente (`validateLogo`); **redimensionamento = backend/serviço de upload** |
| RNF-L03 trocar time sem novo login | `activeTeamChanging` propaga a todos os controllers |
| RNF-L04 baixo consumo | seção 3 |
| RNF-L06 auto-update | **não incluso** (empacotamento/instalador: Qt Installer Framework, Sparkle/WinSparkle etc.) |
| RF-A01..A08 análise do time | `AnalysisPage` + abas Geral/Estatísticas/Recordes + `PlayerDetail` |
| RF-D01..D09 draft | `Draft*Page`, `DraftController` (modos Ao Vivo/Manual, simulação, tipos, counters) |
| RF-T01..T03 treino | `TrainingDiagnosticPage`, `TrainingGoalsPage` |
| RNF-T01 clareza visual | `AlertRow`, `Sparkline`, referência do elo |

## 8. Decisões sobre divergências entre documentos
- **Subguias da Análise**: o wireframe mostra "Geral / Sinergia / Dado"; a especificação (RF-A04) define
  **Geral / Estatísticas / Recordes**. Segui a especificação (sinergias estão dentro de *Estatísticas*).
- **Barra lateral**: os mockups variam; usei os grupos da especificação (Launcher, Análise, Draft com 4 submódulos, Treino).
- **Nome/identidade**: "LÍDER" dos mockups usado como nome provisório (pendência do documento).

## 9. Limitações conhecidas
- Dados 100% simulados; regras de recomendação do mock são simplificadas (tabela de tags real = backend).
- Ícones são glifos Unicode (dependem das fontes do SO) — troque via `Icons.qml`.
- Imagens (logo/avatar) são recortadas em retângulo; círculo real exigiria máscara (custo de GPU) — avaliar depois.
- Testado compilando e executando com Qt 6.4.2 (Linux, offscreen). Não foi testado em Windows/macOS.
