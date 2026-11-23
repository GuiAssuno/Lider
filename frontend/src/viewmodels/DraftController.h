// =============================================================================
//  DraftController — assistente de draft (RF-D01..D09, RNF-D01/D02)
// =============================================================================
//  Exposto como `Draft`. Mantém o estado do draft (4 listas de 5 slots), recebe
//  atualizações da LCU (modo "live") ou do usuário (modo "manual"), e pede ao
//  backend a análise da composição a cada mudança (com debounce e controle de
//  sequência para descartar respostas atrasadas).
// =============================================================================
#pragma once

#include "BaseController.h"
#include "core/ILcuBridge.h"
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class DraftController : public BaseController
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap catalog READ catalog NOTIFY catalogChanged)   // champions, order, archetypes, counters, patch
    Q_PROPERTY(QVariantMap draft READ draft NOTIFY draftChanged)         // {ally:{bans,picks}, enemy:{bans,picks}}
    Q_PROPERTY(QVariantMap analysis READ analysis NOTIFY analysisChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)  // "live" | "manual"
    Q_PROPERTY(int timeLeft READ timeLeft NOTIFY timeLeftChanged)
    Q_PROPERTY(int currentStep READ currentStep NOTIFY draftChanged)     // 0..20 (passos concluídos)
    Q_PROPERTY(bool simulating READ simulating NOTIFY simulatingChanged)
public:
    DraftController(IBackendService *backend, ILcuBridge *lcu, QObject *parent = nullptr);

    QVariantMap catalog() const { return m_catalog; }
    QVariantMap draft() const;
    QVariantMap analysis() const { return m_analysis; }
    QString mode() const { return m_mode; }
    void setMode(const QString &m);
    int timeLeft() const { return m_timeLeft; }
    int currentStep() const { return m_step; }
    bool simulating() const { return m_simulating; }
    void setTeamId(const QString &id);

    Q_INVOKABLE void ensureLoaded();
    /// side: "ally"|"enemy"  kind: "bans"|"picks"  championId vazio limpa o slot (modo manual).
    Q_INVOKABLE void setSlot(const QString &side, const QString &kind, int index, const QString &championId);
    Q_INVOKABLE void clearDraft();
    Q_INVOKABLE void runSimulation();
    Q_INVOKABLE QVariantMap champion(const QString &id) const;
    Q_INVOKABLE bool isTaken(const QString &id) const;

signals:
    void catalogChanged();
    void draftChanged();
    void analysisChanged();
    void modeChanged();
    void timeLeftChanged();
    void simulatingChanged();

private:
    QStringList &slotList(const QString &side, const QString &kind);
    void applySession(const QVariantMap &session);
    void scheduleAnalysis();
    void setSimulating(bool v);

    ILcuBridge *m_lcu;
    QString m_teamId, m_mode = "live";
    QVariantMap m_catalog, m_analysis;
    QHash<QString, QVariantMap> m_byId;
    QStringList m_allyBans, m_allyPicks, m_enemyBans, m_enemyPicks;
    int m_step = 0, m_timeLeft = 0;
    quint64 m_seq = 0, m_lastApplied = 0;
    bool m_simulating = false;
    QTimer m_debounce, m_tick;
};
