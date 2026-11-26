// Login (RF-L01) e vínculo de conta Riot no primeiro acesso (RF-L02).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

Item {
    id: root
    property bool registerMode: false
    readonly property var regions: ["BR", "NA", "EUW", "EUNE", "LAN", "KR"]
    property int regionIndex: 0

    NeonCard {
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 40)
        accent: Theme.borderHi

        // Marca
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { Layout.alignment: Qt.AlignHCenter; text: Icons.glyph("brand"); color: Theme.gold; font.pixelSize: 38 }
            Text { Layout.alignment: Qt.AlignHCenter; text: "LÍDER"; color: Theme.text; font.pixelSize: 40; font.bold: true; font.italic: true }
            Text { Layout.alignment: Qt.AlignHCenter; text: "ANALISE • TREINE • EVOLUA"; color: Theme.textMuted; font.pixelSize: Theme.fontXs; font.letterSpacing: 3 }
        }

        // ---- Passo 1: credenciais ----
        ColumnLayout {
            visible: !App.needsAccountLink
            Layout.fillWidth: true
            spacing: 14
            Text { text: root.registerMode ? "Criar conta" : "Entrar"; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
            NeonTextField { id: email; Layout.fillWidth: true; label: "E-mail"; placeholder: "voce@exemplo.com" }
            NeonTextField { id: pass; Layout.fillWidth: true; label: "Senha"; password: true; placeholder: "••••••••"; onAccepted: submit.clicked() }
            Text { visible: App.error !== ""; text: App.error; color: Theme.red; font.pixelSize: Theme.fontSm }
            NeonButton {
                id: submit
                Layout.fillWidth: true
                text: App.loading ? "Aguarde…" : (root.registerMode ? "Cadastrar" : "Entrar")
                enabled: !App.loading
                onClicked: root.registerMode
                           ? App.registerAccount(email.text, pass.text)
                           : App.login(email.text, pass.text)
            }
            NeonButton { Layout.fillWidth: true; variant: "ghost"; text: "Entrar com Riot (RSO)"; glyph: Icons.glyph("counters"); enabled: !App.loading; onClicked: App.loginWithRiot() }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.registerMode ? "Já tem conta? Entrar" : "Não tem conta? Cadastre-se"
                color: Theme.textDim; font.pixelSize: Theme.fontSm
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.registerMode = !root.registerMode }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Use um e-mail válido e senha com 8+ caracteres.\nSem LIDER_API_URL, o app roda em modo demonstração (mock)."
                color: Theme.textMuted; font.pixelSize: Theme.fontXs; horizontalAlignment: Text.AlignHCenter
            }
        }

        // ---- Passo 2: vínculo Nick / Tag / Região ----
        ColumnLayout {
            visible: App.needsAccountLink
            Layout.fillWidth: true
            spacing: 14
            Text { text: "Vincule sua conta Riot"; color: Theme.text; font.pixelSize: Theme.fontLg; font.bold: true }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Precisamos do seu Nick, Tag e Região para identificar você na Riot API."; color: Theme.textDim; font.pixelSize: Theme.fontMd }
            RowLayout {
                spacing: 10
                NeonTextField { id: nick; Layout.fillWidth: true; Layout.preferredWidth: 200; label: "Nick"; placeholder: "Invocador" }
                NeonTextField { id: tag; Layout.preferredWidth: 110; label: "Tag"; placeholder: "BR1" }
            }
            Text { text: "Região"; color: Theme.textDim; font.pixelSize: Theme.fontSm }
            NeonTabBar { model: root.regions; currentIndex: root.regionIndex; onActivated: i => root.regionIndex = i }
            Text { visible: App.error !== ""; text: App.error; color: Theme.red; font.pixelSize: Theme.fontSm }
            NeonButton {
                Layout.fillWidth: true
                text: App.loading ? "Aguarde…" : "Concluir"
                enabled: !App.loading
                onClicked: App.linkAccount(nick.text, tag.text, root.regions[root.regionIndex])
            }
        }
    }
}
