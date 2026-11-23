// Treino > Diagnóstico (RF-T01/T02): alertas coletivos e individuais, objetivos e acionáveis.
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
        PageHeader {
            title: "Diagnóstico de Performance"
            subtitle: "Gargalos detectados a partir das últimas partidas."
            NeonButton { text: "Atualizar"; glyph: Icons.glyph("refresh"); variant: "ghost"; onClicked: Training.reload() }
        }
        NeonCard {
            Layout.fillWidth: true
            title: "Diagnóstico da equipe"; icon: Icons.glyph("training"); accent: Theme.gold
            Repeater {
                model: Training.data.team || []
                delegate: AlertRow { required property var modelData; severity: modelData.severity; title: modelData.title; detail: modelData.detail }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 1000 ? 2 : 1
            columnSpacing: 14; rowSpacing: 14
            Repeater {
                model: Training.data.players || []
                delegate: NeonCard {
                    id: pc
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true
                    title: modelData.nick + " · " + modelData.role; icon: Icons.glyph("user")
                    Repeater {
                        model: pc.modelData.alerts
                        delegate: AlertRow { required property var modelData; severity: modelData.severity; title: modelData.title; detail: modelData.detail }
                    }
                }
            }
        }
    }
}
