// Barra de progresso indeterminada. A animação só roda enquanto `running` (custo zero em repouso).
import QtQuick
import Lider

Item {
    id: root
    property bool running: false
    implicitHeight: 3
    height: 3
    clip: true
    opacity: running ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.mediumMs } }

    Rectangle {
        id: bar
        width: root.width * 0.3
        height: parent.height
        radius: 2
        color: Theme.accent
        SequentialAnimation on x {
            running: root.running
            loops: Animation.Infinite
            NumberAnimation { from: -bar.width; to: root.width; duration: 1000; easing.type: Easing.InOutQuad }
        }
    }
}
