// Item de navegação da barra lateral (ícone + rótulo). Em modo recolhido mostra só o ícone.
import QtQuick
import QtQuick.Layouts
import Lider

Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property bool selected: false
    property bool collapsed: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 42
    radius: 10
    color: selected ? Theme.alpha(Theme.accent, 0.22) : (ma.containsMouse ? Theme.alpha(Theme.accent, 0.10) : "transparent")
    border.width: selected ? 1 : 0
    border.color: Theme.alpha(Theme.borderHi, 0.8)
    Behavior on color { ColorAnimation { duration: Theme.fastMs } }

    // Barra de destaque à esquerda
    Rectangle {
        visible: root.selected
        width: 3; height: parent.height * 0.55; radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.accent
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.collapsed ? 0 : 14
        spacing: 12
        Item { visible: root.collapsed; Layout.fillWidth: true }
        Text {
            text: Icons.glyph(root.icon)
            color: root.selected ? Theme.text : Theme.accent
            font.pixelSize: 18
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            visible: !root.collapsed
            Layout.fillWidth: true
            text: root.label
            elide: Text.ElideRight
            color: root.selected ? Theme.text : Theme.textDim
            font.pixelSize: Theme.fontMd
            font.bold: root.selected
        }
        Item { visible: root.collapsed; Layout.fillWidth: true }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
