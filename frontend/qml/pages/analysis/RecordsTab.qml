// Subguia "Recordes": quadro histórico do time (RF-A08).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

ScrollPage {
    id: root
    margin: 0

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 860 ? 3 : (root.width > 560 ? 2 : 1)
        columnSpacing: 14; rowSpacing: 14
        Repeater {
            model: Analysis.data.records
            delegate: NeonCard {
                required property var modelData
                Layout.fillWidth: true
                accent: Theme.gold
                RowLayout {
                    spacing: 10
                    Text { text: Icons.glyph(modelData.icon); color: Theme.gold; font.pixelSize: 26 }
                    Text { text: modelData.label; color: Theme.textDim; font.pixelSize: Theme.fontMd; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
                Text { text: modelData.value; color: Theme.text; font.pixelSize: Theme.fontHuge; font.bold: true }
                Text { text: modelData.detail; color: Theme.textMuted; font.pixelSize: Theme.fontSm }
            }
        }
    }
}
