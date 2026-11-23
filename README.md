# LÍDER Launcher — Frontend (Qt 6 / Qt Quick)

Frontend do launcher analítico de League of Legends, pronto para rodar com **dados mock**
e para ser integrado ao backend e à LCU API reais sem alterar nenhuma tela.

> Stack: **C++17 + Qt 6 (Qt Quick/QML, estilo Basic)** · CMake · sem dependências externas além do Qt.

## Requisitos
- Qt **6.4+** (recomendado 6.5+) com os módulos: Core, Gui, Qml, Quick, QuickControls2, QuickDialogs2
- CMake ≥ 3.21 e compilador C++17 (MSVC 2019+, GCC 10+, Clang 12+)

## Compilar e executar
```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/caminho/para/Qt/6.x.x/<kit>
cmake --build build --config Release
./build/lider            # Windows: build\Release\lider.exe
```
Com o Qt Creator: abra `CMakeLists.txt`, selecione um kit Qt 6 e execute.

## Como testar (modo mock)
1. **Login**: qualquer e-mail válido + senha com 4+ caracteres. E-mails contendo `novo` (ex.: `novo@x.com`)
   simulam o 1º acesso e pedem Nick/Tag/Região. "Entrar com Riot" entra direto.
2. **Meus Times**: criar/editar/excluir, logo (PNG/JPG/WebP ≤ 2 MB), mínimo de 2 jogadores, definir time ativo.
3. **Painel do Time**: subguias Geral / Estatísticas / Recordes; clique num jogador do elenco para o perfil individual.
4. **Draft > Composição**: clique em **Simular Draft** (20 passos na ordem oficial) ou use **Manual** e clique nos slots.
5. **Tipos de Times**, **Counters**, **Treino** (Diagnóstico, Metas e Evolução).
6. O selo no topo mostra o estado da ponte LCU (o mock "detecta o LoL" 1,5 s após o login e simula o fim de partida
   depois da simulação, disparando a sincronização do histórico).

### Modo QA (captura automática de telas)
```bash
./build/lider --route draft.composition --simulate --screenshot out.png --delay 15000
# em CI/servidor sem tela:  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ./build/lider ...
```

## Estrutura
```
src/core/        IBackendService.h, ILcuBridge.h      <- CONTRATOS (integração)
src/services/    MockBackendService, MockLcuBridge    <- implementações fake (trocar)
src/viewmodels/  App/Analysis/Draft/Training Controller (expostos ao QML)
resources/mock/  JSONs = contrato de dados da API
qml/theme/       Theme (tokens), Icons, Routes (navegação)
qml/components/  design system (NeonCard, DataTable, gráficos...)
qml/pages|dialogs  telas e modais
docs/ARQUITETURA.md  decisões, integração e rastreabilidade de requisitos
```
Leia **docs/ARQUITETURA.md** para o guia de integração com backend/LCU e para estender o app.
