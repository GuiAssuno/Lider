// =============================================================================
//  AppController — estado GLOBAL do launcher (sessão, perfil, navegação, times, LCU)
// =============================================================================
//  Exposto ao QML como singleton `App` (import Lider.Core).
//  Responsabilidades (ver RF-L01..L12 / RNF-L03):
//    • autenticação e vínculo Riot (Nick/Tag/Região)
//    • rota atual da navegação lateral
//    • CRUD de times, time ativo (persistido em QSettings)
//    • estado da ponte LCU e gatilho de sincronização ao fim de partidas
// =============================================================================
#pragma once

#include "BaseController.h"
#include "core/ILcuBridge.h"
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class AppController : public BaseController
{
    Q_OBJECT
    Q_PROPERTY(QString version READ version CONSTANT)
    // Sessão
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(bool needsAccountLink READ needsAccountLink NOTIFY needsAccountLinkChanged)
    Q_PROPERTY(bool restoringSession READ restoringSession NOTIFY restoringSessionChanged)
    Q_PROPERTY(QVariantMap profile READ profile NOTIFY profileChanged)
    // Navegação
    Q_PROPERTY(QString route READ route NOTIFY routeChanged)
    // Times
    Q_PROPERTY(QVariantList teams READ teams NOTIFY teamsChanged)
    Q_PROPERTY(QString activeTeamId READ activeTeamId NOTIFY activeTeamIdChanged)
    Q_PROPERTY(QVariantMap activeTeam READ activeTeam NOTIFY activeTeamIdChanged)
    // LCU: "disconnected" | "connected" | "champSelect" | "inGame" | "endOfGame"
    Q_PROPERTY(QString lcuState READ lcuState NOTIFY lcuStateChanged)

public:
    AppController(IBackendService *backend, ILcuBridge *lcu, QObject *parent = nullptr);

    QString version() const;
    bool authenticated() const { return m_authenticated; }
    bool needsAccountLink() const { return m_needsLink; }
    bool restoringSession() const { return m_restoringSession; }
    QVariantMap profile() const { return m_profile; }
    QString route() const { return m_route; }
    QVariantList teams() const { return m_teams; }
    QString activeTeamId() const { return m_activeTeamId; }
    QVariantMap activeTeam() const;
    QString lcuState() const;

    // ---- Sessão ----
    Q_INVOKABLE void login(const QString &email, const QString &password);
    Q_INVOKABLE void registerAccount(const QString &email, const QString &password);
    Q_INVOKABLE void loginWithRiot();
    Q_INVOKABLE void restoreSession();
    Q_INVOKABLE void linkAccount(const QString &nick, const QString &tag, const QString &region);
    Q_INVOKABLE void logout();
    // ---- Navegação ----
    Q_INVOKABLE void navigate(const QString &route);
    // ---- Times ----
    Q_INVOKABLE void refreshTeams();
    /// Valida e salva. Retorna "" se OK, ou a mensagem de erro (RF-L08/L09, RNF-L02).
    Q_INVOKABLE QString saveTeam(const QVariantMap &team);
    Q_INVOKABLE void deleteTeam(const QString &teamId);
    Q_INVOKABLE void setActiveTeam(const QString &teamId);
    /// Valida arquivo de logo: PNG/JPG/WebP e até 2 MB. Retorna "" se OK.
    Q_INVOKABLE QString validateLogo(const QUrl &fileUrl) const;
    Q_INVOKABLE void notify(const QString &message) { emit toast(message); }

signals:
    void authenticatedChanged();
    void needsAccountLinkChanged();
    void restoringSessionChanged();
    void profileChanged();
    void routeChanged();
    void teamsChanged();
    void activeTeamIdChanged();
    /// Emitido ANTES de activeTeamIdChanged. Use-o (em C++) para propagar o contexto aos demais
    /// controllers: os bindings do QML reagem primeiro a activeTeamIdChanged, então a ordem importa.
    void activeTeamChanging(const QString &teamId);
    void lcuStateChanged();
    void toast(const QString &message);   ///< mensagens rápidas (snackbar)

private slots:
    void onResponse(IBackendService::Endpoint ep, const QVariantMap &payload);
    void onFailure(IBackendService::Endpoint ep, const QString &message);
    void onSessionExpired(const QString &message);

private:
    void setActiveInternal(const QString &id);
    void clearSessionLocal();

    ILcuBridge *m_lcu;
    bool m_authenticated = false;
    bool m_needsLink = false;
    bool m_restoringSession = false;
    QVariantMap m_profile;
    QString m_route = "analysis";
    QVariantList m_teams;
    QString m_activeTeamId;
};
