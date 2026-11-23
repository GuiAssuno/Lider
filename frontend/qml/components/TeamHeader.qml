// Cabeçalho fixo do time ativo: logo, nome, abreviação e botão atualizar (RF-A01).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Rectangle {
    id: root
    property string subtitle: "Análise completa da sua equipe"
    property string updatedAt: ""
    property bool showRefresh: true
    signal refresh()

    Layout.fillWidth: true
    implicitHeight: 92
    radius: Theme.radius
    border.width: 1
    border.color: Theme.alpha(Theme.borderHi, 0.6)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.surfaceHi }
        GradientStop { position: 1.0; color: Theme.surface }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        Avatar { size: 60; text: App.activeTeam.tag || "?"; source: App.activeTeam.logoPath || "" }
        ColumnLayout {
            spacing: 2
            RowLayout {
                spacing: 10
                Text { text: App.activeTeam.name || "—"; color: Theme.text; font.pixelSize: Theme.fontXl; font.bold: true }
                Rectangle {
                    implicitWidth: tagTxt.implicitWidth + 16; implicitHeight: 22; radius: 11
                    color: Theme.alpha(Theme.accent, 0.25); border.width: 1; border.color: Theme.accent
                    Text { id: tagTxt; anchors.centerIn: parent; text: App.activeTeam.tag || ""; color: Theme.textDim; font.pixelSize: Theme.fontSm; font.bold: true }
                }
            }
            Text { text: root.subtitle; color: Theme.textDim; font.pixelSize: Theme.fontMd }
        }
        Item { Layout.fillWidth: true }
        ColumnLayout {
            visible: root.updatedAt !== ""
            spacing: 0
            Text { text: "Última atualização"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
            Text { text: root.updatedAt; color: Theme.textDim; font.pixelSize: Theme.fontSm }
        }
        NeonButton { visible: root.showRefresh; text: "Atualizar"; glyph: Icons.glyph("refresh"); onClicked: root.refresh() }
    }
}
