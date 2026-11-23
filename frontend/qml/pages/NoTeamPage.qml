// Exibida quando uma área exige time ativo e o usuário ainda não tem nenhum (RF-L07/L10).
import QtQuick
import Lider
import Lider.Core

Item {
    EmptyState {
        anchors.centerIn: parent
        glyph: Icons.glyph("teams")
        title: "Nenhum time ativo"
        description: "Cadastre um time (mínimo de 2 jogadores) e escolha-o como ativo para liberar Análise, Draft e Treino."
        actionText: "Ir para Meus Times"
        onActionClicked: App.navigate("teams")
    }
}
