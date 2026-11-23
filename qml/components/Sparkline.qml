// Mini-gráfico de linha (Canvas). Redesenha apenas quando dados/tamanho mudam.
import QtQuick
import Lider

Canvas {
    id: root
    property var values: []
    property color lineColor: Theme.accent
    property bool filled: true

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var v = values
        if (!v || v.length < 2 || width < 4) return
        var min = Math.min.apply(null, v), max = Math.max.apply(null, v)
        var rng = (max - min) || 1, pad = 3
        var w = width - pad * 2, h = height - pad * 2
        function px(i) { return pad + w * i / (v.length - 1) }
        function py(x) { return pad + h - h * (x - min) / rng }

        ctx.beginPath()
        ctx.moveTo(px(0), py(v[0]))
        for (var i = 1; i < v.length; i++) ctx.lineTo(px(i), py(v[i]))
        ctx.lineWidth = 2
        ctx.strokeStyle = lineColor
        ctx.stroke()
        if (filled) {
            ctx.lineTo(px(v.length - 1), height)
            ctx.lineTo(px(0), height)
            ctx.closePath()
            ctx.fillStyle = Theme.alpha(lineColor, 0.16)
            ctx.fill()
        }
    }
}
