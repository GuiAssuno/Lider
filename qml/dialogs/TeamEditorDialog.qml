// Cadastro/edição de time: nome, abreviação, logo e membros (RF-L07..L09, RNF-L02).
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Lider
import Lider.Core

NeonPopup {
    id: root
    dialogWidth: 560
    property string teamId: ""
    property string logoPath: ""
    property string errorText: ""

    ListModel { id: members }

    function openNew() {
        teamId = ""; title = "Novo time"; errorText = ""; logoPath = ""
        name.text = ""; tag.text = ""
        members.clear(); members.append({ id: "", nick: "", tag: "" }); members.append({ id: "", nick: "", tag: "" })
        open()
    }
    function openEdit(team) {
        teamId = team.id; title = "Editar time"; errorText = ""; logoPath = team.logoPath || ""
        name.text = team.name; tag.text = team.tag
        members.clear()
        for (var i = 0; i < team.members.length; i++)
            members.append({ id: team.members[i].id || "", nick: team.members[i].nick, tag: team.members[i].tag || "" })
        open()
    }
    function collect() {
        var list = []
        for (var i = 0; i < members.count; i++) {
            var m = members.get(i)
            if (m.nick.trim() !== "") list.push({ id: m.id, nick: m.nick.trim(), tag: m.tag.trim() })
        }
        return { id: teamId, name: name.text.trim(), tag: tag.text.trim().toUpperCase(), logoPath: logoPath, members: list }
    }

    FileDialog {
        id: fileDialog
        title: "Escolher logo do time"
        nameFilters: ["Imagens (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: {
            var err = App.validateLogo(selectedFile)
            root.errorText = err
            if (err === "") root.logoPath = selectedFile.toString()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Avatar { size: 64; text: tag.text || name.text; source: root.logoPath }
        ColumnLayout {
            spacing: 6
            NeonButton { text: "Escolher logo"; variant: "ghost"; onClicked: fileDialog.open() }
            Text { text: "PNG, JPG ou WebP · até 2 MB"; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        NeonTextField { id: name; Layout.fillWidth: true; label: "Nome do time" }
        NeonTextField { id: tag; Layout.preferredWidth: 120; label: "Abreviação" }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Jogadores (" + members.count + ")"; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true }
        Item { Layout.fillWidth: true }
        NeonButton { text: "Adicionar"; glyph: Icons.glyph("add"); variant: "ghost"; onClicked: members.append({ id: "", nick: "", tag: "" }) }
    }
    // Lista rolável: sem limite máximo de jogadores (RF-L09)
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 220)
        clip: true
        spacing: 8
        model: members
        delegate: RowLayout {
            id: mrow
            required property int index
            required property string nick
            required property string tag
            width: list.width
            spacing: 8
            NeonTextField { Layout.fillWidth: true; placeholder: "Nick"; text: mrow.nick; onTextChanged: members.setProperty(mrow.index, "nick", text) }
            NeonTextField { Layout.preferredWidth: 110; placeholder: "Tag"; text: mrow.tag; onTextChanged: members.setProperty(mrow.index, "tag", text) }
            Text {
                text: Icons.glyph("close"); color: members.count > 2 ? Theme.red : Theme.textMuted; font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (members.count > 2) members.remove(mrow.index); else root.errorText = "Um time precisa de pelo menos 2 jogadores." }
                }
            }
        }
    }

    Text { visible: root.errorText !== ""; text: root.errorText; color: Theme.red; font.pixelSize: Theme.fontSm; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        NeonButton { text: "Cancelar"; variant: "ghost"; onClicked: root.close() }
        NeonButton {
            text: "Salvar"
            onClicked: {
                var err = App.saveTeam(root.collect())
                if (err === "") root.close(); else root.errorText = err
            }
        }
    }
}
