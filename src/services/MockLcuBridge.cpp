#include "MockLcuBridge.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

MockLcuBridge::MockLcuBridge(QObject *parent) : ILcuBridge(parent)
{
    // A ordem oficial vem do mesmo JSON usado pela UI (fonte única de verdade).
    QFile f(":/mock/draft.json");
    if (f.open(QIODevice::ReadOnly))
        for (const QJsonValue &v : QJsonDocument::fromJson(f.readAll()).object().value("order").toArray())
            m_order << v.toString();

    // Roteiro do draft simulado (ids do Data Dragon-like).
    m_allyBans   = {"syndra", "jhin", "viego", "fiora", "nautilus"};
    m_enemyBans  = {"zed", "sejuani", "janna", "jax", "braum"};
    m_allyPicks  = {"camille", "vi", "ahri", "kaisa", "leona"};
    m_enemyPicks = {"ornn", "leesin", "xerath", "caitlyn", "thresh"};

    m_stepTimer.setInterval(900);
    connect(&m_stepTimer, &QTimer::timeout, this, &MockLcuBridge::nextStep);
}

void MockLcuBridge::start()
{
    if (m_state != State::Disconnected) return;
    // Simula a detecção do LeagueClientUx.exe (RF-L11).
    QTimer::singleShot(1500, this, [this] { if (m_state == State::Disconnected) setState(State::Connected); });
}

void MockLcuBridge::stop()
{
    m_stepTimer.stop();
    setState(State::Disconnected);
}

void MockLcuBridge::setState(State s)
{
    if (m_state == s) return;
    m_state = s;
    emit stateChanged(s);
}

void MockLcuBridge::simulateChampSelect()
{
    if (m_state == State::Disconnected) start();
    m_step = 0;
    m_curAB = m_curEB = m_curAP = m_curEP = QStringList{"", "", "", "", ""};
    setState(State::ChampSelect);
    emit champSelectUpdated({{"phase", "BAN_PICK"}, {"step", 0}, {"timer", 30},
        {"ally", QVariantMap{{"bans", QVariant(m_curAB)}, {"picks", QVariant(m_curAP)}}},
        {"enemy", QVariantMap{{"bans", QVariant(m_curEB)}, {"picks", QVariant(m_curEP)}}}});
    m_stepTimer.start();
}

void MockLcuBridge::nextStep()
{
    if (m_step >= m_order.size()) {
        m_stepTimer.stop();
        setState(State::InGame);
        // Depois de "jogar", simula o fim da partida -> backend sincroniza histórico.
        QTimer::singleShot(5000, this, [this] {
            setState(State::EndOfGame);
            emit gameEnded();
            QTimer::singleShot(1500, this, [this] { setState(State::Connected); });
        });
        return;
    }
    const QStringList tok = m_order[m_step].split(':');   // [lado, tipo, índice]
    const bool blue = tok[0] == "B";
    const int idx = tok[2].toInt();
    if (tok[1] == "ban") (blue ? m_curAB : m_curEB)[idx] = (blue ? m_allyBans : m_enemyBans)[idx];
    else                 (blue ? m_curAP : m_curEP)[idx] = (blue ? m_allyPicks : m_enemyPicks)[idx];
    ++m_step;

    emit champSelectUpdated({{"phase", "BAN_PICK"}, {"step", m_step}, {"timer", 30},
        {"ally", QVariantMap{{"bans", QVariant(m_curAB)}, {"picks", QVariant(m_curAP)}}},
        {"enemy", QVariantMap{{"bans", QVariant(m_curEB)}, {"picks", QVariant(m_curEP)}}}});
}
