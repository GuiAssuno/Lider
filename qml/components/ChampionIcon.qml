// Ícone de campeão. Hoje usa um placeholder colorido por id; para ícones reais do
// Data Dragon (RNF-D03) basta preencher `source` (URL/arquivo em cache local).
import QtQuick
import Lider

Rectangle {
    id: root
    property string championId: ""
    property string name: ""
    property url source: ""
    property int size: 48
    property bool banned: false
    property bool dimmed: false

    readonly property real hue: {
        var h = 0
        for (var i = 0; i < championId.length; i++) h = (h * 31 + championId.charCodeAt(i)) % 360
        return h / 360
    }
    readonly property bool empty: championId === ""

    width: size
    height: size
    radius: 8
    border.width: 1
    border.color: empty ? Theme.border : Theme.alpha(Theme.accent, 0.8)
    gradient: Gradient {
        GradientStop { position: 0.0; color: root.empty ? Theme.alpha(Theme.bg, 0.6) : Qt.hsla(root.hue, 0.55, 0.40, 1) }
        GradientStop { position: 1.0; color: root.empty ? Theme.alpha(Theme.bg, 0.6) : Qt.hsla(root.hue, 0.65, 0.16, 1) }
    }

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: root.empty ? "+" : root.name.substring(0, 2)
        color: root.empty ? Theme.textMuted : Theme.text
        font.pixelSize: root.size * 0.36
        font.bold: true
    }
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 1
        visible: status === Image.Ready
        source: root.source
        asynchronous: true
        sourceSize: Qt.size(root.size * 2, root.size * 2)
    }
    // Banido: escurece e risca
    Rectangle { anchors.fill: parent; radius: root.radius; color: "#000000"; opacity: root.banned || root.dimmed ? 0.55 : 0 }
    Rectangle {
        visible: root.banned && !root.empty
        anchors.centerIn: parent
        width: parent.width * 1.1; height: 2; rotation: -45; color: Theme.red
    }
}
