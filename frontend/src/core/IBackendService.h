// =============================================================================
//  IBackendService — CONTRATO entre o frontend e o backend (API em nuvem)
// =============================================================================
//  Implementacoes concretas em src/services/:
//    • MockBackendService   — dados simulados locais (resources/mock/*.json)
//    • HttpBackendService   — API REST real (QNetworkAccessManager + JWT)
//    • RoutedBackendService — roteia cada Endpoint entre real e mock
//
//  Decisoes de design:
//    • Tudo e ASSINCRONO (nenhum metodo bloqueia a thread da UI).
//    • Os payloads sao QVariantMap (JSON): o QML consome direto, e novos campos
//      nao quebram o frontend (escalabilidade/compatibilidade evolutiva).
//    • Uma unica dupla de sinais (`responseReady`/`requestFailed`) evita explosao
//      de sinais a cada endpoint novo, mais `sessionExpired` para expiracao global.
// =============================================================================
#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class IBackendService : public QObject
{
    Q_OBJECT
public:
    /// Identifica a qual chamada uma resposta pertence.
    enum class Endpoint {
        Login,         ///< payload: { profile:{nick,tag,region,level,iconUrl,email}, needsLink:bool }
        Register,      ///< payload: { profile:{...}, needsLink:bool }
        Logout,        ///< payload: {}
        Me,            ///< payload: { profile:{...}, needsLink:bool, activeTeamId }
        LinkAccount,   ///< payload: { profile:{...}, needsLink:bool }
        Teams,         ///< payload: { teams:[...], activeTeamId }
        SaveTeam,      ///< payload: { team:{...} }
        DeleteTeam,    ///< payload: { teamId }
        ActiveTeam,    ///< payload: { activeTeamId }
        TeamAnalysis,  ///< payload: ver resources/mock/analysis.json
        PlayerStats,   ///< payload: ver resources/mock/players.json (um jogador)
        DraftCatalog,  ///< payload: ver resources/mock/draft.json
        DraftAnalysis, ///< payload: { seq, allyType, confidence, suggestions[], ... }
        Training,      ///< payload: ver resources/mock/training.json
        SyncHistory    ///< payload: { teamId }  (disparado apos fim de partida)
    };
    Q_ENUM(Endpoint)

    explicit IBackendService(QObject *parent = nullptr) : QObject(parent) {}
    ~IBackendService() override = default;

    // ---- Autenticacao, sessao e perfil (RF-L01..L04) ------------------------
    virtual void loginWithCredentials(const QString &email, const QString &password) = 0;
    virtual void registerWithCredentials(const QString &email, const QString &password) = 0;
    virtual void loginWithRiot() = 0;
    virtual void restoreSession() = 0;
    virtual void logoutSession() = 0;
    virtual void linkRiotAccount(const QString &nick, const QString &tag, const QString &region) = 0;

    // ---- Times (RF-L07..L10) ------------------------------------------------
    virtual void fetchTeams() = 0;
    virtual void saveTeam(const QVariantMap &team) = 0;       ///< id vazio => criacao
    virtual void deleteTeam(const QString &teamId) = 0;
    virtual void setActiveTeam(const QString &teamId) = 0;

    // ---- Analise do time (RF-A01..A08) --------------------------------------
    virtual void fetchTeamAnalysis(const QString &teamId) = 0;
    virtual void fetchPlayerStats(const QString &teamId, const QString &playerId) = 0;

    // ---- Draft (RF-D01..D09) ------------------------------------------------
    virtual void fetchDraftCatalog() = 0;
    /// `draft` = { seq, ally:{bans[],picks[]}, enemy:{bans[],picks[]} }.
    /// O backend DEVE devolver o mesmo `seq` para descartar respostas atrasadas.
    virtual void analyzeDraft(const QString &teamId, const QVariantMap &draft) = 0;

    // ---- Treino (RF-T01..T03) -----------------------------------------------
    virtual void fetchTraining(const QString &teamId) = 0;

    // ---- Sincronizacao (RF-L12) ---------------------------------------------
    virtual void syncMatchHistory(const QString &teamId) = 0;

signals:
    void responseReady(IBackendService::Endpoint endpoint, const QVariantMap &payload);
    void requestFailed(IBackendService::Endpoint endpoint, const QString &message);
    void sessionExpired(const QString &message);
};
