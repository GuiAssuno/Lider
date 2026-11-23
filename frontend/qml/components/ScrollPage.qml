// Página rolável: filhos entram numa coluna com margens. Barra de rolagem sob demanda.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider

Flickable {
    id: root
    default property alias content: col.data
    property int margin: 24
    property alias spacing: col.spacing

    contentWidth: width
    contentHeight: col.implicitHeight + margin * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: col
        x: root.margin
        y: root.margin
        width: root.width - root.margin * 2
        spacing: 16
    }
}
