#include "MockBackendService.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <algorithm>

namespace {
/// Rótulos exibidos para cada arquétipo de composição (RF-D04).
const QList<QPair<QString, QString>> kArchetypes = {
    {"dive", "Dive"}, {"poke", "Poke"}, {"disengage", "Desengaje"}, {"split", "Split Push"}};
const QStringList kRoles = {"Topo", "Selva", "Meio", "Atirador", "Suporte"};
}

MockBackendService::MockBackendService(QObject *parent) : IBackendService(parent)
{
    const QVariantMap t = loadJson(":/mock/teams.json");
    m_teams = t.value("teams").toList();
    m_activeTeamId = t.value("activeTeamId").toString();
    m_catalog = loadJson(":/mock/draft.json");
}

QVariantMap MockBackendService::loadJson(const QString &resource)
{
    QFile f(resource);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(f.readAll()).object().toVariantMap();
}

void MockBackendService::reply(Endpoint ep, const QVariantMap &payload, int delayMs)
{
    QTimer::singleShot(delayMs, this, [this, ep, payload] { emit responseReady(ep, payload); });
}

void MockBackendService::fail(Endpoint ep, const QString &msg, int delayMs)
{
    QTimer::singleShot(delayMs, this, [this, ep, msg] { emit requestFailed(ep, msg); });
}

// ------------------------------------------------------------------ Auth ----
QVariantMap MockBackendService::buildProfile(const QString &nick, const QString &tag,
                                             const QString &region) const
{
    return {{"nick", nick}, {"tag", tag}, {"region", region}, {"level", 999}, {"iconUrl", ""}};
}

void MockBackendService::loginWithCredentials(const QString &email, const QString &password)
{
    if (!email.contains('@') || password.size() < 4) {
        fail(Endpoint::Login, tr("E-mail ou senha inválidos."));
        return;
    }
    // Convenção do mock: e-mails com "novo" simulam primeiro acesso (exige vínculo Riot).
    const bool firstAccess = email.contains("novo");
    m_profile = firstAccess ? QVariantMap{{"email", email}}
                            : buildProfile("Nicktag", "BR1", "BR");
    m_profile["email"] = email;
    reply(Endpoint::Login, {{"profile", m_profile}, {"needsLink", firstAccess}}, 450);
}

void MockBackendService::registerWithCredentials(const QString &email, const QString &password)
{
    if (!email.contains('@')) {
        fail(Endpoint::Register, tr("Informe um e-mail válido."));
        return;
    }
    if (password.size() < 8) {
        fail(Endpoint::Register, tr("A senha deve ter pelo menos 8 caracteres."));
        return;
    }
    m_profile = QVariantMap{{"email", email}};
    reply(Endpoint::Register, {{"profile", m_profile}, {"needsLink", true}}, 450);
}

void MockBackendService::loginWithRiot()
{
    m_profile = buildProfile("Nicktag", "BR1", "BR");
    reply(Endpoint::Login, {{"profile", m_profile}, {"needsLink", false}}, 600);
}

void MockBackendService::restoreSession()
{
    // Modo mock nao persiste sessao entre execucoes (mensagem vazia = silencioso).
    fail(Endpoint::Me, QString(), 0);
}

void MockBackendService::logoutSession()
{
    m_profile.clear();
    reply(Endpoint::Logout, {}, 0);
}

void MockBackendService::linkRiotAccount(const QString &nick, const QString &tag, const QString &region)
{
    if (nick.trimmed().isEmpty() || tag.trimmed().isEmpty()) {
        fail(Endpoint::LinkAccount, tr("Informe Nick e Tag."));
        return;
    }
    const QString email = m_profile.value("email").toString();
    m_profile = buildProfile(nick.trimmed(), tag.trimmed(), region);
    m_profile["email"] = email;
    reply(Endpoint::LinkAccount, {{"profile", m_profile}, {"needsLink", false}}, 400);
}

// ----------------------------------------------------------------- Times ----
void MockBackendService::fetchTeams()
{
    reply(Endpoint::Teams, {{"teams", m_teams}, {"activeTeamId", m_activeTeamId}});
}

void MockBackendService::saveTeam(const QVariantMap &team)
{
    QVariantMap t = team;
    if (t.value("id").toString().isEmpty()) {
        t["id"] = QString("t%1").arg(m_nextTeamId++);
        m_teams.append(t);
    } else {
        for (int i = 0; i < m_teams.size(); ++i)
            if (m_teams[i].toMap().value("id") == t.value("id")) m_teams[i] = t;
    }
    // garante ids estáveis para os membros novos
    QVariantList members = t.value("members").toList();
    for (int i = 0; i < members.size(); ++i) {
        QVariantMap m = members[i].toMap();
        if (m.value("id").toString().isEmpty())
            m["id"] = QString("%1_m%2").arg(t.value("id").toString()).arg(i + 1);
        members[i] = m;
    }
    t["members"] = members;
    for (int i = 0; i < m_teams.size(); ++i)
        if (m_teams[i].toMap().value("id") == t.value("id")) m_teams[i] = t;
    if (m_activeTeamId.isEmpty()) m_activeTeamId = t.value("id").toString();
    reply(Endpoint::SaveTeam, {{"team", t}}, 300);
}

void MockBackendService::deleteTeam(const QString &teamId)
{
    m_teams.erase(std::remove_if(m_teams.begin(), m_teams.end(),
                  [&](const QVariant &v) { return v.toMap().value("id") == teamId; }), m_teams.end());
    if (m_activeTeamId == teamId)
        m_activeTeamId = m_teams.isEmpty() ? QString() : m_teams.first().toMap().value("id").toString();
    reply(Endpoint::DeleteTeam, {{"teamId", teamId}}, 250);
}

void MockBackendService::setActiveTeam(const QString &teamId)
{
    m_activeTeamId = teamId;
    reply(Endpoint::ActiveTeam, {{"activeTeamId", m_activeTeamId}}, 80);
}

// -------------------------------------------------------------- Análise -----
void MockBackendService::fetchTeamAnalysis(const QString &teamId)
{
    Q_UNUSED(teamId) // mock: mesmo conjunto de dados para qualquer time
    reply(Endpoint::TeamAnalysis, loadJson(":/mock/analysis.json"), 500);
}

void MockBackendService::fetchPlayerStats(const QString &teamId, const QString &playerId)
{
    Q_UNUSED(teamId)
    const QVariantMap all = loadJson(":/mock/players.json");
    QVariantMap p = all.value(playerId).toMap();
    p["id"] = playerId;
    reply(Endpoint::PlayerStats, p, 250);
}

// ---------------------------------------------------------------- Draft -----
void MockBackendService::fetchDraftCatalog() { reply(Endpoint::DraftCatalog, m_catalog, 150); }

void MockBackendService::analyzeDraft(const QString &teamId, const QVariantMap &draft)
{
    Q_UNUSED(teamId)
    reply(Endpoint::DraftAnalysis, computeDraftAnalysis(draft), 40); // RNF-D01: bem < 1 s
}

QVariantMap MockBackendService::computeDraftAnalysis(const QVariantMap &draft) const
{
    // Índice id -> campeão
    QHash<QString, QVariantMap> byId;
    for (const QVariant &v : m_catalog.value("champions").toList())
        byId.insert(v.toMap().value("id").toString(), v.toMap());

    auto sideIds = [&](const QString &side, const QString &kind) {
        QStringList out;
        for (const QVariant &v : draft.value(side).toMap().value(kind).toList())
            if (!v.toString().isEmpty()) out << v.toString();
        return out;
    };
    // Soma as tags táticas de uma lista de campeões
    auto sumTags = [&](const QStringList &ids) {
        QHash<QString, double> s;
        for (const QString &id : ids)
            for (auto it = byId[id].value("tags").toMap().cbegin(); it != byId[id].value("tags").toMap().cend(); ++it)
                s[it.key()] += it.value().toDouble();
        return s;
    };
    auto classify = [&](const QStringList &ids, QVariantList *bars, QString *label, int *confidence, QString *key) {
        const auto sums = sumTags(ids);
        double total = 0;
        for (const auto &a : kArchetypes) total += sums.value(a.first);
        QString best; double bestV = -1;
        for (const auto &a : kArchetypes) {
            const double pct = total > 0 ? 100.0 * sums.value(a.first) / total : 0;
            if (bars) bars->append(QVariantMap{{"key", a.first}, {"label", a.second}, {"value", qRound(pct)}});
            if (pct > bestV) { bestV = pct; best = a.first; *label = a.second; }
        }
        *key = best;
        *confidence = ids.isEmpty() ? 0 : qMin(95, qRound(bestV * (0.55 + 0.09 * ids.size())));
    };

    const QStringList allyPicks = sideIds("ally", "picks"), enemyPicks = sideIds("enemy", "picks");
    const QStringList taken = allyPicks + enemyPicks + sideIds("ally", "bans") + sideIds("enemy", "bans");

    QVariantMap out{{"seq", draft.value("seq")}};
    QVariantList bars; QString label = "—", key; int conf = 0;
    classify(allyPicks, &bars, &label, &conf, &key);
    out["allyType"] = allyPicks.isEmpty() ? QString("—") : label;
    out["allyTypeKey"] = allyPicks.isEmpty() ? QString() : key;
    out["confidence"] = conf;
    out["bars"] = bars;

    QString eLabel = "—", eKey; int eConf = 0;
    classify(enemyPicks, nullptr, &eLabel, &eConf, &eKey);
    out["enemyType"] = enemyPicks.isEmpty() ? QString("—") : eLabel;
    out["enemyConfidence"] = eConf;

    // --- Pontos fortes / atenção (regras simples; o backend real usa a tabela de tags) ---
    const auto sums = sumTags(allyPicks);
    QVariantList strengths, warnings, insights;
    if (!allyPicks.isEmpty()) {
        if (sums.value("dive") >= 25) strengths << "Excelente engage";
        if (sums.value("dive") + sums.value("disengage") >= 35) strengths << "Boa sinergia de lutas";
        if (sums.value("split") >= 8) strengths << "Controle de mapa";
        if (sums.value("poke") >= 15) strengths << "Dano à distância consistente";
        if (sums.value("disengage") >= 12) strengths << "Boa capacidade de desengajar";
        if (sums.value("poke") < 8) warnings << "Pouca wave clear";
        if (sums.value("disengage") < 8) warnings << "Pouco desengaje";
        if (sums.value("dive") >= 25) warnings << "Dependência de engage";
        insights << QVariantMap{{"level", "ok"}, {"text", out["allyType"].toString() + " em formação com " + QString::number(conf) + "% de confiança."}};
        if (sums.value("disengage") < 8)
            insights << QVariantMap{{"level", "info"}, {"text", "Considere adicionar mais controle de grupo e desengaje."}};
    }
    if (!enemyPicks.isEmpty() && eKey == "poke")
        insights << QVariantMap{{"level", "warn"}, {"text", "O inimigo mostra tendência a composições de lutas prolongadas e poke."}};
    out["strengths"] = strengths; out["warnings"] = warnings; out["insights"] = insights;

    // --- Sugestões: prioriza a função ainda vazia + afinidade com o arquétipo + conforto do time ---
    QStringList freeRoles;
    const QVariantList picks = draft.value("ally").toMap().value("picks").toList();
    for (int i = 0; i < picks.size() && i < kRoles.size(); ++i)
        if (picks[i].toString().isEmpty()) freeRoles << kRoles[i];
    QList<QPair<double, QVariantMap>> ranked;
    for (const QVariant &v : m_catalog.value("champions").toList()) {
        const QVariantMap c = v.toMap();
        if (taken.contains(c.value("id").toString())) continue;
        if (!freeRoles.isEmpty() && !freeRoles.contains(c.value("role").toString())) continue;
        double score = c.value("winRate").toDouble();
        if (!key.isEmpty()) score += 2.0 * c.value("tags").toMap().value(key).toDouble();
        if (sums.value("disengage") < 8) score += 1.5 * c.value("tags").toMap().value("disengage").toDouble();
        ranked.append({score, c});
    }
    std::sort(ranked.begin(), ranked.end(), [](auto &a, auto &b) { return a.first > b.first; });
    QVariantList sug;
    for (int i = 0; i < qMin(5, int(ranked.size())); ++i) sug << ranked[i].second;
    out["suggestions"] = sug;
    return out;
}

// --------------------------------------------------------------- Treino -----
void MockBackendService::fetchTraining(const QString &teamId)
{
    Q_UNUSED(teamId)
    reply(Endpoint::Training, loadJson(":/mock/training.json"), 400);
}

void MockBackendService::syncMatchHistory(const QString &teamId)
{
    reply(Endpoint::SyncHistory, {{"teamId", teamId}}, 800);
}
