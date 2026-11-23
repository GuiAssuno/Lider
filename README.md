# LÍDER Launcher — Frontend (Qt 6 / Qt Quick)

Frontend do launcher analítico de League of Legends, pronto para rodar com **dados mock**
e para ser integrado ao backend e à LCU API reais sem alterar nenhuma tela.

> Stack: **C++17 + Qt 6 (Qt Quick/QML, estilo Basic)** · CMake · sem dependências externas além do Qt.

## Como Compilar e executar
1. Instalar as ferramentas
a) Baixe [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) e marque "Desenvolvimento para desktop com C++".
b) Baixe [Qt](https://www.qt.io/development/download-qt-installer-oss) No instalador, marque:
   - Qt 6.7.x → MSVC 2019 64-bit (ou MSVC 2022 64-bit, conforme sua versão do VS)
   - Qt 6.7.x → Additional Libraries → Qt Quick 3D não é necessário, mas confirme que Qt Shader Tools está marcado
   - Developer and Designer Tools → CMake e Ninja 

2. Abrir o terminal
No menu Iniciar, procure **"x64 Native Tools Command Prompt for VS"** e abra. Use esse terminal, não o CMD comum.

3. Configurar 
```bash
set QT_DIR=[SEU_DIRETORIO_ONDE_SALVOU_AQUI]\Qt\6.12.0\msvc2022_64
set PATH=%QT_DIR%\bin;[SEU_DIRETORIO_ONDE_SALVOU_AQUI]\Qt\Tools\CMake_64\bin;E:\Qt\Tools\Ninja;%PATH%
 
cd /d [DIRETORIO_ONDE_ESTA_O_LAUNCHER_AQUI]
dir CMakeLists.txt
 
rmdir /s /q build
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=%QT_DIR%
cmake --build build
 
%QT_DIR%\bin\windeployqt.exe --qmldir qml build\lider.exe
build\lider.exe
```
4. Compilar
No mesmo terminal, execute:
```bash
cmake --build build
```
Espere aparecer Linking CXX executable lider.exe (leva de 1 a 3 minutos). Depois rode:
```bash
%QT_DIR%\bin\windeployqt.exe --qmldir qml build\lider.exe
build\lider.exe
```

## Como testar
1. **Login**: O launcher abre com uma tela de login. Entre com o ***e-mail:*** `teste@teste.com` e a ***senha:*** `1234`. E-mails contendo `novo` (ex.: `novo@x.com`) simulam o 1º acesso e pedem Nick/Tag/Região. "Entrar com Riot" entra direto.
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
