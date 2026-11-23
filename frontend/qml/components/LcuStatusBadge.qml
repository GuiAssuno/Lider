// Indicador do estado da ponte com o cliente do LoL (RF-L11).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Rectangle {
    id: root
    readonly property var infos: ({
        disconnected: { text: "LoL fechado",           color: Theme.textMuted },
        connected:    { text: "LoL conectado",         color: Theme.green },
        champSelect:  { text: "Seleção de campeões",   color: Theme.accent },
        inGame:       { text: "Em partida",            color: Theme.gold },
        endOfGame:    { text: "Fim de partida",        color: Theme.blue }
    })
    readonly property var info: infos[App.lcuState] || infos.disconnected

    implicitHeight: 26
    implicitWidth: row.implicitWidth + 22
    radius: 13
    color: Theme.alpha(info.color, 0.12)
    border.width: 1
    border.color: Theme.alpha(info.color, 0.6)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Rectangle { width: 8; height: 8; radius: 4; color: root.info.color }
        Text { text: root.info.text; color: Theme.text; font.pixelSize: Theme.fontSm }
    }
}
