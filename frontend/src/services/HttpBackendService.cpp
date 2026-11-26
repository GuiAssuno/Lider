#include "HttpBackendService.h"
#include "TokenStore.h"

#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace {
constexpr int kDefaultTimeoutMs = 10000;

QString normalizeBaseUrl(QString url)
{
    url = url.trimmed();
    while (url.endsWith('/'))
        url.chop(1);
    return url;
}
}

HttpBackendService::HttpBackendService(const QString &baseUrl, QObject *parent)
    : IBackendService(parent)
    , m_baseUrl(normalizeBaseUrl(baseUrl))
{
}

// ------------------------------------------------------------ Autenticacao ---
void HttpBackendService::loginWithCredentials(const QString &email, const QString &password)
{
    sendRequest({
        Endpoint::Login,
        "POST",
        QStringLiteral("/auth/login"),
        QJsonObject{{"email", email}, {"password", password}},
        true,
        false,
        false,
    });
}

void HttpBackendService::registerWithCredentials(const QString &email, const QString &password)
{
    sendRequest({
        Endpoint::Register,
        "POST",
        QStringLiteral("/auth/register"),
        QJsonObject{{"email", email}, {"password", password}},
        true,
        false,
        false,
    });
}

void HttpBackendService::loginWithRiot()
{
    emit requestFailed(
        Endpoint::Login,
        tr("Login com Riot (RSO) ainda não está disponível. Entre com e-mail e senha."));
}

void HttpBackendService::restoreSession()
{
    const QString storedRefresh = TokenStore::loadRefreshToken();
    if (storedRefresh.isEmpty()) {
        emit requestFailed(Endpoint::Me, QString());
        return;
    }

    m_restoringSession = true;
    m_pendingAfterRefresh.append({
        Endpoint::Me,
        "GET",
        QStringLiteral("/me"),
        {},
        false,
        true,
        true,
    });
    startRefresh();
}

void HttpBackendService::logoutSession()
{
    // Invalida qualquer resposta atrasada da sessao anterior.
    ++m_sessionEpoch;
    m_refreshInFlight = false;
    m_restoringSession = false;
    m_pendingAfterRefresh.clear();

    const QString refreshToken = TokenStore::loadRefreshToken();
    m_accessToken.clear();
    TokenStore::clearRefreshToken();

    if (!refreshToken.isEmpty()) {
        QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/auth/logout")));
        req.setTransferTimeout(kDefaultTimeoutMs);
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        const QByteArray payload = QJsonDocument(QJsonObject{{"refreshToken", refreshToken}})
                                       .toJson(QJsonDocument::Compact);
        QNetworkReply *reply = m_net.post(req, payload);
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }

    emit responseReady(Endpoint::Logout, {});
}

void HttpBackendService::linkRiotAccount(const QString &nick, const QString &tag,
                                         const QString &region)
{
    sendRequest({
        Endpoint::LinkAccount,
        "PUT",
        QStringLiteral("/me/riot-account"),
        QJsonObject{{"nick", nick}, {"tag", tag}, {"region", region}},
        true,
        true,
        false,
    });
}

// ------------------------------------------------------------------ Times ----
void HttpBackendService::fetchTeams()
{
    sendRequest({
        Endpoint::Teams,
        "GET",
        QStringLiteral("/teams"),
        {},
        false,
        true,
        false,
    });
}

void HttpBackendService::saveTeam(const QVariantMap &team)
{
    const QString teamId = team.value(QStringLiteral("id")).toString().trimmed();
    const bool isNew = teamId.isEmpty();

    QJsonObject body = QJsonObject::fromVariantMap(team);
    body.remove(QStringLiteral("id"));

    const QString encodedId = QString::fromUtf8(QUrl::toPercentEncoding(teamId));
    sendRequest({
        Endpoint::SaveTeam,
        isNew ? QByteArray("POST") : QByteArray("PUT"),
        isNew ? QStringLiteral("/teams") : (QStringLiteral("/teams/") + encodedId),
        body,
        true,
        true,
        false,
    });
}

void HttpBackendService::deleteTeam(const QString &teamId)
{
    const QString encodedId = QString::fromUtf8(QUrl::toPercentEncoding(teamId.trimmed()));
    sendRequest({
        Endpoint::DeleteTeam,
        "DELETE",
        QStringLiteral("/teams/") + encodedId,
        {},
        false,
        true,
        false,
    });
}

void HttpBackendService::setActiveTeam(const QString &teamId)
{
    sendRequest({
        Endpoint::ActiveTeam,
        "PUT",
        QStringLiteral("/me/active-team"),
        QJsonObject{{"teamId", teamId}},
        true,
        true,
        false,
    });
}

// ----------------------------------------- Endpoints ainda nao migrados ------
void HttpBackendService::fetchTeamAnalysis(const QString &teamId)
{
    Q_UNUSED(teamId)
    emit requestFailed(Endpoint::TeamAnalysis, tr("Análise ainda não disponível neste servidor."));
}

void HttpBackendService::fetchPlayerStats(const QString &teamId, const QString &playerId)
{
    Q_UNUSED(teamId)
    Q_UNUSED(playerId)
    emit requestFailed(Endpoint::PlayerStats, tr("Estatísticas de jogador ainda não disponíveis neste servidor."));
}

void HttpBackendService::fetchDraftCatalog()
{
    emit requestFailed(Endpoint::DraftCatalog, tr("Catálogo do draft ainda não disponível neste servidor."));
}

void HttpBackendService::analyzeDraft(const QString &teamId, const QVariantMap &draft)
{
    Q_UNUSED(teamId)
    Q_UNUSED(draft)
    emit requestFailed(Endpoint::DraftAnalysis, tr("Motor de draft ainda não disponível neste servidor."));
}

void HttpBackendService::fetchTraining(const QString &teamId)
{
    Q_UNUSED(teamId)
    emit requestFailed(Endpoint::Training, tr("Treino ainda não disponível neste servidor."));
}

void HttpBackendService::syncMatchHistory(const QString &teamId)
{
    Q_UNUSED(teamId)
    emit requestFailed(Endpoint::SyncHistory, tr("Sincronização ainda não disponível neste servidor."));
}

// ----------------------------------------------------- Nucleo HTTP & Refresh -
void HttpBackendService::sendRequest(const PendingRequest &req)
{
    // Se uma renovacao de token ja esta rodando, enfileira chamadas autenticadas
    // para evitar disparar multiplos 401 em paralelo.
    if (req.authenticated && m_refreshInFlight) {
        m_pendingAfterRefresh.append(req);
        return;
    }

    QNetworkRequest netReq(QUrl(m_baseUrl + req.path));
    netReq.setTransferTimeout(kDefaultTimeoutMs);
    netReq.setRawHeader("Accept", "application/json");
    if (req.authenticated && !m_accessToken.isEmpty())
        netReq.setRawHeader("Authorization", "Bearer " + m_accessToken.toUtf8());

    QByteArray payload;
    if (req.hasBody) {
        netReq.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        payload = QJsonDocument(req.body).toJson(QJsonDocument::Compact);
    }

    const quint64 epoch = m_sessionEpoch;
    QNetworkReply *reply = m_net.sendCustomRequest(netReq, req.verb, payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply, req, epoch] {
        reply->deleteLater();
        if (epoch != m_sessionEpoch)
            return;

        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray rawBody = reply->readAll();

        // 401 em rota autenticada -> tenta renovar o token uma unica vez.
        if (statusCode == 401 && req.authenticated && !req.alreadyRetried) {
            PendingRequest retry = req;
            retry.alreadyRetried = true;
            m_pendingAfterRefresh.append(retry);
            startRefresh();
            return;
        }

        if (statusCode == 204) {
            emit responseReady(req.endpoint, {});
            return;
        }

        if (reply->error() != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300) {
            if (req.endpoint == Endpoint::Me && m_restoringSession) {
                m_restoringSession = false;
                if (statusCode == 401) {
                    m_accessToken.clear();
                    TokenStore::clearRefreshToken();
                    emit requestFailed(Endpoint::Me, QString());
                    return;
                }
            }
            emit requestFailed(req.endpoint, extractErrorMessage(reply, rawBody, statusCode));
            return;
        }

        QJsonObject obj;
        if (!rawBody.isEmpty()) {
            const QJsonDocument doc = QJsonDocument::fromJson(rawBody);
            if (doc.isObject())
                obj = doc.object();
        }

        if (req.endpoint == Endpoint::Login || req.endpoint == Endpoint::Register) {
            const QString access = obj.value(QStringLiteral("accessToken")).toString();
            const QString refresh = obj.value(QStringLiteral("refreshToken")).toString();
            if (!access.isEmpty())
                m_accessToken = access;
            if (!refresh.isEmpty())
                TokenStore::saveRefreshToken(refresh);

            // Nunca repassa tokens para controllers/QML.
            obj.remove(QStringLiteral("accessToken"));
            obj.remove(QStringLiteral("refreshToken"));
            obj.remove(QStringLiteral("tokenType"));
            obj.remove(QStringLiteral("expiresIn"));
        }

        if (req.endpoint == Endpoint::Me)
            m_restoringSession = false;

        emit responseReady(req.endpoint, obj.toVariantMap());
    });
}

void HttpBackendService::startRefresh()
{
    if (m_refreshInFlight)
        return;

    const QString refreshToken = TokenStore::loadRefreshToken();
    if (refreshToken.isEmpty()) {
        const bool wasRestoring = m_restoringSession;
        m_restoringSession = false;
        m_accessToken.clear();
        m_pendingAfterRefresh.clear();
        if (wasRestoring)
            emit requestFailed(Endpoint::Me, QString());
        else
            emit sessionExpired(tr("Sessão expirada. Faça login novamente."));
        return;
    }

    m_refreshInFlight = true;
    const quint64 epoch = m_sessionEpoch;

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/auth/refresh")));
    req.setTransferTimeout(kDefaultTimeoutMs);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Accept", "application/json");
    const QByteArray payload = QJsonDocument(QJsonObject{{"refreshToken", refreshToken}})
                                   .toJson(QJsonDocument::Compact);

    QNetworkReply *reply = m_net.post(req, payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply, epoch] {
        handleRefreshFinished(reply, epoch);
    });
}

void HttpBackendService::handleRefreshFinished(QNetworkReply *reply, quint64 epoch)
{
    reply->deleteLater();
    if (epoch != m_sessionEpoch)
        return;

    m_refreshInFlight = false;
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray rawBody = reply->readAll();

    const QList<PendingRequest> queued = m_pendingAfterRefresh;
    m_pendingAfterRefresh.clear();

    if (reply->error() == QNetworkReply::NoError && statusCode >= 200 && statusCode < 300) {
        const QJsonObject obj = QJsonDocument::fromJson(rawBody).object();
        const QString newAccess = obj.value(QStringLiteral("accessToken")).toString();
        const QString newRefresh = obj.value(QStringLiteral("refreshToken")).toString();
        if (!newAccess.isEmpty() && !newRefresh.isEmpty()) {
            m_accessToken = newAccess;
            TokenStore::saveRefreshToken(newRefresh);
            for (const PendingRequest &pending : queued)
                sendRequest(pending);
            return;
        }
    }

    const bool wasRestoring = m_restoringSession;
    m_restoringSession = false;

    // 401/403 indica token invalido, expirado ou reutilizado -> encerra sessao.
    if (statusCode == 401 || statusCode == 403) {
        ++m_sessionEpoch;
        m_accessToken.clear();
        TokenStore::clearRefreshToken();
        if (wasRestoring) {
            emit requestFailed(Endpoint::Me, QString());
        } else {
            emit sessionExpired(extractErrorMessage(reply, rawBody, statusCode));
        }
        return;
    }

    // Queda de rede / timeout: preserva o refresh token no cofre e reporta erro.
    const QString errMsg = extractErrorMessage(reply, rawBody, statusCode);
    for (const PendingRequest &pending : queued)
        emit requestFailed(pending.endpoint, wasRestoring ? QString() : errMsg);
}

QString HttpBackendService::extractErrorMessage(QNetworkReply *reply, const QByteArray &rawBody,
                                                int statusCode) const
{
    if (!rawBody.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(rawBody);
        if (doc.isObject()) {
            const QString msg = doc.object().value(QStringLiteral("message")).toString().trimmed();
            if (!msg.isEmpty())
                return msg;
        }
    }

    if (reply->error() == QNetworkReply::TimeoutError ||
        reply->error() == QNetworkReply::OperationCanceledError) {
        return tr("Tempo limite excedido ao conectar ao servidor.");
    }

    if (statusCode == 0)
        return tr("Sem conexão com o servidor.");
    if (statusCode == 401)
        return tr("Sessão expirada. Faça login novamente.");
    if (statusCode >= 500)
        return tr("Erro interno no servidor. Tente novamente.");

    return tr("Não foi possível concluir a requisição.");
}
