// =============================================================================
//  TrainingController — diagnósticos, metas e evolução (RF-T01..T03)
// =============================================================================
#pragma once

#include "BaseController.h"
#include <QVariantMap>

class TrainingController : public BaseController
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap data READ data NOTIFY dataChanged) // team[], players[], goals[], evolution[]
public:
    explicit TrainingController(IBackendService *backend, QObject *parent = nullptr);
    QVariantMap data() const { return m_data; }
    void setTeamId(const QString &id);

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void reload();
    /// Marca/desmarca meta localmente (o backend real persistirá via PATCH).
    Q_INVOKABLE void toggleGoal(const QString &goalId);

signals:
    void dataChanged();

private:
    QString m_teamId;
    QVariantMap m_data;
    bool m_loaded = false;
};
