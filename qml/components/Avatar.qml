// Avatar circular (logo do time, ícone de invocador). `source` vazio => inicial.
import QtQuick
import Lider

Rectangle {
    id: root
    property string text: ""
    property url source: ""
    property int size: 48
    property color ring: Theme.gold

    width: size
    height: size
    radius: size / 2
    color: Theme.surfaceHi
    border.width: 2
    border.color: ring

    Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: root.text.length ? root.text.substring(0, root.size > 56 ? 3 : 1).toUpperCase() : "?"
        color: Theme.text
        font.pixelSize: root.size * (root.size > 56 ? 0.30 : 0.42)
        font.bold: true
    }
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 3
        visible: status === Image.Ready
        source: root.source
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)   // decodifica já reduzido (economiza RAM)
    }
}
