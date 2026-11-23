// =============================================================================
//  LÍDER Launcher — ponto de entrada (composition root)
// =============================================================================
//  Aqui (e só aqui) as implementações concretas são escolhidas e conectadas:
//     MockBackendService  ->  troque por HttpBackendService
//     MockLcuBridge       ->  troque por LcuBridge (WebSocket real)
//  O restante do app depende apenas das interfaces IBackendService / ILcuBridge.
//
//  Opções de linha de comando (desenvolvimento/QA):
//     --route <rota>        faz login demo e abre a rota (ex.: draft.composition)
//     --screenshot <png>    salva uma captura da janela e encerra
//     --simulate            inicia a simulação de draft (use com --route draft.composition)
//     --delay <ms>          tempo de espera antes da captura (padrão 2500)
// =============================================================================
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <qqml.h>

#include "services/MockBackendService.h"
#include "services/MockLcuBridge.h"
#include "viewmodels/AnalysisController.h"
#include "viewmodels/AppController.h"
#include "viewmodels/DraftController.h"
#include "viewmodels/TrainingController.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName("Lider");
    QGuiApplication::setApplicationName("Lider Launcher");
    QGuiApplication::setApplicationVersion(LIDER_VERSION);

    // Estilo "Basic": é o ideal para customização total e o mais leve em CPU/RAM.
    QQuickStyle::setStyle("Basic");

    QCommandLineParser cli;
    cli.addHelpOption();
    cli.addVersionOption();
    QCommandLineOption routeOpt("route", "Abre a rota após login demo.", "rota");
    QCommandLineOption shotOpt("screenshot", "Salva captura e encerra.", "arquivo");
    QCommandLineOption delayOpt("delay", "Espera (ms) antes da captura.", "ms", "2500");
    QCommandLineOption simOpt("simulate", "Inicia a simulação de draft após o login demo.");
    cli.addOptions({routeOpt, shotOpt, delayOpt, simOpt});
    cli.process(app);

    // ---- Infraestrutura (trocar por implementações reais) ----
    MockBackendService backend;
    MockLcuBridge lcu;

    // ---- Controllers (ViewModels) ----
    AppController appCtl(&backend, &lcu);
    AnalysisController analysis(&backend);
    DraftController draft(&backend, &lcu);
    TrainingController training(&backend);

    // Trocar de time ativo propaga o contexto para todas as áreas (RNF-L03).
    QObject::connect(&appCtl, &AppController::activeTeamChanging, &app, [&](const QString &id) {
        analysis.setTeamId(id);
        draft.setTeamId(id);
        training.setTeamId(id);
    });

    qmlRegisterSingletonInstance("Lider.Core", 1, 0, "App", &appCtl);
    qmlRegisterSingletonInstance("Lider.Core", 1, 0, "Analysis", &analysis);
    qmlRegisterSingletonInstance("Lider.Core", 1, 0, "Draft", &draft);
    qmlRegisterSingletonInstance("Lider.Core", 1, 0, "Training", &training);

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral(":/qt/qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/Lider/qml/Main.qml")));

    // ---- Modo demo/QA ----
    if (cli.isSet(routeOpt)) {
        const QString route = cli.value(routeOpt);
        QObject::connect(&appCtl, &AppController::authenticatedChanged, &app, [&, route] {
            if (appCtl.authenticated()) appCtl.navigate(route);
        });
        if (cli.isSet(simOpt))
            QTimer::singleShot(1800, &app, [&] { draft.ensureLoaded(); draft.runSimulation(); });
        appCtl.login("demo@lider.gg", "demo1234");
    }
    if (cli.isSet(shotOpt)) {
        const QString file = cli.value(shotOpt);
        QTimer::singleShot(cli.value(delayOpt).toInt(), &app, [&, file] {
            auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
            if (w) w->grabWindow().save(file);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
