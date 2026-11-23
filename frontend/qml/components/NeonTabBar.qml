// Barra de abas/segmentos. Uso: NeonTabBar { model: ["Geral","Estatísticas"]; onActivated: i => ... }
import QtQuick
import Lider

Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: 44
    implicitWidth: row.implicitWidth + 12
    radius: 12
    color: Theme.alpha(Theme.bg, 0.65)
    border.width: 1
    border.color: Theme.border

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: root.model
            delegate: Rectangle {
                id: tab
                required property int index
                required property var modelData
                width: lbl.implicitWidth + 36
                height: 34
                radius: 9
                color: root.currentIndex === index ? Theme.accentStrong
                       : (ma.containsMouse ? Theme.alpha(Theme.accent, 0.22) : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.fastMs } }
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: tab.modelData
                    font.pixelSize: Theme.fontMd
                    font.bold: root.currentIndex === tab.index
                    color: root.currentIndex === tab.index ? Theme.text : Theme.textDim
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentIndex = tab.index; root.activated(tab.index) }
                }
            }
        }
    }
}
