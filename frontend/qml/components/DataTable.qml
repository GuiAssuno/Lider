// Tabela leve e genérica (sem ListView: ideal para dezenas de linhas).
//   columns: [{ key, title, weight(=1), align("left"|"right"|"center"),
//               kind("text"|"percent"|"signed"|"result"), suffix }]
//   rows:    [{ <key>: valor, ... }]
import QtQuick
import QtQuick.Layouts
import Lider

ColumnLayout {
    id: root
    property var columns: []
    property var rows: []
    spacing: 0
    Layout.fillWidth: true

    function fmt(col, v) {
        if (v === undefined || v === null) return "—"
        if (Array.isArray(v)) return v.join(" · ")
        if (col.kind === "percent") return Number(v).toFixed(1) + "%"
        if (col.kind === "signed") return (v > 0 ? "+" : "") + v
        return v + (col.suffix || "")
    }
    function tint(col, v) {
        if (col.kind === "percent") return v >= 50 ? Theme.green : Theme.red
        if (col.kind === "signed")  return v > 0 ? Theme.green : (v < 0 ? Theme.red : Theme.textDim)
        if (col.kind === "result")  return v === "Vitória" ? Theme.green : Theme.red
        return Theme.text
    }
    function hAlign(col) {
        return col.align === "right" ? Text.AlignRight : (col.align === "center" ? Text.AlignHCenter : Text.AlignLeft)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        spacing: 8
        Repeater {
            model: root.columns
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: (modelData.weight || 1) * 100
                text: modelData.title
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
                font.bold: true
                horizontalAlignment: root.hAlign(modelData)
            }
        }
    }
    Repeater {
        model: root.rows
        delegate: Rectangle {
            id: rowItem
            required property int index
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 8
            color: index % 2 === 0 ? Theme.alpha(Theme.bg, 0.45) : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8
                Repeater {
                    model: root.columns
                    delegate: Text {
                        id: cell
                        required property var modelData
                        readonly property var v: rowItem.modelData[modelData.key]
                        Layout.fillWidth: true
                        Layout.preferredWidth: (modelData.weight || 1) * 100
                        text: root.fmt(modelData, v)
                        color: root.tint(modelData, v)
                        font.pixelSize: Theme.fontMd
                        font.bold: modelData.kind !== undefined && modelData.kind !== "text"
                        elide: Text.ElideRight
                        horizontalAlignment: root.hAlign(modelData)
                    }
                }
            }
        }
    }
}
