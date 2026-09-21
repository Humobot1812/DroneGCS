cmake_minimum_required(VERSION 3.22)
project(DRONE_GCS VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ─── Qt6 ──────────────────────────────────────────────────────────────────────
find_package(Qt6 6.2 REQUIRED COMPONENTS
    Core
    Gui
    Quick
    QuickControls2
    Network
    SerialPort
    Multimedia
    WebEngineQuick
    WebChannel
    Xml
)



# ─── MAVLink headers (header-only) ────────────────────────────────────────────
add_library(mavlink INTERFACE)
target_include_directories(mavlink INTERFACE
    ${CMAKE_SOURCE_DIR}/mavlink/v2.0
    ${CMAKE_SOURCE_DIR}/mavlink/v2.0/ardupilotmega
)

# ─── Source files ─────────────────────────────────────────────────────────────
set(GCS_SOURCES
    src/main.cpp

    # Core
    src/core/DroneManager.h
    src/core/DroneManager.cpp
    src/core/DroneVehicle.h
    src/core/DroneVehicle.cpp
    src/core/TelemetryStore.h
    src/core/TelemetryStore.cpp
    src/core/MissionPlanner.h
    src/core/MissionPlanner.cpp
    src/core/AppSettings.h
    src/core/AppSettings.cpp

    # MAVLink links
    src/mavlink/AbstractLink.h
    src/mavlink/AbstractLink.cpp
    src/mavlink/MAVLinkBridge.h
    src/mavlink/MAVLinkBridge.cpp
    src/mavlink/SerialLink.h
    src/mavlink/SerialLink.cpp
    src/mavlink/UDPLink.h
    src/mavlink/UDPLink.cpp
    src/mavlink/TCPLink.h
    src/mavlink/TCPLink.cpp

    # Python bridge
    src/python/PythonBridge.h
    src/python/PythonBridge.cpp

    # Video
    src/video/VideoManager.h
    src/video/VideoManager.cpp

    # QML type registration
    src/qml/QmlTypes.cpp
)

# ─── QML Resources ────────────────────────────────────────────────────────────
qt_add_executable(DRONE_GCS ${GCS_SOURCES})

qt_add_qml_module(DRONE_GCS
    URI GCS
    VERSION 1.0
    QML_FILES
        qml/main.qml
        qml/components/Sidebar.qml
        qml/components/StatusBar.qml
        qml/components/DroneSelector.qml
        qml/components/ConnectionDialog.qml
        qml/components/AttitudeIndicator.qml
        qml/components/CompassRose.qml
        qml/components/SpeedAltGauge.qml
        qml/components/BatteryWidget.qml
        qml/components/LEDIndicator.qml
        qml/components/SettingsDialog.qml
        qml/pages/DashboardPage.qml
        qml/pages/MapPage.qml
        qml/pages/MissionPage.qml
        qml/pages/ParametersPage.qml
        qml/pages/VideoPage.qml
    RESOURCES
        resources/assets.qrc
)

# ─── Map & Python scripts (copy to build) ─────────────────────────────────────
configure_file(${CMAKE_SOURCE_DIR}/map/map.html       ${CMAKE_BINARY_DIR}/map/map.html COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/map/map.js         ${CMAKE_BINARY_DIR}/map/map.js   COPYONLY)
configure_file(${CMAKE_SOURCE_DIR}/map/qwebchannel.js ${CMAKE_BINARY_DIR}/map/qwebchannel.js COPYONLY)

# Copy all python_scripts
file(GLOB PY_SCRIPTS "${CMAKE_SOURCE_DIR}/python_scripts/*.py")
foreach(PY ${PY_SCRIPTS})
    get_filename_component(PY_NAME ${PY} NAME)
    configure_file(${PY} ${CMAKE_BINARY_DIR}/python_scripts/${PY_NAME} COPYONLY)
endforeach()

# ─── Leaflet assets copy ──────────────────────────────────────────────────────
add_custom_command(TARGET DRONE_GCS POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/map/leaflet
        ${CMAKE_BINARY_DIR}/map/leaflet
    COMMENT "Copying Leaflet assets"
)

# ─── Link libraries ───────────────────────────────────────────────────────────
target_link_libraries(DRONE_GCS PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::SerialPort
    Qt6::Multimedia
    Qt6::WebEngineQuick
    Qt6::WebChannel
    Qt6::Xml
    mavlink
)

target_include_directories(DRONE_GCS PRIVATE
    ${CMAKE_SOURCE_DIR}/src
)

# ─── Install ──────────────────────────────────────────────────────────────────
install(TARGETS DRONE_GCS
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
