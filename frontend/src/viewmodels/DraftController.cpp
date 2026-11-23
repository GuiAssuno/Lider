#include "DraftController.h"

DraftController::DraftController(IBackendService *backend, ILcuBridge *lcu, QObject *parent)
    : BaseController(backend, parent), m_lcu(lcu)
{
    m_allyBans = m_allyPicks = m_enemyBans = m_enemyPicks = QStringList{"", "", "", "", ""};

    // Debounce: várias mudanças seguidas geram uma única análise (RNF-D01).
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(60);
    connect(&m_debounce, &QTimer::timeout, this, [this] {
        QVariantMap d = draft();
        d["seq"] = QVariant::fromValue<qulonglong>(++m_seq);
        this->backend()->analyzeDraft(m_teamId, d);
    });

    // Cronômetro da fase de escolha (apenas informativo na UI).
    m_tick.setInterval(1000);
    connect(&m_tick, &QTimer::timeout, this, [this] {
        if (m_timeLeft > 0) { --m_timeLeft; emit timeLeftChanged(); }
    });

    connect(backend, &IBackendService::responseReady, this,
            [this](IBackendService::Endpoint ep, const QVariantMap &p) {
        if (ep == IBackendService::Endpoint::DraftCatalog) {
            m_catalog = p; m_byId.clear();
            for (const QVariant &v : p.value("champions").toList()) m_byId.insert(v.toMap().value("id").toString(), v.toMap());
            setLoading(false); emit catalogChanged();
            scheduleAnalysis();
        } else if (ep == IBackendService::Endpoint::DraftAnalysis) {
            const quint64 seq = p.value("seq").toULongLong();
            if (seq < m_lastApplied) return;          // resposta atrasada: descarta
            m_lastApplied = seq; m_analysis = p; emit analysisChanged();
        }
    });
    connect(backend, &IBackendService::requestFailed, this,
            [this](IBackendService::Endpoint ep, const QString &msg) {
        if (ep == IBackendService::Endpoint::DraftCatalog) { setLoading(false); setError(msg); }
    });

    // Sessão vinda do cliente do LoL (ou do mock).
    connect(lcu, &ILcuBridge::champSelectUpdated, this, [this](const QVariantMap &s) {
        if (m_mode == "live" || m_simulating) applySession(s);
    });
    connect(lcu, &ILcuBridge::stateChanged, this, [this](ILcuBridge::State st) {
        if (st == ILcuBridge::State::InGame || st == ILcuBridge::State::Connected) { m_tick.stop(); setSimulating(false); }
    });
}

void DraftController::setTeamId(const QString &id)
{
    if (id == m_teamId) return;
    m_teamId = id;
    clearDraft();
}

void DraftController::ensureLoaded()
{
    if (m_catalog.isEmpty() && !loading()) { setLoading(true); backend()->fetchDraftCatalog(); }
}

void DraftController::setMode(const QString &m)
{
    if (m == m_mode || (m != "live" && m != "manual")) return;
    m_mode = m; emit modeChanged();
    if (m == "manual") { m_tick.stop(); m_timeLeft = 0; emit timeLeftChanged(); }
}

QVariantMap DraftController::draft() const
{
    return {{"ally", QVariantMap{{"bans", QVariant(m_allyBans)}, {"picks", QVariant(m_allyPicks)}}},
            {"enemy", QVariantMap{{"bans", QVariant(m_enemyBans)}, {"picks", QVariant(m_enemyPicks)}}}};
}

QStringList &DraftController::slotList(const QString &side, const QString &kind)
{
    if (side == "ally") return kind == "bans" ? m_allyBans : m_allyPicks;
    return kind == "bans" ? m_enemyBans : m_enemyPicks;
}

void DraftController::setSlot(const QString &side, const QString &kind, int index, const QString &championId)
{
    QStringList &l = slotList(side, kind);
    if (index < 0 || index >= l.size()) return;
    l[index] = championId;
    emit draftChanged();
    scheduleAnalysis();
}

void DraftController::clearDraft()
{
    m_allyBans = m_allyPicks = m_enemyBans = m_enemyPicks = QStringList{"", "", "", "", ""};
    m_step = 0; m_timeLeft = 0;
    emit draftChanged(); emit timeLeftChanged();
    scheduleAnalysis();
}

void DraftController::runSimulation()
{
    clearDraft();
    setSimulating(true);
    m_lcu->simulateChampSelect();   // o mock emite os 20 passos; o LcuBridge real ignora
}

void DraftController::setSimulating(bool v)
{
    if (m_simulating == v) return;
    m_simulating = v; emit simulatingChanged();
}

void DraftController::applySession(const QVariantMap &s)
{
    const QVariantMap a = s.value("ally").toMap(), e = s.value("enemy").toMap();
    m_allyBans = a.value("bans").toStringList();   m_allyPicks = a.value("picks").toStringList();
    m_enemyBans = e.value("bans").toStringList();  m_enemyPicks = e.value("picks").toStringList();
    m_step = s.value("step").toInt();
    m_timeLeft = s.value("timer").toInt();
    m_tick.start();
    emit draftChanged(); emit timeLeftChanged();
    scheduleAnalysis();
}

void DraftController::scheduleAnalysis() { if (!m_catalog.isEmpty()) m_debounce.start(); }

QVariantMap DraftController::champion(const QString &id) const { return m_byId.value(id); }

bool DraftController::isTaken(const QString &id) const
{
    return m_allyBans.contains(id) || m_allyPicks.contains(id) || m_enemyBans.contains(id) || m_enemyPicks.contains(id);
}
