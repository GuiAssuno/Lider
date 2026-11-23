// Estado vazio padrão: ícone, título, descrição e ação opcional.
import QtQuick
import QtQuick.Layouts
import Lider

ColumnLayout {
    id: root
    property string glyph: "◎"
    property string title: ""
    property string description: ""
    property string actionText: ""
    signal actionClicked()
    spacing: 10

    Text { Layout.alignment: Qt.AlignHCenter; text: root.glyph; color: Theme.accent; font.pixelSize: 48 }
    Text { Layout.alignment: Qt.AlignHCenter; text: root.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 420
        text: root.description
        color: Theme.textDim
        font.pixelSize: Theme.fontMd
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
    NeonButton {
        visible: root.actionText !== ""
        Layout.alignment: Qt.AlignHCenter
        text: root.actionText
        onClicked: root.actionClicked()
    }
}
