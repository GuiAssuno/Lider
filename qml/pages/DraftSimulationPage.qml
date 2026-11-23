// Draft > Simulação (RF-D07): percorre a ORDEM OFICIAL de bans/picks (RF-D02).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    readonly property var order: Draft.catalog.order || []
    Component.onCompleted: Draft.ensureLoaded()

    PageHeader {
        title: "Simulação de Draft"
        subtitle: "Treine a sequência oficial de bans e picks com a sua equipe."
        NeonButton { text: "Ver composição"; variant: "ghost"; onClicked: App.navigate("draft.composition") }
        NeonButton { text: Draft.simulating ? "Reiniciar" : "Iniciar simulação"; glyph: Icons.glyph("simulate"); onClicked: Draft.runSimulation() }
    }

    NeonCard {
        Layout.fillWidth: true
        title: "Progresso"; icon: Icons.glyph("simulate")
        BarRow { label: "Passos"; value: Draft.currentStep; maxValue: 20; valueText: Draft.currentStep + "/20"; barColor: Theme.accent }
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout { Text { text: "Seu time"; color: Theme.textMuted; font.pixelSize: Theme.fontXs } Text { text: Draft.analysis.allyType || "—"; color: Theme.blue; font.pixelSize: Theme.fontXl; font.bold: true } }
            ColumnLayout { Text { text: "Inimigo"; color: Theme.textMuted; font.pixelSize: Theme.fontXs } Text { text: Draft.analysis.enemyType || "—"; color: Theme.red; font.pixelSize: Theme.fontXl; font.bold: true } }
        }
    }

    NeonCard {
        Layout.fillWidth: true
        title: "Ordem oficial do draft"; icon: Icons.glyph("types")
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.order
                delegate: Rectangle {
                    id: chip
                    required property int index
                    required property string modelData
                    readonly property var tok: modelData.split(":")
                    readonly property bool blue: tok[0] === "B"
                    readonly property bool done: index < Draft.currentStep
                    readonly property bool current: Draft.simulating && index === Draft.currentStep
                    width: 138; height: 40; radius: 9
                    color: done ? Theme.alpha(blue ? Theme.blue : Theme.red, 0.22) : Theme.alpha(Theme.bg, 0.5)
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.gold : Theme.alpha(blue ? Theme.blue : Theme.red, 0.55)
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: (chip.index + 1) + "."; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                        Text { text: (chip.blue ? "Azul" : "Vermelho") + " · " + (chip.tok[1] === "ban" ? "Ban" : "Pick"); color: chip.done ? Theme.text : Theme.textDim; font.pixelSize: Theme.fontSm; font.bold: chip.done }
                    }
                }
            }
        }
        Text { text: "Lado azul = time aliado. A simulação usa o mesmo motor de composição do draft ao vivo."; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
    }
}
