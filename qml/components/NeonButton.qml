// Botão do design system. variant: "primary" | "ghost" | "danger"
import QtQuick
import QtQuick.Controls
import Lider

Button {
    id: control
    property string variant: "primary"
    property string glyph: ""

    implicitHeight: 38
    implicitWidth: label.implicitWidth + 32
    leftPadding: 16
    rightPadding: 16
    hoverEnabled: true
    font.pixelSize: Theme.fontMd
    font.bold: true
    opacity: enabled ? 1.0 : 0.45

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    contentItem: Text {
        id: label
        text: (control.glyph !== "" ? control.glyph + "  " : "") + control.text
        font: control.font
        color: control.variant === "danger" ? Theme.red : Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 10
        border.width: control.variant === "primary" ? 0 : 1
        border.color: control.variant === "danger" ? Theme.alpha(Theme.red, 0.7) : Theme.alpha(Theme.accent, 0.7)
        color: {
            if (control.variant === "primary")
                return control.down ? Theme.accentStrong : (control.hovered ? Qt.lighter(Theme.accentStrong, 1.25) : Theme.accentStrong)
            var base = control.variant === "danger" ? Theme.red : Theme.accent
            return Theme.alpha(base, control.down ? 0.30 : (control.hovered ? 0.18 : 0.0))
        }
        Behavior on color { ColorAnimation { duration: Theme.fastMs } }
    }
}
