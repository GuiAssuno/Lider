// =============================================================================
//  MockBackendService — implementação FAKE do backend (desenvolvimento/testes)
// =============================================================================
//  • Lê os JSONs embutidos (":/mock/*.json") e responde com latência simulada.
//  • Mantém times em memória para exercitar o CRUD (RF-L07..L10).
//  • Calcula a análise de draft localmente a partir das tags dos campeões,
//    demonstrando o requisito de resposta < 1 s (RNF-D01).
//  Substitua por um `HttpBackendService` mantendo a interface IBackendService.
// =============================================================================
#pragma once

#include "core/IBackendService.h"

class MockBackendService : public IBackendService
{
    Q_OBJECT
public:
    explicit MockBackendService(QObject *parent = nullptr);

    void loginWithCredentials(const QString &email, const QString &password) override;
    void loginWithRiot() override;
    void linkRiotAccount(const QString &nick, const QString &tag, const QString &region) override;
    void fetchTeams() override;
    void saveTeam(const QVariantMap &team) override;
    void deleteTeam(const QString &teamId) override;
    void fetchTeamAnalysis(const QString &teamId) override;
    void fetchPlayerStats(const QString &teamId, const QString &playerId) override;
    void fetchDraftCatalog() override;
    void analyzeDraft(const QString &teamId, const QVariantMap &draft) override;
    void fetchTraining(const QString &teamId) override;
    void syncMatchHistory(const QString &teamId) override;

private:
    /// Emite a resposta após `delayMs` (simula rede). Usa o contexto `this`.
    void reply(Endpoint ep, const QVariantMap &payload, int delayMs = 220);
    void fail(Endpoint ep, const QString &msg, int delayMs = 220);

    static QVariantMap loadJson(const QString &resource);
    QVariantMap buildProfile(const QString &nick, const QString &tag, const QString &region) const;
    QVariantMap computeDraftAnalysis(const QVariantMap &draft) const;

    QVariantList m_teams;       // estado em memória
    QString m_activeTeamId;
    QVariantMap m_catalog;      // cache de draft.json
    QVariantMap m_profile;
    int m_nextTeamId = 100;
};
