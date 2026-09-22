#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtWebEngineQuick>
#include <QDir>
#include <QFileInfo>
#include <QQuickWindow>
#include <QImage>
#include <QTimer>

#include "core/DroneManager.h"
#include "core/MissionPlanner.h"
#include "core/AppSettings.h"
#include "core/AudioAnnunciator.h"
#include "core/AiAssistant.h"
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
    DroneManager     droneManager;
    AppSettings      appSettings;
    MissionPlanner   missionPlanner;
    AudioAnnunciator audioAnnunciator;
    AiAssistant      aiAssistant(&droneManager, &audioAnnunciator, &appSettings);
    PythonBridge     pythonBridge;
    VideoManager     videoManager;

    // Connect AudioAnnunciator to all drones (present & dynamically discovered)
    auto wireDroneAudio = [&audioAnnunciator](DroneVehicle *drone) {
        if (!drone) return;

        QObject::connect(drone, &DroneVehicle::connectionChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            audioAnnunciator.onDroneConnected(drone->isConnected(), drone->name());
        });

        QObject::connect(drone, &DroneVehicle::armedChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            audioAnnunciator.onArmedChanged(drone->isArmed(), drone->name());
        });

        QObject::connect(drone, &DroneVehicle::flightModeChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            audioAnnunciator.onFlightModeChanged(drone->flightMode(), drone->name());
        });

        QObject::connect(drone, &DroneVehicle::batteryChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            audioAnnunciator.onBatteryWarning(drone->batteryPercent());
        });

        QObject::connect(drone, &DroneVehicle::geofenceBreachedChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            if (drone->geofenceBreached()) {
                audioAnnunciator.onGeofenceBreach();
            }
        });

        QObject::connect(drone, &DroneVehicle::gpsChanged, &audioAnnunciator, [drone, &audioAnnunciator]() {
            if (drone->gpsFixType() < 3 && drone->isArmed()) {
                audioAnnunciator.onGpsLost(drone->name());
            }
        });

        QObject::connect(drone, &DroneVehicle::missionUploadComplete, &audioAnnunciator, [&audioAnnunciator](bool success) {
            if (success) {
                audioAnnunciator.onMissionUploaded(1);
            }
        });

        QObject::connect(drone, &DroneVehicle::missionCleared, &audioAnnunciator, [&audioAnnunciator]() {
            audioAnnunciator.onMissionCleared();
        });

        if (drone->isConnected()) {
            audioAnnunciator.onDroneConnected(true, drone->name());
        }
    };

    QObject::connect(&droneManager, &DroneManager::droneAdded, &audioAnnunciator, wireDroneAudio);

    // QML engine
    QQmlApplicationEngine engine;

    // Expose C++ objects to QML as context properties
    engine.rootContext()->setContextProperty("droneManager",      &droneManager);
    engine.rootContext()->setContextProperty("appSettings",       &appSettings);
    engine.rootContext()->setContextProperty("missionPlanner",    &missionPlanner);
    engine.rootContext()->setContextProperty("audioAnnunciator",  &audioAnnunciator);
    engine.rootContext()->setContextProperty("aiAssistant",        &aiAssistant);
    engine.rootContext()->setContextProperty("pythonBridge",      &pythonBridge);
    engine.rootContext()->setContextProperty("videoManager",      &videoManager);

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
            resolvedDataDir = appDir;
    }
    engine.rootContext()->setContextProperty("appDirPath", resolvedDataDir);

    int initialPage = 0;
    QString screenshotPath;
    bool mockDrone = false;
    bool openLogs = false;
    bool openAi = false;
    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == "--map" || arg == "-m") {
            initialPage = 0;
        } else if (arg == "--mission") {
            initialPage = 1;
        } else if (arg.startsWith("--page=")) {
            initialPage = arg.mid(7).toInt();
        } else if (arg == "--screenshot" && i + 1 < argc) {
            screenshotPath = QString::fromLocal8Bit(argv[++i]);
        } else if (arg == "--mock") {
            mockDrone = true;
        } else if (arg == "--logs") {
            openLogs = true;
        } else if (arg == "--ai") {
            openAi = true;
        }
    }
    engine.rootContext()->setContextProperty("initialPage", initialPage);
    engine.rootContext()->setContextProperty("initialOpenLogs", openLogs);
    engine.rootContext()->setContextProperty("initialOpenAi", openAi);

    if (mockDrone || !screenshotPath.isEmpty()) {
        auto *drone = droneManager.getOrCreateDrone(1);
        drone->setName("Tactical Drone #1");
        drone->updateSimulatedTelemetry(37.7749, -122.4194, 45.0, 45.0,
                                       75.0, 3.2, -1.8, 75.0,
                                       12.5, 13.0, 0.2,
                                       86, 15.6,
                                       14, 0.85,
                                       true, "AUTO", "[SYS:1] In Flight — Nominal");
        drone->setGeofenceRadius(400.0);
        drone->setGeofenceMaxAlt(120.0);
        drone->setGeofenceMinAlt(5.0);
        drone->setGeofenceEnabled(true);
    }

    // Load main QML
    const QUrl url(u"qrc:/GCS/qml/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    if (!screenshotPath.isEmpty()) {
        QTimer::singleShot(4000, [&engine, screenshotPath]() {
            const auto rootObjects = engine.rootObjects();
            if (!rootObjects.isEmpty()) {
                if (auto *window = qobject_cast<QQuickWindow*>(rootObjects.first())) {
                    QImage img = window->grabWindow();
                    img.save(screenshotPath);
                    qDebug() << "Captured screenshot to" << screenshotPath;
                }
            }
            QCoreApplication::quit();
        });
    }

    engine.load(url);

    return app.exec();
}
