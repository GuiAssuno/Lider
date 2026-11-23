// Gráfico radar (pentágono etc.). axes: [{label, value(0..100)}]
import QtQuick
import Lider

Canvas {
    id: root
    property var axes: []
    property color fillColor: Theme.accent

    onAxesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var n = axes ? axes.length : 0
        if (n < 3) return
        var cx = width / 2, cy = height / 2
        var r = Math.min(width, height) / 2 - 34
        if (r < 20) return
        function pt(i, k) {
            var a = -Math.PI / 2 + i * 2 * Math.PI / n
            return [cx + Math.cos(a) * r * k, cy + Math.sin(a) * r * k]
        }
        // grade (3 anéis)
        ctx.lineWidth = 1
        ctx.strokeStyle = Theme.alpha(Theme.accent, 0.28)
        for (var ring = 1; ring <= 3; ring++) {
            ctx.beginPath()
            for (var i = 0; i < n; i++) {
                var p = pt(i, ring / 3)
                if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1])
            }
            ctx.closePath(); ctx.stroke()
        }
        // eixos + rótulos
        ctx.font = "12px sans-serif"
        ctx.fillStyle = Theme.textDim
        ctx.textAlign = "center"
        for (var j = 0; j < n; j++) {
            var e = pt(j, 1), l = pt(j, 1.2)
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(e[0], e[1]); ctx.stroke()
            ctx.fillText(axes[j].label, l[0], l[1] + 4)
        }
        // polígono de dados
        ctx.beginPath()
        for (var k = 0; k < n; k++) {
            var q = pt(k, Math.max(0, Math.min(100, axes[k].value)) / 100)
            if (k === 0) ctx.moveTo(q[0], q[1]); else ctx.lineTo(q[0], q[1])
        }
        ctx.closePath()
        ctx.fillStyle = Theme.alpha(fillColor, 0.30); ctx.fill()
        ctx.lineWidth = 2; ctx.strokeStyle = fillColor; ctx.stroke()
        ctx.fillStyle = Theme.text
        for (var m = 0; m < n; m++) {
            var d = pt(m, Math.max(0, Math.min(100, axes[m].value)) / 100)
            ctx.beginPath(); ctx.arc(d[0], d[1], 3, 0, 2 * Math.PI); ctx.fill()
        }
    }
}
