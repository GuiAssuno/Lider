pragma Singleton
// =============================================================================
//  Icons — mapa nome -> glifo. Ponto ÚNICO para trocar por SVG/fonte de ícones
//  (ex.: Material Symbols) sem alterar nenhuma tela: basta mudar `glyph()`.
// =============================================================================
import QtQuick

QtObject {
    readonly property var map: ({
        brand: "♛", teams: "☰", analysis: "▤", compose: "♞", simulate: "▶",
        types: "◆", counters: "⚔", training: "◎", goals: "★", settings: "⚙",
        edit: "✎", close: "✕", minimize: "–", maximize: "▢", restore: "❐",
        check: "✔", warn: "⚠", info: "ℹ", refresh: "⟳", add: "+", logout: "⎋",
        back: "←", collapse: "«", expand: "»", trophy: "♕", up: "▲", down: "▼",
        baron: "♛", kills: "✦", kda: "✚", fast: "⚡", tower: "♜", spree: "☠", user: "●"
    })
    function glyph(name) { return map[name] !== undefined ? map[name] : "?" }
}
