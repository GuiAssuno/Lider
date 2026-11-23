// Lista de ranking: [{label, detail, value}] com valor colorido (ex.: win rate).
import QtQuick
import QtQuick.Layouts
import Lider

ColumnLayout {
    id: root
    property var items: []
    property color valueColor: Theme.green
    property string suffix: "%"
    spacing: 8
    Layout.fillWidth: true

    Repeater {
        model: root.items
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: row.modelData.label; color: Theme.text; font.pixelSize: Theme.fontMd; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: row.modelData.detail || ""; color: Theme.textMuted; font.pixelSize: Theme.fontXs }
            }
            Text { text: row.modelData.value + root.suffix; color: root.valueColor; font.pixelSize: Theme.fontMd + 1; font.bold: true }
        }
    }
    Text { visible: root.items.length === 0; text: "Sem dados suficientes."; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
}
