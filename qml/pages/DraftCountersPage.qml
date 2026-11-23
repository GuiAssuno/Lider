// Draft > Counters (RF-D09): matchups com win rate, GD@15 e CSD@15.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    property int sel: 0
    readonly property var list: Draft.catalog.counters || []
    readonly property var current: list.length > sel ? list[sel] : null
    Component.onCompleted: Draft.ensureLoaded()

    PageHeader { title: "Counters e Matchups"; subtitle: "Pressão de rota e taxa de vitória combinando dados globais e histórico do time." }

    NeonTabBar { visible: root.list.length > 0; model: root.list.map(c => c.champion); currentIndex: root.sel; onActivated: i => root.sel = i }

    NeonCard {
        visible: root.current !== null
        Layout.fillWidth: true
        title: root.current ? root.current.champion + " · " + root.current.role : ""
        icon: Icons.glyph("counters")
        DataTable {
            columns: [
                { key: "vs", title: "CONTRA", weight: 2 },
                { key: "winRate", title: "WIN RATE", weight: 1, align: "right", kind: "percent" },
                { key: "gd15", title: "GD@15", weight: 1, align: "right", kind: "signed" },
                { key: "csd15", title: "CSD@15", weight: 1, align: "right", kind: "signed" },
                { key: "games", title: "PARTIDAS", weight: 1, align: "right" } ]
            rows: root.current ? root.current.matchups : []
        }
        Text { text: "GD@15 = diferença de ouro aos 15 min · CSD@15 = diferença de farm aos 15 min"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
    }
}
