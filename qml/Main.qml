// Janela principal (sem moldura): barra de título + [Login | Shell].
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Lider
import Lider.Core

ApplicationWindow {
    id: win
    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "LÍDER — Analise • Treine • Evolua"
    color: Theme.bg

    // Fundo em degradê (barato: um único Rectangle).
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgAlt }
            GradientStop { position: 1.0; color: Theme.bg }
        }
        border.width: win.visibility === Window.Maximized ? 0 : 1
        border.color: Theme.alpha(Theme.borderHi, 0.7)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        TitleBar { Layout.fillWidth: true }
        // Só um dos dois existe por vez: economiza memória/CPU.
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: App.authenticated ? shellComp : loginComp
        }
    }

    Component { id: shellComp; Shell {} }
    Component { id: loginComp; LoginPage {} }

    ResizeHandles { anchors.fill: parent }
    Toast {}
}
