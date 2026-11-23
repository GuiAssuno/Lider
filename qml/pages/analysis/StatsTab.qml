// Subguia "Estatísticas": métricas coletivas do time (RF-A07 / seção 4 da especificação).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    margin: 0
    readonly property var s: Analysis.data.stats
    readonly property var o: s.overview
    readonly property bool wide: width > 860

    // ---- KPIs ----
    GridLayout {
        Layout.fillWidth: true
        columns: root.wide ? 4 : 2
        columnSpacing: 14; rowSpacing: 14
        StatCard { label: "Taxa de Vitória"; value: o.winRate + "%"; delta: "+" + o.winRateDelta + "%"; tint: Theme.accent; glyph: Icons.glyph("trophy"); series: o.series.winRate }
        StatCard { label: "Controle de Objetivos"; value: o.objectiveControl + "%"; delta: "+" + o.objectiveControlDelta + "%"; tint: Theme.blue; glyph: Icons.glyph("counters"); series: o.series.objectiveControl }
        StatCard { label: "Ouro por Minuto"; value: (o.goldPerMin / 1000).toFixed(1) + "k"; delta: "+" + o.goldPerMinDelta + "%"; tint: Theme.gold; glyph: "●"; series: o.series.goldPerMin }
        StatCard { label: "Objetivos Conquistados"; value: o.objectives.toFixed(1); delta: "+" + o.objectivesDelta; tint: Theme.red; glyph: Icons.glyph("tower"); series: o.series.objectives }
    }

    // ---- Radar + marcos de objetivos ----
    GridLayout {
        Layout.fillWidth: true
        columns: root.wide ? 2 : 1
        columnSpacing: 14; rowSpacing: 14
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true
            title: "Perfil da equipe"; icon: Icons.glyph("analysis")
            RadarChart { Layout.fillWidth: true; Layout.preferredHeight: 250; axes: root.s.radar }
            Text { text: "KDA coletivo: " + root.o.kda + "  (+" + root.o.kdaDelta + ")"; color: Theme.textDim; font.pixelSize: Theme.fontSm }
        }
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true
            title: "Tempo médio dos marcos"; icon: Icons.glyph("fast")
            Repeater {
                model: root.s.milestones
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text { text: modelData.label; color: Theme.textDim; font.pixelSize: Theme.fontMd; Layout.fillWidth: true }
                    Text { text: modelData.time; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
                }
            }
        }
    }

    // ---- Melhores / piores (sinergias, composições, campeões) ----
    Repeater {
        model: [
            { title: "Sinergias", icon: "link", data: root.s.synergies },
            { title: "Composições", icon: "types", data: root.s.compositions },
            { title: "Campeões", icon: "kills", data: root.s.champions } ]
        delegate: NeonCard {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.title; icon: Icons.glyph(modelData.icon === "link" ? "teams" : modelData.icon)
            GridLayout {
                Layout.fillWidth: true
                columns: root.wide ? 2 : 1
                columnSpacing: 28; rowSpacing: 12
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                    Text { text: "MELHORES"; color: Theme.green; font.pixelSize: Theme.fontXs; font.bold: true }
                    RankList { items: modelData.data.best; valueColor: Theme.green }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                    Text { text: "PIORES"; color: Theme.red; font.pixelSize: Theme.fontXs; font.bold: true }
                    RankList { items: modelData.data.worst; valueColor: Theme.red }
                }
            }
        }
    }

    // ---- Macro: comebacks, throws, fechamento ----
    GridLayout {
        Layout.fillWidth: true
        columns: root.wide ? 3 : 1
        columnSpacing: 14; rowSpacing: 14
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true; accent: Theme.green
            title: "Fator Comeback"; icon: Icons.glyph("up")
            Text { text: root.s.comebacks.count + " viradas"; color: Theme.green; font.pixelSize: Theme.fontXl; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.s.comebacks.detail; color: Theme.textDim; font.pixelSize: Theme.fontSm }
            Text { text: "Campeões: " + root.s.comebacks.champions.join(", "); color: Theme.text; font.pixelSize: Theme.fontSm }
        }
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true; accent: Theme.red
            title: "Índice de Throw"; icon: Icons.glyph("warn")
            Text { text: root.s.throws.count + " throws (" + root.s.throws.rate + "%)"; color: Theme.red; font.pixelSize: Theme.fontXl; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.s.throws.detail; color: Theme.textDim; font.pixelSize: Theme.fontSm }
        }
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true; accent: Theme.blue
            title: "Eficiência de Fechamento"; icon: Icons.glyph("fast")
            Text { text: root.s.closing.avgMinutes + " min"; color: Theme.blue; font.pixelSize: Theme.fontXl; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.s.closing.detail + ". Média geral: " + root.s.closing.referenceMinutes + " min."; color: Theme.textDim; font.pixelSize: Theme.fontSm }
        }
    }

    // ---- Matchups por rota ----
    NeonCard {
        Layout.fillWidth: true
        title: "Matchups por rota"; icon: Icons.glyph("counters")
        DataTable {
            columns: [
                { key: "lane", title: "ROTA", weight: 1.1 },
                { key: "champion", title: "CAMPEÃO", weight: 1.3 },
                { key: "vs", title: "CONTRA", weight: 1.3 },
                { key: "winRate", title: "WIN RATE", weight: 1, align: "right", kind: "percent" },
                { key: "gd15", title: "GD@15", weight: 1, align: "right", kind: "signed" },
                { key: "csd15", title: "CSD@15", weight: 1, align: "right", kind: "signed" },
                { key: "games", title: "PARTIDAS", weight: 1, align: "right" } ]
            rows: root.s.matchups
        }
    }
}
