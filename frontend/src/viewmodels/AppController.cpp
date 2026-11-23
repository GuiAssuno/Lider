#include "AppController.h"

#include <QFileInfo>
#include <QSettings>

AppController::AppController(IBackendService *backend, ILcuBridge *lcu, QObject *parent)
    : BaseController(backend, parent), m_lcu(lcu)
{
    connect(backend, &IBackendService::responseReady, this, &AppController::onResponse);
    connect(backend, &IBackendService::requestFailed, this, &AppController::onFailure);

    // Estado da ponte LCU -> UI (RF-L11)
    connect(lcu, &ILcuBridge::stateChanged, this, &AppController::lcuStateChanged);
    // Fim de partida -> sincroniza histórico da equipe ativa (RF-L12)
    connect(lcu, &ILcuBridge::gameEnded, this, [this] {
        if (m_activeTeamId.isEmpty()) return;
        emit toast(tr("Partida encerrada — sincronizando histórico da equipe…"));
        this->backend()->syncMatchHistory(m_activeTeamId);
    });
}

QString AppController::version() const { return QStringLiteral(LIDER_VERSION); }

QVariantMap AppController::activeTeam() const
{
    for (const QVariant &v : m_teams)
        if (v.toMap().value("id").toString() == m_activeTeamId) return v.toMap();
    return {};
}

QString AppController::lcuState() const
{
    switch (m_lcu->state()) {
    case ILcuBridge::State::Connected:   return "connected";
    case ILcuBridge::State::ChampSelect: return "champSelect";
    case ILcuBridge::State::InGame:      return "inGame";
    case ILcuBridge::State::EndOfGame:   return "endOfGame";
    default:                             return "disconnected";
    }
}

// ------------------------------------------------------------------ Sessão --
void AppController::login(const QString &email, const QString &password)
{
    setError({}); setLoading(true);
    backend()->loginWithCredentials(email.trimmed(), password);
}

void AppController::loginWithRiot()
{
    setError({}); setLoading(true);
    backend()->loginWithRiot();
}

void AppController::linkAccount(const QString &nick, const QString &tag, const QString &region)
{
    setError({}); setLoading(true);
    backend()->linkRiotAccount(nick, tag, region);
}

void AppController::logout()
{
    m_lcu->stop();
    m_authenticated = false; m_needsLink = false; m_profile.clear(); m_teams.clear(); m_activeTeamId.clear();
    emit authenticatedChanged(); emit needsAccountLinkChanged(); emit profileChanged();
    emit teamsChanged(); emit activeTeamChanging({}); emit activeTeamIdChanged();
}

void AppController::navigate(const QString &route)
{
    if (route == m_route) return;
    m_route = route;
    emit routeChanged();
}

// ------------------------------------------------------------------- Times --
void AppController::refreshTeams() { backend()->fetchTeams(); }

QString AppController::validateLogo(const QUrl &fileUrl) const
{
    if (!fileUrl.isValid() || fileUrl.isEmpty()) return {};
    const QFileInfo fi(fileUrl.toLocalFile());
    const QString ext = fi.suffix().toLower();
    if (!QStringList{"png", "jpg", "jpeg", "webp"}.contains(ext))
        return tr("Formato inválido. Use PNG, JPG ou WebP.");
    if (fi.size() > 2 * 1024 * 1024)
        return tr("A imagem excede o limite de 2 MB.");
    return {};
}

QString AppController::saveTeam(const QVariantMap &team)
{
    if (team.value("name").toString().trimmed().isEmpty()) return tr("Informe o nome do time.");
    const QString tag = team.value("tag").toString().trimmed();
    if (tag.size() < 2 || tag.size() > 5) return tr("A abreviação deve ter de 2 a 5 caracteres.");
    const QVariantList members = team.value("members").toList();
    int valid = 0;
    for (const QVariant &m : members)
        if (!m.toMap().value("nick").toString().trimmed().isEmpty()) ++valid;
    if (valid < 2) return tr("Um time precisa de pelo menos 2 jogadores.");   // RF-L09 (sem limite máximo)
    const QString logoErr = validateLogo(QUrl(team.value("logoPath").toString()));
    if (!logoErr.isEmpty()) return logoErr;

    setLoading(true);
    backend()->saveTeam(team);
    return {};
}

void AppController::deleteTeam(const QString &teamId) { setLoading(true); backend()->deleteTeam(teamId); }

void AppController::setActiveTeam(const QString &teamId) { setActiveInternal(teamId); }

void AppController::setActiveInternal(const QString &id)
{
    if (id == m_activeTeamId) return;
    m_activeTeamId = id;
    QSettings().setValue("session/activeTeamId", id);   // lembra a escolha entre execuções
    emit activeTeamChanging(id);
    emit activeTeamIdChanged();                         // RNF-L03: todas as áreas recarregam sem novo login
}

// --------------------------------------------------------------- Respostas --
void AppController::onResponse(IBackendService::Endpoint ep, const QVariantMap &p)
{
    using E = IBackendService::Endpoint;
    switch (ep) {
    case E::Login:
    case E::LinkAccount: {
        setLoading(false);
        m_profile = p.value("profile").toMap();
        emit profileChanged();
        m_needsLink = p.value("needsLink").toBool();
        emit needsAccountLinkChanged();
        if (ep == E::LinkAccount) emit toast(tr("Perfil atualizado."));
        if (!m_authenticated && !m_needsLink) {
            m_authenticated = true;
            emit authenticatedChanged();
            m_lcu->start();          // só inicia o monitor do cliente após autenticar
            refreshTeams();
        }
        break;
    }
    case E::Teams: {
        setLoading(false);
        m_teams = p.value("teams").toList();
        emit teamsChanged();
        // restaura time ativo salvo; senão usa o sugerido pelo backend; senão o primeiro
        QString wanted = QSettings().value("session/activeTeamId").toString();
        auto exists = [&](const QString &id) {
            for (const QVariant &t : m_teams) if (t.toMap().value("id").toString() == id) return true;
            return false;
        };
        if (!exists(wanted)) wanted = p.value("activeTeamId").toString();
        if (!exists(wanted) && !m_teams.isEmpty()) wanted = m_teams.first().toMap().value("id").toString();
        if (m_teams.isEmpty()) wanted.clear();
        if (wanted == m_activeTeamId) emit activeTeamIdChanged(); // time pode ter sido editado
        else setActiveInternal(wanted);
        break;
    }
    case E::SaveTeam:   emit toast(tr("Time salvo.")); refreshTeams(); break;
    case E::DeleteTeam: emit toast(tr("Time excluído.")); refreshTeams(); break;
    case E::SyncHistory: emit toast(tr("Histórico sincronizado.")); break;
    default: break;
    }
}

void AppController::onFailure(IBackendService::Endpoint ep, const QString &message)
{
    using E = IBackendService::Endpoint;
    if (ep == E::Login || ep == E::LinkAccount || ep == E::Teams || ep == E::SaveTeam || ep == E::DeleteTeam) {
        setLoading(false);
        setError(message);
        emit toast(message);
    }
}
