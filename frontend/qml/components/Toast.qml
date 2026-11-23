// Mensagem rápida (snackbar). Disparada por App.toast(msg) / App.notify(msg).
import QtQuick
import Lider
import Lider.Core

Rectangle {
    id: root
    property string message: ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28
    width: txt.implicitWidth + 40
    height: 40
    radius: 20
    color: Theme.surfaceHi
    border.width: 1
    border.color: Theme.borderHi
    opacity: 0
    visible: opacity > 0
    z: 1000

    Text { id: txt; anchors.centerIn: parent; text: root.message; color: Theme.text; font.pixelSize: Theme.fontMd }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Theme.mediumMs }
        PauseAnimation { duration: 2600 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 300 }
    }
    Connections {
        target: App
        function onToast(m) { root.message = m; anim.restart() }
    }
}
