// =============================================================================
//  HttpBackendService — cliente HTTP/HTTPS da API REST LIDER
// =============================================================================
//  • Access token mantido apenas em memoria; refresh token no cofre (TokenStore).
//  • Renovacao automatica em 401 com fila unica (single-flight), respeitando
//    o refresh token de uso unico da API.
//  • Descarta respostas atrasadas de sessoes encerradas (m_sessionEpoch).
//  • Remove tokens do payload antes de emitir responseReady para a UI/QML.
// =============================================================================
#pragma once

#include "core/IBackendService.h"

#include <QByteArray>
#include <QJsonObject>
#include <QList>
#include <QNetworkAccessManager>

class QNetworkReply;

class HttpBackendService : public IBackendService
{
    Q_OBJECT
public:
    explicit HttpBackendService(const QString &baseUrl, QObject *parent = nullptr);

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
    struct PendingRequest {
        Endpoint endpoint;
        QByteArray verb;
        QString path;
        QJsonObject body;
        bool hasBody = false;
        bool authenticated = true;
        bool alreadyRetried = false;
    };

    void sendRequest(const PendingRequest &req);
    void startRefresh();
    void handleRefreshFinished(QNetworkReply *reply, quint64 epoch);
    QString extractErrorMessage(QNetworkReply *reply, const QByteArray &rawBody, int statusCode) const;

    QString m_baseUrl;
    QNetworkAccessManager m_net;
    QString m_accessToken;
    quint64 m_sessionEpoch = 0;
    bool m_refreshInFlight = false;
    bool m_restoringSession = false;
    QList<PendingRequest> m_pendingAfterRefresh;
};
