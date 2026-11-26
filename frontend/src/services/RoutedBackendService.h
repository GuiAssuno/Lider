// =============================================================================
//  RoutedBackendService — roteia cada Endpoint entre API real e Mock
// =============================================================================
//  Permite migrar o launcher etapa a etapa sem mexer em controllers ou telas.
//  Na Etapa 3, autenticacao, perfil e times vao para HttpBackendService;
//  analise, draft, treino e sync continuam no MockBackendService.
// =============================================================================
#pragma once

#include "core/IBackendService.h"

#include <QSet>

class RoutedBackendService : public IBackendService
{
    Q_OBJECT
public:
    RoutedBackendService(IBackendService *realService,
                         IBackendService *mockService,
                         QObject *parent = nullptr);

    void loginWithCredentials(const QString &email, const QString &password) override;
    void registerWithCredentials(const QString &email, const QString &password) override;
    void loginWithRiot() override;
    void restoreSession() override;
    void logoutSession() override;
    void linkRiotAccount(const QString &nick, const QString &tag, const QString &region) override;

    void fetchTeams() override;
    void saveTeam(const QVariantMap &team) override;
    void deleteTeam(const QString &teamId) override;
    void setActiveTeam(const QString &teamId) override;

    void fetchTeamAnalysis(const QString &teamId) override;
    void fetchPlayerStats(const QString &teamId, const QString &playerId) override;
    void fetchDraftCatalog() override;
    void analyzeDraft(const QString &teamId, const QVariantMap &draft) override;
    void fetchTraining(const QString &teamId) override;
    void syncMatchHistory(const QString &teamId) override;

private:
    IBackendService *targetFor(Endpoint ep) const;

    IBackendService *m_real;
    IBackendService *m_mock;
    QSet<Endpoint> m_realEndpoints;
};
