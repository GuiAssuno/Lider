// =============================================================================
//  MockLcuBridge — simula o cliente do LoL (somente para desenvolvimento)
// =============================================================================
//  Ciclo simulado:  Disconnected -> Connected (1,5 s) -> [simulateChampSelect]
//                   -> ChampSelect (20 passos do draft) -> InGame -> EndOfGame
//                   -> Connected.   Ao fim emite `gameEnded()` (RF-L12).
//
//  Formato de `champSelectUpdated(session)` (idêntico ao esperado do LcuBridge real):
//    { phase:"BAN_PICK", step:int, timer:30,
//      ally:{ bans:[5 ids], picks:[5 ids] }, enemy:{ bans:[5], picks:[5] } }
//  Ids vazios ("") representam slots ainda não preenchidos.
// =============================================================================
#pragma once

#include "core/ILcuBridge.h"
#include <QStringList>
#include <QTimer>

class MockLcuBridge : public ILcuBridge
{
    Q_OBJECT
public:
    explicit MockLcuBridge(QObject *parent = nullptr);
    void start() override;
    void stop() override;
    State state() const override { return m_state; }
    void simulateChampSelect() override;

private:
    void setState(State s);
    void nextStep();

    State m_state = State::Disconnected;
    QStringList m_order;                 // tokens "B:ban:0" lidos de draft.json
    QStringList m_allyBans, m_enemyBans, m_allyPicks, m_enemyPicks; // roteiro final
    QStringList m_curAB, m_curEB, m_curAP, m_curEP;                 // estado corrente
    int m_step = 0;
    QTimer m_stepTimer;
};
