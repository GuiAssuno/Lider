pragma Singleton
// =============================================================================
//  Routes — tabela de navegação (fonte única da barra lateral e do roteamento)
// =============================================================================
//  Para ADICIONAR uma nova tela:
//    1) crie qml/pages/MinhaPage.qml e registre em CMakeLists.txt (QML_FILES);
//    2) adicione-a em `pages` (arquivo + requiresTeam);
//    3) adicione um item em `groups` para aparecer na barra lateral.
// =============================================================================
import QtQuick

QtObject {
    /// rota -> { file, requiresTeam }
    readonly property var pages: ({
        "teams":               { file: "TeamsPage.qml",              requiresTeam: false },
        "analysis":            { file: "AnalysisPage.qml",           requiresTeam: true  },
        "draft.composition":   { file: "DraftCompositionPage.qml",   requiresTeam: true  },
        "draft.simulation":    { file: "DraftSimulationPage.qml",    requiresTeam: true  },
        "draft.archetypes":    { file: "DraftArchetypesPage.qml",    requiresTeam: true  },
        "draft.counters":      { file: "DraftCountersPage.qml",      requiresTeam: true  },
        "training.diagnostic": { file: "TrainingDiagnosticPage.qml", requiresTeam: true  },
        "training.goals":      { file: "TrainingGoalsPage.qml",      requiresTeam: true  },
        "noteam":              { file: "NoTeamPage.qml",             requiresTeam: false }
    })

    /// Estrutura da barra lateral (RF-L05 / RF-D01).
    readonly property var groups: [
        { title: "LAUNCHER", items: [
            { route: "teams", label: "Meus Times", icon: "teams" } ] },
        { title: "ANÁLISE DE EQUIPE", items: [
            { route: "analysis", label: "Painel do Time", icon: "analysis" } ] },
        { title: "DRAFT", items: [
            { route: "draft.composition", label: "Composição",     icon: "compose"  },
            { route: "draft.simulation",  label: "Simulação",      icon: "simulate" },
            { route: "draft.archetypes",  label: "Tipos de Times", icon: "types"    },
            { route: "draft.counters",    label: "Counters",       icon: "counters" } ] },
        { title: "TREINO", items: [
            { route: "training.diagnostic", label: "Diagnóstico",       icon: "training" },
            { route: "training.goals",      label: "Metas e Evolução",  icon: "goals"    } ] }
    ]

    function source(route) {
        var p = pages[route]
        return p ? Qt.resolvedUrl("../pages/" + p.file) : ""
    }
    function requiresTeam(route) {
        var p = pages[route]
        return p ? p.requiresTeam : false
    }
}
