// Edição do perfil: Nick, Tag e Região (RF-L04).
import QtQuick
import QtQuick.Layouts
import Lider
import Lider.Core

NeonPopup {
    id: root
    title: "Editar perfil"
    readonly property var regions: ["BR", "NA", "EUW", "EUNE", "LAN", "KR"]

    onAboutToShow: {
        nick.text = App.profile.nick || ""
        tag.text = App.profile.tag || ""
        regionTabs.currentIndex = Math.max(0, regions.indexOf(App.profile.region || "BR"))
    }
    // fecha quando o backend confirmar a atualização
    Connections { target: App; function onProfileChanged() { if (root.opened) root.close() } }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        NeonTextField { id: nick; Layout.fillWidth: true; label: "Nick" }
        NeonTextField { id: tag; Layout.preferredWidth: 110; label: "Tag" }
    }
    Text { text: "Região"; color: Theme.textDim; font.pixelSize: Theme.fontSm }
    NeonTabBar { id: regionTabs; model: root.regions }
    Text { visible: App.error !== ""; text: App.error; color: Theme.red; font.pixelSize: Theme.fontSm }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        NeonButton { text: "Cancelar"; variant: "ghost"; onClicked: root.close() }
        NeonButton { text: "Salvar"; enabled: !App.loading; onClicked: App.linkAccount(nick.text, tag.text, root.regions[regionTabs.currentIndex]) }
    }
}
