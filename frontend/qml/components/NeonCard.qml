// Cartão base do design system: superfície com borda neon e cabeçalho opcional.
// Uso:  NeonCard { title: "Sinergias"; icon: "▤"; Text { ... } }
import QtQuick
import QtQuick.Layouts
import Lider

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property color accent: Theme.accent
    /// true => o corpo ocupa toda a altura do cartão (ex.: ListView). false => conteúdo alinhado ao topo.
    property bool fillBody: false
    /// Conteúdo extra no canto direito do cabeçalho.
    property alias headerExtras: extras.data
    /// Filhos declarados dentro do NeonCard vão para o corpo (ColumnLayout).
    default property alias content: body.data

    implicitHeight: col.implicitHeight + Theme.pad * 2
    radius: Theme.radius
    border.width: 1
    border.color: Theme.alpha(accent, 0.40)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.surfaceHi }
        GradientStop { position: 1.0; color: Theme.surface }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        RowLayout {
            visible: root.title !== ""
            Layout.fillWidth: true
            spacing: 8
            Text { visible: root.icon !== ""; text: root.icon; color: root.accent; font.pixelSize: Theme.fontLg }
            Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fontMd + 1; font.bold: true }
            Item { Layout.fillWidth: true }
            RowLayout { id: extras; spacing: 6 }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: root.fillBody
            spacing: Theme.gap
        }
        Item { visible: !root.fillBody; Layout.fillHeight: true }   // empurra o conteúdo para o topo
    }
}
