// Estatísticas individuais: KDA, KP%, visão, farm, pool e solo x equipe (RF-A03).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    margin: 0
    readonly property var p: Analysis.player
    readonly property var info: {
        var m = Analysis.data.members || []
        for (var i = 0; i < m.length; i++) if (m[i].id === p.id) return m[i]
        return ({ nick: "?", role: "", rank: "" })
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        NeonButton { text: "Voltar ao time"; glyph: Icons.glyph("back"); variant: "ghost"; onClicked: Analysis.closePlayer() }
        Avatar { size: 48; text: root.info.nick; ring: Theme.accent }
        ColumnLayout {
            spacing: 0
            Text { text: root.info.nick; color: Theme.text; font.pixelSize: Theme.fontXl; font.bold: true }
            Text { text: root.info.role + " · " + root.info.rank; color: Theme.textDim; font.pixelSize: Theme.fontMd }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 760 ? 4 : 2
        columnSpacing: 14; rowSpacing: 14
        StatCard { label: "KDA"; value: root.p.kda.toFixed(1); tint: Theme.accent }
        StatCard { label: "Participação em abates"; value: root.p.kp + "%"; tint: Theme.blue }
        StatCard { label: "Visão / min"; value: root.p.visionPerMin.toFixed(2); tint: Theme.teal }
        StatCard { label: "Farm (CS / min)"; value: root.p.csPerMin.toFixed(1); tint: Theme.gold }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 760 ? 2 : 1
        columnSpacing: 14; rowSpacing: 14
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true
            title: "Pool de campeões"; icon: Icons.glyph("kills")
            Repeater {
                model: root.p.pool
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    ChampionIcon { size: 34; championId: modelData.champion.toLowerCase(); name: modelData.champion }
                    Text { text: modelData.champion; color: Theme.text; font.pixelSize: Theme.fontMd; Layout.fillWidth: true }
                    Text { text: modelData.games + " partidas"; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
                    Text { text: modelData.winRate.toFixed(1) + "%"; color: modelData.winRate >= 50 ? Theme.green : Theme.red; font.pixelSize: Theme.fontMd; font.bold: true; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight }
                }
            }
        }
        NeonCard {
            Layout.fillWidth: true; Layout.fillHeight: true
            title: "Solo vs. em equipe"; icon: Icons.glyph("teams")
            Text { text: "TAXA DE VITÓRIA"; color: Theme.textMuted; font.pixelSize: Theme.fontXs; font.bold: true }
            BarRow { label: "Solo"; value: root.p.soloVsTeam.solo.winRate; barColor: Theme.blue }
            BarRow { label: "Com o time"; value: root.p.soloVsTeam.team.winRate; barColor: Theme.accent }
            Text { Layout.topMargin: 8; text: "KDA"; color: Theme.textMuted; font.pixelSize: Theme.fontXs; font.bold: true }
            BarRow { label: "Solo"; value: root.p.soloVsTeam.solo.kda; maxValue: 6; suffix: ""; barColor: Theme.blue }
            BarRow { label: "Com o time"; value: root.p.soloVsTeam.team.kda; maxValue: 6; suffix: ""; barColor: Theme.accent }
        }
    }
}
