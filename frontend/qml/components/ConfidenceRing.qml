// Anel de confiança (0..100) usado na classificação de composição (RF-D04).
import QtQuick
import Lider

Item {
    id: root
    property real value: 0
    property string caption: "Confiança"
    property color ringColor: Theme.teal
    implicitWidth: 120
    implicitHeight: 120

    // Valor animado: o Canvas redesenha só durante a transição.
    property real shown: 0
    Behavior on shown { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    onValueChanged: shown = value
    onShownChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = Math.min(width, height) / 2 - 8, cx = width / 2, cy = height / 2
            ctx.lineWidth = 9; ctx.lineCap = "round"
            ctx.strokeStyle = Theme.alpha(Theme.border, 0.7)
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke()
            if (root.shown > 0) {
                ctx.strokeStyle = root.ringColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * root.shown / 100)
                ctx.stroke()
            }
        }
    }
    Column {
        anchors.centerIn: parent
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(root.value) + "%"; color: Theme.text; font.pixelSize: 24; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.caption; color: Theme.textDim; font.pixelSize: Theme.fontXs }
    }
}
