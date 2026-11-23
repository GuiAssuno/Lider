// Cartão de métrica com variação e sparkline (ex.: Taxa de Vitória 64.8% ▲ +4.2%).
import QtQuick
import QtQuick.Layouts
import Lider

NeonCard {
    id: root
    property string label: ""
    property string value: ""
    property string delta: ""
    property bool positive: true
    property color tint: Theme.accent
    property string glyph: ""
    property var series: []

    accent: tint
    Layout.fillWidth: true

    RowLayout {
        spacing: 8
        Text { visible: root.glyph !== ""; text: root.glyph; color: root.tint; font.pixelSize: Theme.fontLg }
        Text { text: root.label; color: Theme.textDim; font.pixelSize: Theme.fontMd }
    }
    Text { text: root.value; color: Theme.text; font.pixelSize: Theme.fontHuge; font.bold: true }
    RowLayout {
        visible: root.delta !== "" || root.series.length > 1
        Layout.fillWidth: true
        Text {
            visible: root.delta !== ""
            text: (root.positive ? Icons.glyph("up") : Icons.glyph("down")) + " " + root.delta
            color: root.positive ? Theme.green : Theme.red
            font.pixelSize: Theme.fontSm
            font.bold: true
        }
        Item { Layout.fillWidth: true }
        Sparkline {
            visible: root.series.length > 1
            Layout.preferredWidth: 96
            Layout.preferredHeight: 34
            values: root.series
            lineColor: root.tint
        }
    }
}
