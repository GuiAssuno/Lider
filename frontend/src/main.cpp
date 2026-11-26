// =============================================================================
//  LÍDER Launcher — ponto de entrada (composition root)
// =============================================================================
//  Aqui (e só aqui) as implementações concretas são escolhidas e conectadas:
//     • Se LIDER_API_URL (ou --api-url) estiver definido:
//         RoutedBackendService -> HttpBackendService (auth/perfil/times)
//                              -> MockBackendService (análise/draft/treino/sync)
//     • Caso contrário:
//         MockBackendService (modo demonstração offline)
//     • MockLcuBridge -> será trocado por LcuBridge na Etapa 9
//  O restante do app depende apenas das interfaces IBackendService / ILcuBridge.
//
//  Opções de linha de comando (desenvolvimento/QA):
//     --api-url <url>       URL base da API REST (sobrepõe LIDER_API_URL)
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
#include <memory>
#include <qqml.h>

#include "services/HttpBackendService.h"
#include "services/MockBackendService.h"
#include "services/MockLcuBridge.h"
#include "services/RoutedBackendService.h"
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
    QCommandLineOption apiUrlOpt("api-url", "URL base da API REST (ex.: http://127.0.0.1:8000).", "url");
    QCommandLineOption routeOpt("route", "Abre a rota após login demo.", "rota");
    QCommandLineOption shotOpt("screenshot", "Salva captura e encerra.", "arquivo");
    QCommandLineOption delayOpt("delay", "Espera (ms) antes da captura.", "ms", "2500");
    QCommandLineOption simOpt("simulate", "Inicia a simulação de draft após o login demo.");
    cli.addOptions({apiUrlOpt, routeOpt, shotOpt, delayOpt, simOpt});
    cli.process(app);

    const QString apiUrl = cli.isSet(apiUrlOpt)
                               ? cli.value(apiUrlOpt).trimmed()
                               : qEnvironmentVariable("LIDER_API_URL").trimmed();

    // ---- Infraestrutura ----
    MockBackendService mockBackend;
    std::unique_ptr<HttpBackendService> httpBackend;
    std::unique_ptr<RoutedBackendService> routedBackend;
    IBackendService *backend = &mockBackend;

    if (!apiUrl.isEmpty()) {
        httpBackend = std::make_unique<HttpBackendService>(apiUrl);
        routedBackend = std::make_unique<RoutedBackendService>(httpBackend.get(), &mockBackend);
        backend = routedBackend.get();
    }

    MockLcuBridge lcu;

    // ---- Controllers (ViewModels) ----
    AppController appCtl(backend, &lcu);
    AnalysisController analysis(backend);
    DraftController draft(backend, &lcu);
    TrainingController training(backend);

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

    // ---- Modo demo/QA ou restauração automática de sessão ----
    if (cli.isSet(routeOpt)) {
        const QString route = cli.value(routeOpt);
        QObject::connect(&appCtl, &AppController::authenticatedChanged, &app, [&, route] {
            if (appCtl.authenticated()) appCtl.navigate(route);
        });
        if (cli.isSet(simOpt))
            QTimer::singleShot(1800, &app, [&] { draft.ensureLoaded(); draft.runSimulation(); });
        appCtl.login("demo@lider.gg", "demo1234");
    } else if (!apiUrl.isEmpty()) {
        // Se existir refresh token salvo no cofre do SO, restaura a sessão ao abrir.
        QTimer::singleShot(0, &appCtl, &AppController::restoreSession);
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
