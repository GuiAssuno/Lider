// =============================================================================
//  ILcuBridge — CONTRATO da ponte com o cliente local do LoL (LCU API)
// =============================================================================
//  Implementação real (futura): `LcuBridge`
//    • Detectar `LeagueClientUx.exe` e ler o *lockfile* (porta + token).
//    • Conectar por WebSocket seguro em 127.0.0.1 e assinar
//      `/lol-champ-select/v1/session` e `/lol-gameflow/v1/gameflow-phase`.
//    • MODO SOMENTE LEITURA (RNF-L05): nunca enviar PATCH/POST/PUT ao cliente.
//    • Converter ids numéricos de campeão -> ids do Data Dragon antes de emitir.
//  O formato do `session` emitido está descrito em MockLcuBridge.cpp.
// =============================================================================
#pragma once

#include <QObject>
#include <QVariantMap>

class ILcuBridge : public QObject
{
    Q_OBJECT
public:
    enum class State { Disconnected, Connected, ChampSelect, InGame, EndOfGame };
    Q_ENUM(State)

    explicit ILcuBridge(QObject *parent = nullptr) : QObject(parent) {}
    ~ILcuBridge() override = default;

    virtual void start() = 0;                 ///< inicia a detecção do cliente (idempotente)
    virtual void stop() = 0;
    virtual State state() const = 0;

    /// Apenas para mocks/desenvolvimento: simula uma sessão de champ select.
    virtual void simulateChampSelect() {}

signals:
    void stateChanged(ILcuBridge::State state);
    /// Sessão completa a cada alteração:
    /// { phase, timer, step, ally:{bans[5],picks[5]}, enemy:{bans[5],picks[5]} }
    void champSelectUpdated(const QVariantMap &session);
    void gameEnded();                         ///< fase EndOfGame (RF-L12)
};
