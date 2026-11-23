// Análise do Time (RF-A01..A04): cabeçalho, elenco à esquerda, subguias à direita.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider
import Lider.Core

Item {
    id: root
    readonly property var members: Analysis.data.members || []
    property int tab: 0
    readonly property var tabFiles: ["analysis/GeneralTab.qml", "analysis/StatsTab.qml", "analysis/RecordsTab.qml"]

    Component.onCompleted: Analysis.ensureLoaded()

    LoadingBar { anchors { top: parent.top; left: parent.left; right: parent.right } running: Analysis.loading }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        // ---- Elenco (RF-A02) — clique abre o perfil individual (RF-A03) ----
        NeonCard {
            Layout.preferredWidth: root.width < 1100 ? 220 : 270
            Layout.fillHeight: true
            title: "Elenco"
            fillBody: true
            icon: Icons.glyph("teams")
            headerExtras: Text { text: root.members.length + " jogadores"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }

            ListView {
                id: roster
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.members
                delegate: Rectangle {
                    id: mrow
                    required property var modelData
                    width: roster.width
                    height: 58
                    radius: 10
                    color: Analysis.playerOpen && Analysis.player.id === modelData.id ? Theme.alpha(Theme.accent, 0.25)
                           : (ma.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.alpha(Theme.bg, 0.45))
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10
                        Avatar { size: 38; text: mrow.modelData.nick; ring: Theme.accent }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: mrow.modelData.nick; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: mrow.modelData.role + " · " + mrow.modelData.rank; color: Theme.textDim; font.pixelSize: Theme.fontXs; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Analysis.openPlayer(mrow.modelData.id) }
                }
            }
        }

        // ---- Conteúdo ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            TeamHeader {
                updatedAt: Analysis.data.updatedAt || ""
                onRefresh: Analysis.reload()
            }

            // Jogador aberto => tela individual; senão => subguias do time
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: Analysis.playerOpen
                visible: active
                source: "analysis/PlayerDetail.qml"
            }
            ColumnLayout {
                visible: !Analysis.playerOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                NeonTabBar { model: ["Geral", "Estatísticas", "Recordes"]; currentIndex: root.tab; onActivated: i => root.tab = i }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: Analysis.data.stats !== undefined
                    source: root.tabFiles[root.tab]
                }
            }
        }
    }
}
