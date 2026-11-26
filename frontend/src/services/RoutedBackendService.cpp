#include "RoutedBackendService.h"

RoutedBackendService::RoutedBackendService(IBackendService *realService,
                                           IBackendService *mockService,
                                           QObject *parent)
    : IBackendService(parent)
    , m_real(realService)
    , m_mock(mockService)
    , m_realEndpoints{
          Endpoint::Login,
          Endpoint::Register,
          Endpoint::Logout,
          Endpoint::Me,
          Endpoint::LinkAccount,
          Endpoint::Teams,
          Endpoint::SaveTeam,
          Endpoint::DeleteTeam,
          Endpoint::ActiveTeam,
      }
{
    auto forwardSignals = [this](IBackendService *svc) {
        if (!svc)
            return;
        connect(svc, &IBackendService::responseReady, this, &IBackendService::responseReady);
        connect(svc, &IBackendService::requestFailed, this, &IBackendService::requestFailed);
        connect(svc, &IBackendService::sessionExpired, this, &IBackendService::sessionExpired);
    };
    forwardSignals(m_real);
    forwardSignals(m_mock);
}

IBackendService *RoutedBackendService::targetFor(Endpoint ep) const
{
    return (m_real && m_realEndpoints.contains(ep)) ? m_real : m_mock;
}

void RoutedBackendService::loginWithCredentials(const QString &email, const QString &password)
{
    targetFor(Endpoint::Login)->loginWithCredentials(email, password);
}

void RoutedBackendService::registerWithCredentials(const QString &email, const QString &password)
{
    targetFor(Endpoint::Register)->registerWithCredentials(email, password);
}

void RoutedBackendService::loginWithRiot()
{
    targetFor(Endpoint::Login)->loginWithRiot();
}

void RoutedBackendService::restoreSession()
{
    targetFor(Endpoint::Me)->restoreSession();
}

void RoutedBackendService::logoutSession()
{
    targetFor(Endpoint::Logout)->logoutSession();
}

void RoutedBackendService::linkRiotAccount(const QString &nick, const QString &tag,
                                           const QString &region)
{
    targetFor(Endpoint::LinkAccount)->linkRiotAccount(nick, tag, region);
}

void RoutedBackendService::fetchTeams()
{
    targetFor(Endpoint::Teams)->fetchTeams();
}

void RoutedBackendService::saveTeam(const QVariantMap &team)
{
    targetFor(Endpoint::SaveTeam)->saveTeam(team);
}

void RoutedBackendService::deleteTeam(const QString &teamId)
{
    targetFor(Endpoint::DeleteTeam)->deleteTeam(teamId);
}

void RoutedBackendService::setActiveTeam(const QString &teamId)
{
    targetFor(Endpoint::ActiveTeam)->setActiveTeam(teamId);
}

void RoutedBackendService::fetchTeamAnalysis(const QString &teamId)
{
    targetFor(Endpoint::TeamAnalysis)->fetchTeamAnalysis(teamId);
}

void RoutedBackendService::fetchPlayerStats(const QString &teamId, const QString &playerId)
{
    targetFor(Endpoint::PlayerStats)->fetchPlayerStats(teamId, playerId);
}

void RoutedBackendService::fetchDraftCatalog()
{
    targetFor(Endpoint::DraftCatalog)->fetchDraftCatalog();
}

void RoutedBackendService::analyzeDraft(const QString &teamId, const QVariantMap &draft)
{
    targetFor(Endpoint::DraftAnalysis)->analyzeDraft(teamId, draft);
}

void RoutedBackendService::fetchTraining(const QString &teamId)
{
    targetFor(Endpoint::Training)->fetchTraining(teamId);
}

void RoutedBackendService::syncMatchHistory(const QString &teamId)
{
    targetFor(Endpoint::SyncHistory)->syncMatchHistory(teamId);
}
