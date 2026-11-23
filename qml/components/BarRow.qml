// Linha "rótulo — barra — valor". Barra anima suavemente ao mudar o valor.
import QtQuick
import QtQuick.Layouts
import Lider

RowLayout {
    id: root
    property string label: ""
    property real value: 0
    property real maxValue: 100
    property color barColor: Theme.accent
    property string suffix: "%"
    property int labelWidth: 90
    property string valueText: ""     // sobrescreve o texto do valor, se informado
    spacing: 12
    Layout.fillWidth: true

    Text {
        Layout.preferredWidth: root.labelWidth
        text: root.label
        color: Theme.textDim
        font.pixelSize: Theme.fontMd
        elide: Text.ElideRight
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: 4
        color: Theme.alpha(Theme.border, 0.55)
        Rectangle {
            height: parent.height
            radius: 4
            color: root.barColor
            width: parent.width * Math.max(0, Math.min(1, root.value / root.maxValue))
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }
    Text {
        Layout.minimumWidth: 52
        horizontalAlignment: Text.AlignRight
        text: root.valueText !== "" ? root.valueText : (Math.round(root.value * 10) / 10) + root.suffix
        color: Theme.text
        font.pixelSize: Theme.fontMd
        font.bold: true
    }
}
