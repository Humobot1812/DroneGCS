#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtWebEngineQuick>
#include <QDir>
#include <QFileInfo>

#include "core/DroneManager.h"
#include "core/MissionPlanner.h"
#include "core/AppSettings.h"
#include "python/PythonBridge.h"
#include "video/VideoManager.h"

void registerQmlTypes();  // forward decl from qml/QmlTypes.cpp

int main(int argc, char *argv[])
{
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-web-security --allow-running-insecure-content --ignore-certificate-errors");
    // Must be called before QGuiApplication
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    app.setApplicationName("DRONE GCS");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("DRONE_GCS");

    // Register QML types
    registerQmlTypes();

    // Create singletons
    DroneManager   droneManager;
    AppSettings    appSettings;
    MissionPlanner missionPlanner;
    PythonBridge   pythonBridge;
    VideoManager   videoManager;

    // QML engine
    QQmlApplicationEngine engine;

    // Expose C++ objects to QML as context properties
    engine.rootContext()->setContextProperty("droneManager",   &droneManager);
    engine.rootContext()->setContextProperty("appSettings",    &appSettings);
    engine.rootContext()->setContextProperty("missionPlanner", &missionPlanner);
    engine.rootContext()->setContextProperty("pythonBridge",   &pythonBridge);
    engine.rootContext()->setContextProperty("videoManager",   &videoManager);
    // Resolve data directory: check env override, then binary-adjacent map/, then parent dir (dev build)
    QString resolvedDataDir;
    QString envOverride = QString::fromLocal8Bit(qgetenv("GCS_DATA_DIR"));
    if (!envOverride.isEmpty() && QFileInfo(envOverride + "/map/map.html").exists()) {
        resolvedDataDir = envOverride;
    } else {
        QString appDir = QCoreApplication::applicationDirPath();
        QStringList candidates = {
            appDir,                        // binary dir (AppImage: usr/bin, dev: build/)
            appDir + "/..",               // one up (dev: build/../ = project root)
            appDir + "/../..",            // two up (fallback)
        };
        for (const QString &cand : candidates) {
            QString normalized = QDir(cand).absolutePath();
            if (QFileInfo(normalized + "/map/map.html").exists()) {
                resolvedDataDir = normalized;
                break;
            }
        }
        if (resolvedDataDir.isEmpty())
            resolvedDataDir = appDir;  // fallback — will show error but not crash
    }
    engine.rootContext()->setContextProperty("appDirPath", resolvedDataDir);

    bool autoTour = false;
    int initialPage = 0;
    QString screenshotDir = "";
    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == "--demo" || arg == "-d" || arg == "--simulate" || arg == "--sim") {
            droneManager.startSimulation(2);
        }
        if (arg == "--tour" || arg == "--auto-tour") {
            autoTour = true;
            droneManager.startSimulation(2);
        }
        if (arg == "--map" || arg == "-m") {
            initialPage = 1;
        } else if (arg.startsWith("--page=")) {
            initialPage = arg.mid(7).toInt();
        }
        if (arg.startsWith("--screenshots=")) {
            screenshotDir = arg.mid(14);
        } else if (arg == "--screenshot-dir" && i + 1 < argc) {
            screenshotDir = QString::fromLocal8Bit(argv[++i]);
        }
    }
    engine.rootContext()->setContextProperty("initialPage",           initialPage);
    engine.rootContext()->setContextProperty("initialAutoTour",      autoTour);
    engine.rootContext()->setContextProperty("initialScreenshotDir", screenshotDir);

    // Load main QML
    const QUrl url(u"qrc:/GCS/qml/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
