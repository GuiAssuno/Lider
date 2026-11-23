// Casca do app autenticado: barra lateral fixa + área de conteúdo com páginas sob demanda.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Item {
    id: root
    property bool userCollapsed: false
    // Se não houver time ativo, páginas que dependem dele mostram "NoTeamPage".
    readonly property string effectiveRoute:
        (Routes.requiresTeam(App.route) && App.activeTeamId === "") ? "noteam" : App.route

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.fillHeight: true
            collapsed: root.userCollapsed || root.width < 1100      // responsivo
            onEditProfile: profileDialog.open()
            onToggleCollapse: root.userCollapsed = true
            // Clicar no logo recolhido reexpande
            TapHandler { enabled: root.userCollapsed; onTapped: root.userCollapsed = false }
        }

        // Páginas são criadas apenas quando abertas (Loader) e destruídas ao sair:
        // memória baixa e inicialização rápida (RNF-L04).
        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: Routes.source(root.effectiveRoute)
            onLoaded: { fade.target = item; fade.restart() }
            NumberAnimation { id: fade; property: "opacity"; from: 0; to: 1; duration: Theme.mediumMs }
        }
    }

    ProfileDialog { id: profileDialog }
}
