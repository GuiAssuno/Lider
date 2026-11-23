// Linha de alerta acionável (Treino/Draft): ícone por severidade + título + detalhe.
// severity: "critical" | "warning" | "info" | "ok"   (RNF-T01)
import QtQuick
import QtQuick.Layouts
import Lider

Rectangle {
    id: root
    property string severity: "info"
    property string title: ""
    property string detail: ""

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 20
    radius: 10
    color: Theme.alpha(Theme.severityColor(severity), 0.10)
    border.width: 1
    border.color: Theme.alpha(Theme.severityColor(severity), 0.45)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        Text { text: Theme.severityGlyph(root.severity); color: Theme.severityColor(root.severity); font.pixelSize: 20; Layout.alignment: Qt.AlignTop }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { Layout.fillWidth: true; text: root.title; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true; wrapMode: Text.WordWrap }
            Text { Layout.fillWidth: true; visible: root.detail !== ""; text: root.detail; color: Theme.textDim; font.pixelSize: Theme.fontSm; wrapMode: Text.WordWrap }
        }
    }
}
