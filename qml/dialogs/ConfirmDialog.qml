// Confirmação genérica. Uso: confirm.ask("Título", "Mensagem", () => ...)
import QtQuick
import QtQuick.Layouts
import Lider

NeonPopup {
    id: root
    property string message: ""
    property var onConfirmed: null
    dialogWidth: 420

    function ask(titleText, msg, callback) {
        title = titleText; message = msg; onConfirmed = callback; open()
    }

    Text { Layout.fillWidth: true; text: root.message; wrapMode: Text.WordWrap; color: Theme.textDim; font.pixelSize: Theme.fontMd }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        NeonButton { text: "Cancelar"; variant: "ghost"; onClicked: root.close() }
        NeonButton { text: "Confirmar"; variant: "danger"; onClicked: { root.close(); if (root.onConfirmed) root.onConfirmed() } }
    }
}
