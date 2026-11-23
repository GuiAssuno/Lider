// Barra de título customizada (janela sem moldura). Arrastar = mover; duplo clique = maximizar.
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Rectangle {
    id: root
    readonly property var win: Window.window
    readonly property bool maximized: win && win.visibility === Window.Maximized
    implicitHeight: 40
    color: Theme.alpha(Theme.bg, 0.95)

    // Área de arraste
    MouseArea {
        anchors.fill: parent
        onDoubleClicked: root.toggleMaximize()
    }
    DragHandler {
        target: null
        onActiveChanged: if (active && root.win) root.win.startSystemMove()
    }

    function toggleMaximize() {
        if (!win) return
        win.visibility = maximized ? Window.Windowed : Window.Maximized
    }

    component WinButton: Rectangle {
        id: btn
        property string glyph: ""
        property color hoverColor: Theme.alpha(Theme.accent, 0.3)
        signal clicked()
        Layout.preferredWidth: 40
        Layout.fillHeight: true
        color: ma.containsMouse ? hoverColor : "transparent"
        Text { anchors.centerIn: parent; text: btn.glyph; color: Theme.text; font.pixelSize: 14 }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        spacing: 12
        Text { text: Icons.glyph("brand"); color: Theme.gold; font.pixelSize: 16 }
        Text { text: "LÍDER"; color: Theme.text; font.pixelSize: Theme.fontMd; font.bold: true; font.italic: true; font.letterSpacing: 2 }
        Item { Layout.fillWidth: true }
        LcuStatusBadge { visible: App.authenticated }
        Item { Layout.preferredWidth: 8 }
        WinButton { glyph: Icons.glyph("minimize"); onClicked: if (root.win) root.win.showMinimized() }
        WinButton { glyph: root.maximized ? Icons.glyph("restore") : Icons.glyph("maximize"); onClicked: root.toggleMaximize() }
        WinButton { glyph: Icons.glyph("close"); hoverColor: Theme.red; onClicked: Qt.quit() }
    }
}
