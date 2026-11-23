// Base dos diálogos modais (ConfirmDialog, ProfileDialog, TeamEditorDialog...).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider

Popup {
    id: root
    property string title: ""
    property int dialogWidth: 460
    default property alias content: body.data

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 24
    width: Math.min(dialogWidth, (parent ? parent.width : dialogWidth) - 40)

    Overlay.modal: Rectangle { color: Theme.alpha("#000000", 0.62) }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fastMs } }
    exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fastMs } }

    background: Rectangle {
        radius: 16
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderHi
    }
    contentItem: ColumnLayout {
        spacing: 16
        Text { text: root.title; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true; Layout.fillWidth: true }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 14 }
    }
}
