# =============================================================================
#  LÍDER Launcher — Frontend (Qt 6 / Qt Quick)
#  Requisitos: CMake >= 3.21, Qt >= 6.4 (recomendado 6.5+), compilador C++17
# =============================================================================
cmake_minimum_required(VERSION 3.21)
project(LiderLauncher VERSION 1.2.2.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)

# ----------------------------------------------------------------------------
#  Código C++ — separado em camadas (ver docs/ARQUITETURA.md)
#    core/        contratos (interfaces) que o backend/LCU reais devem cumprir
#    services/    implementações (HTTP real, roteador, cofre de tokens e MOCK)
#    viewmodels/  controllers expostos ao QML
# ----------------------------------------------------------------------------
qt_add_executable(lider
    src/main.cpp
    src/core/IBackendService.h
    src/core/ILcuBridge.h
    src/services/TokenStore.h
    src/services/TokenStore.cpp
    src/services/HttpBackendService.h
    src/services/HttpBackendService.cpp
    src/services/RoutedBackendService.h
    src/services/RoutedBackendService.cpp
    src/services/MockBackendService.h
    src/services/MockBackendService.cpp
    src/services/MockLcuBridge.h
    src/services/MockLcuBridge.cpp
    src/viewmodels/BaseController.h
    src/viewmodels/AppController.h
    src/viewmodels/AppController.cpp
    src/viewmodels/AnalysisController.h
    src/viewmodels/AnalysisController.cpp
    src/viewmodels/DraftController.h
    src/viewmodels/DraftController.cpp
    src/viewmodels/TrainingController.h
    src/viewmodels/TrainingController.cpp
)
target_include_directories(lider PRIVATE src)
target_compile_definitions(lider PRIVATE LIDER_VERSION="${PROJECT_VERSION}")

# ----------------------------------------------------------------------------
#  Dados mock (JSON) embutidos no executável. Remova quando o backend real
#  estiver integrado — o formato dos JSONs é o contrato esperado da API.
# ----------------------------------------------------------------------------
qt_add_resources(lider "mock_data"
    PREFIX "/mock"
    BASE "resources/mock"
    FILES
        resources/mock/teams.json
        resources/mock/analysis.json
        resources/mock/players.json
        resources/mock/draft.json
        resources/mock/training.json
)

# ----------------------------------------------------------------------------
#  Módulo QML "Lider" — singletons (tema/ícones/rotas), componentes, páginas.
# ----------------------------------------------------------------------------
set(LIDER_SINGLETONS
    qml/theme/Theme.qml
    qml/theme/Icons.qml
    qml/theme/Routes.qml
)
set_source_files_properties(${LIDER_SINGLETONS} PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(lider
    URI Lider
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        ${LIDER_SINGLETONS}
        qml/Main.qml
        qml/Shell.qml
        # --- componentes reutilizáveis ---
        qml/components/AlertRow.qml
        qml/components/Avatar.qml
        qml/components/BarRow.qml
        qml/components/ChampionIcon.qml
        qml/components/ConfidenceRing.qml
        qml/components/DataTable.qml
        qml/components/EmptyState.qml
        qml/components/LcuStatusBadge.qml
        qml/components/LoadingBar.qml
        qml/components/NeonButton.qml
        qml/components/NeonCard.qml
        qml/components/NeonPopup.qml
        qml/components/NeonTabBar.qml
        qml/components/NeonTextField.qml
        qml/components/PageHeader.qml
        qml/components/RadarChart.qml
        qml/components/RankList.qml
        qml/components/ResizeHandles.qml
        qml/components/ScrollPage.qml
        qml/components/Sidebar.qml
        qml/components/SidebarItem.qml
        qml/components/Sparkline.qml
        qml/components/StatCard.qml
        qml/components/TeamHeader.qml
        qml/components/TitleBar.qml
        qml/components/Toast.qml
        # --- diálogos ---
        qml/dialogs/ChampionPicker.qml
        qml/dialogs/ConfirmDialog.qml
        qml/dialogs/ProfileDialog.qml
        qml/dialogs/TeamEditorDialog.qml
        # --- páginas ---
        qml/pages/LoginPage.qml
        qml/pages/TeamsPage.qml
        qml/pages/NoTeamPage.qml
        qml/pages/AnalysisPage.qml
        qml/pages/analysis/GeneralTab.qml
        qml/pages/analysis/StatsTab.qml
        qml/pages/analysis/RecordsTab.qml
        qml/pages/analysis/PlayerDetail.qml
        qml/pages/DraftCompositionPage.qml
        qml/pages/DraftSimulationPage.qml
        qml/pages/DraftArchetypesPage.qml
        qml/pages/DraftCountersPage.qml
        qml/pages/TrainingDiagnosticPage.qml
        qml/pages/TrainingGoalsPage.qml
)

target_link_libraries(lider PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network)
if (WIN32)
    target_link_libraries(lider PRIVATE Advapi32)
endif()

# Aplicação gráfica (sem console no Windows)
set_target_properties(lider PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)
