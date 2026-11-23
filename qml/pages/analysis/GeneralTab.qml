// Subguia "Geral": índice de conjuntos de jogadores (RF-A06) e histórico (RF-A05).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    margin: 0
    readonly property var g: Analysis.data.general

    Text { text: g.season + " · somente partidas ranqueadas com 2+ membros juntos"; color: Theme.textDim; font.pixelSize: Theme.fontMd }

    // Um cartão por tamanho de conjunto (quinteto, quarteto, trio, duo)
    Repeater {
        model: root.g.groups
        delegate: NeonCard {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.label
            icon: Icons.glyph("teams")
            DataTable {
                columns: [
                    { key: "members", title: "JOGADORES", weight: 4 },
                    { key: "games", title: "PARTIDAS", weight: 1, align: "right" },
                    { key: "winRate", title: "WIN RATE", weight: 1, align: "right", kind: "percent" } ]
                rows: modelData.lineups
            }
        }
    }

    NeonCard {
        Layout.fillWidth: true
        title: "Partidas recentes"
        icon: Icons.glyph("analysis")
        DataTable {
            columns: [
                { key: "date", title: "DATA", weight: 1.2 },
                { key: "queue", title: "FILA", weight: 1.6 },
                { key: "members", title: "MEMBROS", weight: 1, align: "center" },
                { key: "result", title: "RESULTADO", weight: 1.2, kind: "result" },
                { key: "duration", title: "DURAÇÃO", weight: 1, align: "right" },
                { key: "score", title: "K/D/A", weight: 1.2, align: "right" } ]
            rows: root.g.matches
        }
    }
}
