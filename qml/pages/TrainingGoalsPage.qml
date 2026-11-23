// Treino > Metas e Evolução (RF-T03, RNF-T01/T02): metas acompanháveis e histórico vs. referência do elo.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Item {
    id: root
    Component.onCompleted: Training.ensureLoaded()
    LoadingBar { anchors { top: parent.top; left: parent.left; right: parent.right } running: Training.loading }

    ScrollPage {
        anchors.fill: parent
        PageHeader { title: "Metas e Evolução"; subtitle: "Acompanhe o progresso das metas individuais e coletivas." }

        NeonCard {
            Layout.fillWidth: true
            title: "Metas de treino"; icon: Icons.glyph("goals"); accent: Theme.gold
            Repeater {
                model: Training.data.goals || []
                delegate: RowLayout {
                    id: gr
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: gr.modelData.done ? Theme.green : "transparent"
                        border.width: 2; border.color: gr.modelData.done ? Theme.green : Theme.textMuted
                        Text { anchors.centerIn: parent; visible: gr.modelData.done; text: "✔"; color: Theme.bg; font.pixelSize: 15; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Training.toggleGoal(gr.modelData.id) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Text { text: gr.modelData.title; color: gr.modelData.done ? Theme.textMuted : Theme.text; font.pixelSize: Theme.fontMd; font.strikeout: gr.modelData.done }
                            Rectangle {
                                implicitWidth: sc.implicitWidth + 14; implicitHeight: 20; radius: 10
                                color: Theme.alpha(Theme.accent, 0.2)
                                Text { id: sc; anchors.centerIn: parent; text: gr.modelData.scope; color: Theme.textDim; font.pixelSize: Theme.fontXs }
                            }
                        }
                        BarRow {
                            label: ""; labelWidth: 0
                            value: gr.modelData.current; maxValue: gr.modelData.target
                            valueText: gr.modelData.current + " / " + gr.modelData.target + " " + gr.modelData.unit
                            barColor: gr.modelData.done ? Theme.green : Theme.accent
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 900 ? 2 : 1
            columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: Training.data.evolution || []
                delegate: NeonCard {
                    id: ec
                    required property var modelData
                    readonly property real last: modelData.points[modelData.points.length - 1]
                    readonly property bool lowerBetter: modelData.key === "throw"
                    readonly property bool good: lowerBetter ? last <= modelData.benchmark : last >= modelData.benchmark
                    Layout.fillWidth: true
                    title: modelData.label; icon: Icons.glyph("up"); accent: good ? Theme.green : Theme.gold
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ec.last + ec.modelData.unit; color: Theme.text; font.pixelSize: Theme.fontHuge; font.bold: true }
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            Text { text: "Referência do elo"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
                            Text { text: ec.modelData.benchmark + ec.modelData.unit; color: ec.good ? Theme.green : Theme.gold; font.pixelSize: Theme.fontLg; font.bold: true }
                        }
                    }
                    Sparkline { Layout.fillWidth: true; Layout.preferredHeight: 70; values: ec.modelData.points; lineColor: ec.good ? Theme.green : Theme.gold }
                }
            }
        }
    }
}
