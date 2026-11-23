// =============================================================================
//  AnalysisController — dados da área "Análise do Time" (RF-A01..A08)
// =============================================================================
//  Exposto como `Analysis`. Carrega sob demanda (`ensureLoaded`) e recarrega
//  automaticamente quando o time ativo muda (RNF-L03).
// =============================================================================
#pragma once

#include "BaseController.h"
#include <QVariantMap>

class AnalysisController : public BaseController
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap data READ data NOTIFY dataChanged)       // members, general, stats, records
    Q_PROPERTY(QVariantMap player READ player NOTIFY playerChanged) // estatísticas do jogador aberto
    Q_PROPERTY(bool playerOpen READ playerOpen NOTIFY playerChanged)
public:
    explicit AnalysisController(IBackendService *backend, QObject *parent = nullptr);

    QVariantMap data() const { return m_data; }
    QVariantMap player() const { return m_player; }
    bool playerOpen() const { return m_playerOpen; }

    void setTeamId(const QString &id);

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void openPlayer(const QString &playerId);   ///< RF-A03
    Q_INVOKABLE void closePlayer();

signals:
    void dataChanged();
    void playerChanged();

private:
    QString m_teamId;
    QVariantMap m_data, m_player;
    bool m_playerOpen = false;
    bool m_loaded = false;
};
