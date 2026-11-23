// Campo de texto com rótulo e mensagem de erro.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider

ColumnLayout {
    id: root
    property alias text: field.text
    property string label: ""
    property string placeholder: ""
    property bool password: false
    property string errorText: ""
    signal accepted()
    spacing: 6

    function focusField() { field.forceActiveFocus() }

    Text { visible: root.label !== ""; text: root.label; color: Theme.textDim; font.pixelSize: Theme.fontSm }
    TextField {
        id: field
        Layout.fillWidth: true
        implicitHeight: 42
        leftPadding: 14
        rightPadding: 14
        color: Theme.text
        font.pixelSize: Theme.fontMd
        placeholderText: root.placeholder
        placeholderTextColor: Theme.textMuted
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        onAccepted: root.accepted()
        background: Rectangle {
            radius: 10
            color: Theme.alpha(Theme.bg, 0.75)
            border.width: 1
            border.color: root.errorText !== "" ? Theme.red : (field.activeFocus ? Theme.accent : Theme.border)
        }
    }
    Text { visible: root.errorText !== ""; text: root.errorText; color: Theme.red; font.pixelSize: Theme.fontSm }
}
