// Título de página + ações à direita (filhos declarados vão para a área de ações).
import QtQuick
import QtQuick.Layouts
import Lider

RowLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    default property alias actions: actionsRow.data
    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        spacing: 2
        Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fontXl; font.bold: true }
        Text { visible: root.subtitle !== ""; text: root.subtitle; color: Theme.textDim; font.pixelSize: Theme.fontMd }
    }
    Item { Layout.fillWidth: true }
    RowLayout { id: actionsRow; spacing: 10 }
}
