#include "AnalysisController.h"

AnalysisController::AnalysisController(IBackendService *backend, QObject *parent)
    : BaseController(backend, parent)
{
    connect(backend, &IBackendService::responseReady, this,
            [this](IBackendService::Endpoint ep, const QVariantMap &p) {
        if (ep == IBackendService::Endpoint::TeamAnalysis) {
            m_data = p; m_loaded = true; setLoading(false); setError({});
            emit dataChanged();
        } else if (ep == IBackendService::Endpoint::PlayerStats) {
            m_player = p; m_playerOpen = true; setLoading(false);
            emit playerChanged();
        }
    });
    connect(backend, &IBackendService::requestFailed, this,
            [this](IBackendService::Endpoint ep, const QString &msg) {
        if (ep == IBackendService::Endpoint::TeamAnalysis || ep == IBackendService::Endpoint::PlayerStats) {
            setLoading(false); setError(msg);
        }
    });
}

void AnalysisController::setTeamId(const QString &id)
{
    if (id == m_teamId) return;
    m_teamId = id;
    m_loaded = false; m_data.clear(); m_playerOpen = false; m_player.clear();
    emit dataChanged(); emit playerChanged();
}

void AnalysisController::ensureLoaded() { if (!m_loaded && !loading()) reload(); }

void AnalysisController::reload()
{
    if (m_teamId.isEmpty()) return;
    setLoading(true); setError({});
    backend()->fetchTeamAnalysis(m_teamId);
}

void AnalysisController::openPlayer(const QString &playerId)
{
    setLoading(true);
    backend()->fetchPlayerStats(m_teamId, playerId);
}

void AnalysisController::closePlayer()
{
    m_playerOpen = false; m_player.clear();
    emit playerChanged();
}
