#include "TrainingController.h"

TrainingController::TrainingController(IBackendService *backend, QObject *parent)
    : BaseController(backend, parent)
{
    connect(backend, &IBackendService::responseReady, this,
            [this](IBackendService::Endpoint ep, const QVariantMap &p) {
        if (ep != IBackendService::Endpoint::Training) return;
        m_data = p; m_loaded = true; setLoading(false); setError({});
        emit dataChanged();
    });
    connect(backend, &IBackendService::requestFailed, this,
            [this](IBackendService::Endpoint ep, const QString &msg) {
        if (ep == IBackendService::Endpoint::Training) { setLoading(false); setError(msg); }
    });
}

void TrainingController::setTeamId(const QString &id)
{
    if (id == m_teamId) return;
    m_teamId = id; m_loaded = false; m_data.clear();
    emit dataChanged();
}

void TrainingController::ensureLoaded() { if (!m_loaded && !loading()) reload(); }

void TrainingController::reload()
{
    if (m_teamId.isEmpty()) return;
    setLoading(true); setError({});
    backend()->fetchTraining(m_teamId);
}

void TrainingController::toggleGoal(const QString &goalId)
{
    QVariantList goals = m_data.value("goals").toList();
    for (int i = 0; i < goals.size(); ++i) {
        QVariantMap g = goals[i].toMap();
        if (g.value("id").toString() == goalId) { g["done"] = !g.value("done").toBool(); goals[i] = g; }
    }
    m_data["goals"] = goals;
    emit dataChanged();
}
