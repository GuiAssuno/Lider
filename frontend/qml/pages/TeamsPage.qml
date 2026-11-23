// Gestão de times (RF-L07..L10): listar, criar, editar, excluir e definir o time ativo.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root

    PageHeader {
        title: "Meus Times"
        subtitle: "Cadastre seus times e escolha qual fica ativo em Análise, Draft e Treino."
        NeonButton { text: "Novo time"; glyph: Icons.glyph("add"); onClicked: editor.openNew() }
    }

    EmptyState {
        visible: App.teams.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 60
        glyph: Icons.glyph("teams")
        title: "Você ainda não tem times"
        description: "Crie seu primeiro time com pelo menos 2 jogadores para começar a analisar."
        actionText: "Criar time"
        onActionClicked: editor.openNew()
    }

    Repeater {
        model: App.teams
        delegate: NeonCard {
            id: card
            required property var modelData
            readonly property bool isActive: modelData.id === App.activeTeamId
            Layout.fillWidth: true
            accent: isActive ? Theme.green : Theme.accent

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Avatar { size: 56; text: card.modelData.tag; source: card.modelData.logoPath || "" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        spacing: 10
                        Text { text: card.modelData.name; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
                        Text { text: "[" + card.modelData.tag + "]"; color: Theme.textDim; font.pixelSize: Theme.fontMd }
                        Rectangle {
                            visible: card.isActive
                            implicitWidth: ab.implicitWidth + 16; implicitHeight: 22; radius: 11
                            color: Theme.alpha(Theme.green, 0.18); border.width: 1; border.color: Theme.green
                            Text { id: ab; anchors.centerIn: parent; text: "ATIVO"; color: Theme.green; font.pixelSize: Theme.fontXs; font.bold: true }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Theme.textDim; font.pixelSize: Theme.fontSm
                        text: card.modelData.members.length + " jogadores · " + card.modelData.members.map(m => m.nick).join(", ")
                    }
                }
                NeonButton { visible: !card.isActive; text: "Definir ativo"; onClicked: App.setActiveTeam(card.modelData.id) }
                NeonButton { text: "Editar"; variant: "ghost"; glyph: Icons.glyph("edit"); onClicked: editor.openEdit(card.modelData) }
                NeonButton {
                    text: "Excluir"; variant: "danger"
                    onClicked: confirm.ask("Excluir time", "Excluir “" + card.modelData.name + "”? Esta ação não pode ser desfeita.",
                                           () => App.deleteTeam(card.modelData.id))
                }
            }
        }
    }

    TeamEditorDialog { id: editor }
    ConfirmDialog { id: confirm }
}
