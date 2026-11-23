// Draft > Tipos de Times (RF-D08): arquétipos, condição de vitória e taxa de sucesso do time.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    readonly property var list: Draft.catalog.archetypes || []
    readonly property real best: Math.max.apply(null, list.map(a => a.winRate).concat([0]))
    readonly property real worst: Math.min.apply(null, list.map(a => a.winRate).concat([100]))
    Component.onCompleted: Draft.ensureLoaded()

    PageHeader { title: "Tipos de Times"; subtitle: "Qual estilo de jogo a sua equipe executa melhor — e qual deve evitar." }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 900 ? 2 : 1
        columnSpacing: 14; rowSpacing: 14
        Repeater {
            model: root.list
            delegate: NeonCard {
                id: card
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                accent: modelData.winRate === root.best ? Theme.green : (modelData.winRate === root.worst ? Theme.red : Theme.accent)
                title: modelData.name; icon: Icons.glyph("types")
                headerExtras: Text {
                    visible: card.modelData.winRate === root.best || card.modelData.winRate === root.worst
                    text: card.modelData.winRate === root.best ? "MELHOR MODELO" : "EVITAR"
                    color: card.modelData.winRate === root.best ? Theme.green : Theme.red
                    font.pixelSize: Theme.fontXs; font.bold: true
                }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: card.modelData.description; color: Theme.textDim; font.pixelSize: Theme.fontMd }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Condição de vitória: " + card.modelData.winCondition; color: Theme.text; font.pixelSize: Theme.fontSm }
                BarRow { label: "Win rate"; value: card.modelData.winRate; barColor: card.modelData.winRate >= 50 ? Theme.green : Theme.red }
                Text { text: card.modelData.games + " partidas do time"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
            }
        }
    }
}
