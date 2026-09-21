#include <QtQml/qqml.h>
#include "../core/DroneManager.h"
#include "../core/DroneVehicle.h"
#include "../core/MissionPlanner.h"
#include "../core/AppSettings.h"
#include "../python/PythonBridge.h"
#include "../video/VideoManager.h"

void registerQmlTypes()
{
    qmlRegisterType<DroneVehicle>   ("GCS", 1, 0, "DroneVehicle");
    qmlRegisterType<MissionPlanner> ("GCS", 1, 0, "MissionPlanner");
    qmlRegisterType<PythonBridge>   ("GCS", 1, 0, "PythonBridge");
    qmlRegisterType<VideoManager>   ("GCS", 1, 0, "VideoManager");
    qmlRegisterUncreatableType<DroneManager>("GCS", 1, 0, "DroneManager",
        "DroneManager is a singleton created in main.cpp");
    qmlRegisterUncreatableType<AppSettings>("GCS", 1, 0, "AppSettings",
        "AppSettings is a singleton created in main.cpp");
}
