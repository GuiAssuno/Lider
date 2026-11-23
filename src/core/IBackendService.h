// =============================================================================
//  IBackendService — CONTRATO entre o frontend e o backend (API em nuvem)
// =============================================================================
//  Para integrar o backend real:
//    1) Crie `HttpBackendService : public IBackendService` (QNetworkAccessManager).
//    2) Implemente cada método disparando a requisição HTTPS correspondente.
//    3) Ao concluir, emita `responseReady(endpoint, payload)` com o MESMO formato
//       JSON dos arquivos em resources/mock/ (ele é o contrato de dados).
//       Em erro, emita `requestFailed(endpoint, mensagem)`.
//    4) Troque `MockBackendService` por `HttpBackendService` em src/main.cpp.
//
//  Decisões de design:
//    • Tudo é ASSÍNCRONO (nenhum método bloqueia a thread da UI).
//    • Os payloads são QVariantMap (JSON): o QML consome direto, e novos campos
//      não quebram o frontend (escalabilidade/compatibilidade evolutiva).
//    • Uma única dupla de sinais (`responseReady`/`requestFailed`) evita explosão
//      de sinais a cada endpoint novo.
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
        LinkAccount,   ///< payload: { profile:{...} }
        Teams,         ///< payload: { teams:[...], activeTeamId }
        SaveTeam,      ///< payload: { team:{...} }
        DeleteTeam,    ///< payload: { teamId }
        TeamAnalysis,  ///< payload: ver resources/mock/analysis.json
        PlayerStats,   ///< payload: ver resources/mock/players.json (um jogador)
        DraftCatalog,  ///< payload: ver resources/mock/draft.json
        DraftAnalysis, ///< payload: { seq, allyType, confidence, suggestions[], ... }
        Training,      ///< payload: ver resources/mock/training.json
        SyncHistory    ///< payload: { teamId }  (disparado após fim de partida)
    };
    Q_ENUM(Endpoint)

    explicit IBackendService(QObject *parent = nullptr) : QObject(parent) {}
    ~IBackendService() override = default;

    // ---- Autenticação e perfil (RF-L01..L04) --------------------------------
    virtual void loginWithCredentials(const QString &email, const QString &password) = 0;
    virtual void loginWithRiot() = 0;
    virtual void linkRiotAccount(const QString &nick, const QString &tag, const QString &region) = 0;

    // ---- Times (RF-L07..L10) ------------------------------------------------
    virtual void fetchTeams() = 0;
    virtual void saveTeam(const QVariantMap &team) = 0;       ///< id vazio => criação
    virtual void deleteTeam(const QString &teamId) = 0;

    // ---- Análise do time (RF-A01..A08) ---------------------------------------
    virtual void fetchTeamAnalysis(const QString &teamId) = 0;
    virtual void fetchPlayerStats(const QString &teamId, const QString &playerId) = 0;

    // ---- Draft (RF-D01..D09) -------------------------------------------------
    virtual void fetchDraftCatalog() = 0;
    /// `draft` = { seq, ally:{bans[],picks[]}, enemy:{bans[],picks[]} }.
    /// O backend DEVE devolver o mesmo `seq` para descartar respostas atrasadas.
    virtual void analyzeDraft(const QString &teamId, const QVariantMap &draft) = 0;

    // ---- Treino (RF-T01..T03) ------------------------------------------------
    virtual void fetchTraining(const QString &teamId) = 0;

    // ---- Sincronização (RF-L12) ----------------------------------------------
    virtual void syncMatchHistory(const QString &teamId) = 0;

signals:
    void responseReady(IBackendService::Endpoint endpoint, const QVariantMap &payload);
    void requestFailed(IBackendService::Endpoint endpoint, const QString &message);
};
