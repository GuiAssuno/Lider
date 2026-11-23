// Seletor de campeão para o modo Manual do draft (e para a Simulação).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider
import Lider.Core

NeonPopup {
    id: root
    title: "Escolher campeão"
    dialogWidth: 600
    property string side: "ally"
    property string kind: "picks"
    property int slotIndex: 0
    property string roleFilter: ""      // se vazio, mostra todas as funções
    property string query: ""

    function pick(side_, kind_, index, role) {
        side = side_; kind = kind_; slotIndex = index; roleFilter = role || ""; query = ""
        search.text = ""
        open()
    }
    readonly property var filtered: {
        var all = Draft.catalog.champions || [], out = []
        var q = query.trim().toLowerCase()
        for (var i = 0; i < all.length; i++) {
            if (q !== "" && all[i].name.toLowerCase().indexOf(q) < 0) continue
            if (q === "" && roleFilter !== "" && all[i].role !== roleFilter) continue
            out.push(all[i])
        }
        return out
    }

    NeonTextField { id: search; Layout.fillWidth: true; placeholder: "Buscar campeão…"; onTextChanged: root.query = text }
    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        cellWidth: 88; cellHeight: 92
        clip: true
        model: root.filtered
        delegate: Item {
            id: cell
            required property var modelData
            width: grid.cellWidth; height: grid.cellHeight
            readonly property bool taken: Draft.isTaken(modelData.id)
            Column {
                anchors.centerIn: parent
                spacing: 4
                ChampionIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 52; championId: cell.modelData.id; name: cell.modelData.name; dimmed: cell.taken }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: cell.modelData.name; color: cell.taken ? Theme.textMuted : Theme.text; font.pixelSize: Theme.fontXs }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !cell.taken
                cursorShape: Qt.PointingHandCursor
                onClicked: { Draft.setSlot(root.side, root.kind, root.slotIndex, cell.modelData.id); root.close() }
            }
        }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
    RowLayout {
        Layout.fillWidth: true
        NeonButton { text: "Limpar slot"; variant: "ghost"; onClicked: { Draft.setSlot(root.side, root.kind, root.slotIndex, ""); root.close() } }
        Item { Layout.fillWidth: true }
        NeonButton { text: "Fechar"; variant: "ghost"; onClicked: root.close() }
    }
}
