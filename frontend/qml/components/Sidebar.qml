// Barra lateral fixa (RF-L05): marca, perfil, navegação por grupos, rodapé.
// Os itens vêm de Routes.groups — nada de rota hardcoded aqui.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Rectangle {
    id: root
    property bool collapsed: false
    signal editProfile()
    signal toggleCollapse()

    implicitWidth: collapsed ? 76 : 264
    Behavior on implicitWidth { NumberAnimation { duration: Theme.mediumMs; easing.type: Easing.OutCubic } }
    color: Theme.alpha(Theme.bg, 0.92)

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.alpha(Theme.borderHi, 0.5) }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ---- Marca ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Text { text: Icons.glyph("brand"); color: Theme.gold; font.pixelSize: 24; Layout.leftMargin: root.collapsed ? 20 : 6 }
            Text {
                visible: !root.collapsed
                text: "LÍDER"; color: Theme.text
                font.pixelSize: 26; font.bold: true; font.italic: true; font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: !root.collapsed
                text: Icons.glyph("collapse"); color: Theme.textDim; font.pixelSize: 18
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleCollapse() }
            }
        }
        Text {
            visible: !root.collapsed
            text: "ANALISE • TREINE • EVOLUA"; color: Theme.textMuted
            font.pixelSize: 9; font.letterSpacing: 2; Layout.leftMargin: 6
        }

        // ---- Perfil (clique abre a edição — RF-L04) ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 12
            color: pma.containsMouse ? Theme.alpha(Theme.accent, 0.2) : Theme.alpha(Theme.surfaceHi, 0.7)
            border.width: 1; border.color: Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Item { visible: root.collapsed; Layout.fillWidth: true }
                Avatar { size: 38; text: App.profile.nick || "?"; source: App.profile.iconUrl || "" }
                ColumnLayout {
                    visible: !root.collapsed
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: (App.profile.nick || "—") + "#" + (App.profile.tag || ""); color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: "LVL " + (App.profile.level || 0) + " · " + (App.profile.region || ""); color: Theme.textDim; font.pixelSize: Theme.fontXs }
                }
                Text { visible: !root.collapsed; text: Icons.glyph("edit"); color: Theme.accent; font.pixelSize: 16 }
                Item { visible: root.collapsed; Layout.fillWidth: true }
            }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editProfile() }
        }

        // ---- Navegação (rolável em janelas baixas) ----
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: nav.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: nav
                width: parent.width
                spacing: 4
                Repeater {
                    model: Routes.groups
                    delegate: ColumnLayout {
                        id: grp
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            visible: !root.collapsed
                            Layout.topMargin: 10
                            Layout.leftMargin: 6
                            text: grp.modelData.title
                            color: Theme.accent
                            font.pixelSize: Theme.fontSm; font.bold: true; font.letterSpacing: 1
                        }
                        Rectangle { visible: root.collapsed; Layout.fillWidth: true; Layout.topMargin: 6; height: 1; color: Theme.border }
                        Repeater {
                            model: grp.modelData.items
                            delegate: SidebarItem {
                                required property var modelData
                                label: modelData.label
                                icon: modelData.icon
                                collapsed: root.collapsed
                                selected: App.route === modelData.route
                                onClicked: App.navigate(modelData.route)
                            }
                        }
                    }
                }
            }
        }

        // ---- Rodapé ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle { visible: !root.collapsed; width: 9; height: 9; radius: 5; color: Theme.green }
            Text { visible: !root.collapsed; Layout.fillWidth: true; text: "Versão " + App.version; color: Theme.textMuted; font.pixelSize: Theme.fontXs; elide: Text.ElideRight }
            Item { visible: root.collapsed; Layout.fillWidth: true }
            Text {
                text: Icons.glyph("settings"); color: Theme.accent; font.pixelSize: 20
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: App.notify("Configurações: em breve.") }
            }
            Text {
                text: Icons.glyph("logout"); color: Theme.textDim; font.pixelSize: 20
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: App.logout() }
            }
            Item { visible: root.collapsed; Layout.fillWidth: true }
        }
    }
}
