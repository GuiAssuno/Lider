pragma Singleton
// =============================================================================
//  Theme — design tokens do launcher (cores, espaçamentos, tipografia, tempos)
// =============================================================================
//  TODA cor/medida do app deve vir daqui. Para alterar a identidade visual
//  (ex.: novo nome/branding — pendência 6 do documento de especificação),
//  basta editar este arquivo.
// =============================================================================
import QtQuick

QtObject {
    // ---- Paleta neon (baseada nos mockups) ----
    readonly property color bg:           "#060313"
    readonly property color bgAlt:        "#0b0728"
    readonly property color surface:      "#0f0b2b"
    readonly property color surfaceHi:    "#181344"
    readonly property color border:       "#2a2072"
    readonly property color borderHi:     "#6d4aff"
    readonly property color accent:       "#8b5cf6"
    readonly property color accentStrong: "#6d28d9"
    readonly property color blue:         "#3b82f6"
    readonly property color gold:         "#f5b83d"
    readonly property color red:          "#ef4444"
    readonly property color green:        "#22c55e"
    readonly property color teal:         "#14d8b4"
    readonly property color text:         "#f4f1ff"
    readonly property color textDim:      "#aaa3dd"
    readonly property color textMuted:    "#6e68a3"

    // ---- Espaçamento e forma ----
    readonly property int pad: 16
    readonly property int gap: 12
    readonly property int radius: 12

    // ---- Tipografia (px) ----
    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 14
    readonly property int fontLg: 18
    readonly property int fontXl: 26
    readonly property int fontHuge: 34

    // ---- Animações (curtas = UI responsiva e leve) ----
    readonly property int fastMs: 120
    readonly property int mediumMs: 200

    /// Retorna a cor `c` com opacidade `a` (0..1). Aceita string ou color.
    function alpha(c, a) {
        var k = Qt.lighter(c, 1.0)
        return Qt.rgba(k.r, k.g, k.b, a)
    }
    /// Cor semântica por severidade de alertas (Treino/Draft).
    function severityColor(sev) {
        switch (sev) {
        case "critical": return red
        case "warning":  return gold
        case "ok":       return green
        default:         return blue
        }
    }
    function severityGlyph(sev) {
        switch (sev) {
        case "critical": return "⚠"
        case "warning":  return "⚠"
        case "ok":       return "✔"
        default:         return "ℹ"
        }
    }
}
