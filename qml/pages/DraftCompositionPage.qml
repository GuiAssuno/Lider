// Draft > Composição (RF-D02..D06): picks/bans, tipo de comp., sugestões e insights.
// Modo "Ao Vivo": sincroniza com a LCU. Modo "Manual": clique nos slots para escolher.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Item {
    id: root
    readonly property var d: Draft.draft
    readonly property var a: Draft.analysis
    readonly property var roles: ["Topo", "Selva", "Meio", "Atirador", "Suporte"]
    readonly property bool editable: Draft.mode === "manual" && !Draft.simulating
    readonly property var allyMembers: App.activeTeam.members || []

    Component.onCompleted: Draft.ensureLoaded()

    function mmss(s) { return "00:" + (s < 10 ? "0" : "") + s }
    function champName(id) { var c = Draft.champion(id); return c.name || "" }

    // Slot reutilizável (ban ou pick)
    component Slot: ChampionIcon {
        id: slot
        property string side: "ally"
        property string kind: "picks"
        property int slotIndex: 0
        property string role: ""
        readonly property string cid: root.d[side][kind][slotIndex] || ""
        championId: cid
        name: root.champName(cid)
        banned: kind === "bans" && cid !== ""
        MouseArea {
            anchors.fill: parent
            enabled: root.editable
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.pick(slot.side, slot.kind, slot.slotIndex, slot.kind === "picks" ? slot.role : "")
        }
    }

    // Coluna de um lado (aliado/inimigo)
    component SideCard: NeonCard {
        id: sc
        property string side: "ally"
        property bool isAlly: side === "ally"
        Layout.fillWidth: true
        Layout.fillHeight: true
        accent: isAlly ? Theme.blue : Theme.red
        title: isAlly ? "TIME ALIADO" : "TIME INIMIGO"

        Text { text: "BANS"; color: Theme.textMuted; font.pixelSize: Theme.fontXs; font.bold: true }
        Row {
            spacing: 8
            Repeater { model: 5; delegate: Slot { required property int index; size: 42; side: sc.side; kind: "bans"; slotIndex: index } }
        }
        Text { text: "PICKS"; color: Theme.textMuted; font.pixelSize: Theme.fontXs; font.bold: true }
        Repeater {
            model: 5
            delegate: RowLayout {
                id: pr
                required property int index
                Layout.fillWidth: true
                spacing: 12
                Slot { size: 50; side: sc.side; kind: "picks"; slotIndex: pr.index; role: root.roles[pr.index] }
                ColumnLayout {
                    spacing: 0
                    Text { text: root.roles[pr.index]; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true }
                    Text {
                        text: sc.isAlly ? (root.allyMembers[pr.index] ? root.allyMembers[pr.index].nick : "—") : "Adversário"
                        color: Theme.textDim; font.pixelSize: Theme.fontSm
                    }
                }
            }
        }
    }

    ChampionPicker { id: picker }

    ScrollPage {
        anchors.fill: parent
        LoadingBar { Layout.fillWidth: true; running: Draft.loading }

        PageHeader {
            title: "Draft Inteligente"
            subtitle: "Composição, sugestões e análise em tempo real"
            NeonTabBar { model: ["Ao Vivo", "Manual"]; currentIndex: Draft.mode === "live" ? 0 : 1; onActivated: i => Draft.mode = (i === 0 ? "live" : "manual") }
            NeonButton { text: "Limpar"; variant: "ghost"; visible: Draft.mode === "manual"; onClicked: Draft.clearDraft() }
            NeonButton { text: "Simular Draft"; glyph: Icons.glyph("simulate"); onClicked: Draft.runSimulation() }
            Rectangle {
                implicitWidth: pt.implicitWidth + 24; implicitHeight: 38; radius: 10
                color: Theme.alpha(Theme.bg, 0.65); border.width: 1; border.color: Theme.border
                Text { id: pt; anchors.centerIn: parent; text: "Patch " + (Draft.catalog.patch || "—"); color: Theme.text; font.pixelSize: Theme.fontMd }
            }
        }

        Text {
            visible: Draft.mode === "live" && !Draft.simulating
            text: App.lcuState === "champSelect" ? "Sincronizado com a seleção de campeões do LoL."
                  : (App.lcuState === "disconnected" ? "Abra o cliente do League of Legends para sincronizar o draft automaticamente."
                                                     : "Cliente conectado. Aguardando o início da seleção de campeões…")
            color: Theme.textDim; font.pixelSize: Theme.fontMd
        }
        Text { visible: root.editable; text: "Modo manual: clique em um slot para escolher o campeão."; color: Theme.textDim; font.pixelSize: Theme.fontMd }

        // ---- Aliado | Fase + composição | Inimigo ----
        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 940 ? 3 : 1
            columnSpacing: 14; rowSpacing: 14

            SideCard { side: "ally"; Layout.preferredWidth: 1 }

            NeonCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.25
                accent: Theme.borderHi
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { Layout.alignment: Qt.AlignHCenter; text: "FASE DE ESCOLHA"; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: Draft.timeLeft > 0 ? root.mmss(Draft.timeLeft) : "--:--"; color: Theme.text; font.pixelSize: 40; font.bold: true }
                    BarRow { label: ""; labelWidth: 0; value: Draft.currentStep; maxValue: 20; valueText: Draft.currentStep + "/20"; barColor: Theme.accent }
                }
                Text { text: "Tipo de composição atual"; color: Theme.textDim; font.pixelSize: Theme.fontSm }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: root.a.allyType || "—"; color: Theme.text; font.pixelSize: 34; font.bold: true }
                        Text { text: "Inimigo: " + (root.a.enemyType || "—"); color: Theme.red; font.pixelSize: Theme.fontMd }
                    }
                    ConfidenceRing { implicitWidth: 110; implicitHeight: 110; value: root.a.confidence || 0 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 6
                        Text { text: "Pontos fortes"; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true }
                        Repeater {
                            model: root.a.strengths || []
                            delegate: Text { required property string modelData; text: "✔  " + modelData; color: Theme.green; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 6
                        Text { text: "Pontos de atenção"; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true }
                        Repeater {
                            model: root.a.warnings || []
                            delegate: Text { required property string modelData; text: "⚠  " + modelData; color: Theme.gold; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                }
            }

            SideCard { side: "enemy"; Layout.preferredWidth: 1 }
        }

        // ---- Sugestões | Análise | Insights ----
        GridLayout {
            Layout.fillWidth: true
            columns: root.width > 940 ? 3 : 1
            columnSpacing: 14; rowSpacing: 14

            NeonCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.4
                title: "Sugestões de campeões"; icon: "💡"
                Text { visible: (root.a.suggestions || []).length === 0; text: "Monte a composição para receber sugestões."; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: root.a.suggestions || []
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            width: 92; height: 124; radius: 10
                            color: Theme.alpha(Theme.bg, 0.5); border.width: 1; border.color: Theme.alpha(Theme.teal, 0.6)
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                ChampionIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 56; championId: tile.modelData.id; name: tile.modelData.name }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.name; color: Theme.text; font.pixelSize: Theme.fontSm; font.bold: true }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.winRate.toFixed(1) + "%"; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "▲ +" + tile.modelData.delta.toFixed(1) + "%"; color: Theme.green; font.pixelSize: Theme.fontXs }
                            }
                        }
                    }
                }
            }
            NeonCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                title: "Análise da composição"; icon: Icons.glyph("analysis")
                Repeater {
                    model: root.a.bars || []
                    delegate: BarRow { required property var modelData; label: modelData.label; value: modelData.value; barColor: Theme.accent }
                }
            }
            NeonCard {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.2
                title: "Insights do draft"; icon: Icons.glyph("goals")
                Repeater {
                    model: root.a.insights || []
                    delegate: AlertRow {
                        required property var modelData
                        severity: modelData.level === "ok" ? "ok" : (modelData.level === "warn" ? "warning" : "info")
                        title: modelData.text
                    }
                }
            }
        }
    }
}
