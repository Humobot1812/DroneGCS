# Project Handover Specification & Architectural Blueprint

**Project Name**: Drone Ground Control Station (DroneGCS)  
**Handover Target**: Institutional Next-Generation Aerospace GCS Project  
**Engineering Agent**: Claude Code  
**Author**: Abhinav Goel  
**Date**: November 2026  
**License**: MIT  

---

## Table of Contents
1. [Project Overview & Handover Scope](#1-project-overview--handover-scope)
2. [Underlay Stack Architecture](#2-underlay-stack-architecture)
3. [Component Interfaces & Data Flow](#3-component-interfaces--data-flow)
4. [Workspaces & UI Specifications](#4-workspaces--ui-specifications)
5. [Telemetry & MAVLink Communications Engine](#5-telemetry--mavlink-communications-engine)
6. [2D & 3D Geospatial Engine Integration](#6-2d--3d-geospatial-engine-integration)
7. [Parameter Management & Tuning Engine](#7-parameter-management--tuning-engine)
8. [Safety Systems, Failsafes & Geofencing](#8-safety-systems-failsafes--geofencing)
9. [Build System, Packaging & Deployment](#9-build-system-packaging--deployment)
10. [Roadmap & Recommendations for Claude Code](#10-roadmap--recommendations-for-claude-code)

---

## 1. Project Overview & Handover Scope

This project serves as the foundational **underlay stack** for your institution's ground control station initiative. Rather than building a ground control system from scratch, you inherit a robust, high-performance C++17/Qt6/MAVLink architecture that is already capable of:

- Multi-vehicle telemetry streaming and fleet coordination.
- Real-time 2D (Leaflet) and 3D (CesiumJS) geospatial flight tracking.
- Bidirectional mission planning with survey grid generators and 3D terrain elevation clearance verification.
- Cross-autopilot (ArduPilot and PX4) dynamic flight mode and parameter translation.
- 1-click batch parameter upload with paced transmission to eliminate telemetry radio packet loss.
- High-reliability failsafes (critical battery auto-RTL, circular/polygonal geofencing, slide-to-confirm action gates).
- Low-latency HD video streaming pipeline via GStreamer 1.0.
- Integrated voice annunciator for audible cockpit alerts.
- Tactical AI Copilot powered by Google Gemini AI.
- Standalone Linux AppImage packaging toolchain.

---

## 2. Underlay Stack Architecture

```
+-----------------------------------------------------------------------------------------+
|                                    USER INTERFACE                                       |
|  Tactical Cockpit (Map) | Mission Planner | Parameters & Tuning | Video | Logs & Analytics|
+-----------------------------------------------------------------------------------------+
|                                 QML PRESENTATION LAYER                                  |
|   Qt Quick Controls 2 (Material Dark)  | Custom Canvas  | QWebEngineView (2D & 3D Map)   |
+---------------------------+-----------------------------+-------------------------------+
|    Telemetry Grapher      |     Geofence Safety         |       Audio Annunciator       |
+---------------------------+-----------------------------+-------------------------------+
|                                    C++17 CORE ENGINE                                    |
|   +-----------------------+ +-------------------------+ +---------------------------+   |
|   |     DroneManager      | |       DroneVehicle      | |       MissionPlanner      |   |
|   | (Fleet & Connections) | | (MAVLink State Machine) | |  (Waypoints & Geofences)  |   |
|   +-----------------------+ +-------------------------+ +---------------------------+   |
+---------------------------+-----------------------------+-------------------------------+
|                                   COMMUNICATIONS LAYER                                  |
|    SerialLink (QSerialPort)  |  UDPLink (QUdpSocket)   |    TCPLink (QTcpSocket)       |
|    USB & Telemetry Radios    |  Broadcast & Companion  |    ArduPilot / PX4 SITL       |
+-----------------------------------------------------------------------------------------+
|                                    MEDIA SUBSYSTEM                                      |
|            GStreamer 1.0 (RTSP / UDP RTP / H.264) | Picture-in-Picture (PiP)            |
+-----------------------------------------------------------------------------------------+
```

### Key Libraries & Tooling
- **Qt 6.2.4**: Built and bundled from `$HOME/Qt/6.2.4/gcc_64`.
- **C++ Standard**: C++17 (`set(CMAKE_CXX_STANDARD 17)`).
- **MAVLink Dialect**: ArduPilot Mega & Common v2.0 header-only implementation (`mavlink/v2.0/`).
- **WebEngine**: Chromium-based `QtWebEngineQuick` rendering CesiumJS and Leaflet.
- **Audio**: Speech synthesis over `spd-say` and `espeak`.

---

## 3. Component Interfaces & Data Flow

### 3.1 Main Entry Point (`src/main.cpp`)
Initializes the Qt Quick application, instantiates singletons, and exposes them directly to QML context properties:
- `droneManager`: Pointer to `DroneManager` instance.
- `appSettings`: Pointer to `AppSettings` instance.
- `audioAnnunciator`: Pointer to `AudioAnnunciator` instance.
- `aiAssistant`: Pointer to `AiAssistant` instance.

### 3.2 DroneManager (`src/core/DroneManager.h/.cpp`)
- Manages the lifecycle of active and inactive `DroneVehicle` objects.
- Handles automatic hardware interface detection across Serial (`/dev/ttyACM*`, `/dev/ttyUSB*`), UDP (`14550`, `14551`), and TCP (`5760`).
- Emits `droneAdded(DroneVehicle*)` and `activeDroneChanged()`.

### 3.3 DroneVehicle (`src/core/DroneVehicle.h/.cpp`)
Represents an individual physical or simulated aircraft.
- **Q_PROPERTY Bindings**: Latitude, longitude, altitude, relAltitude, roll, pitch, yaw, heading, groundspeed, airspeed, climbRate, batteryVoltage, batteryPercent, armed, flightMode, autopilotType (`"ArduPilot"` or `"PX4"`).
- **MAVLink Encoding/Decoding**: Implements `mavlink_parse_char()` handling incoming byte streams and packing outgoing commands via `buildCommandLong()` and `sendMavlinkParam()`.
- **Parameter Batch Engine**: `uploadAllParameters(const QVariantList &paramList)` sends parameters with a 15ms queue timer to avoid saturating telemetry links.
- **Mission Protocol**: Handles bidirectional upload/download of waypoint lists, ensuring post-mission RTL is appended without overwriting operator waypoints.

---

## 4. Workspaces & UI Specifications

The application enforces a **single source of truth** UI paradigm with no duplicated dashboards:

| Workspace | QML File | Primary Responsibility |
|---|---|---|
| **Map (Primary Cockpit)** | `qml/pages/MapPage.qml` | Tactical operations, 2D/3D geospatial visualization, live telemetry HUD, slide-to-confirm flight commands. |
| **Mission Planner** | `qml/pages/MissionPage.qml` | Interactive waypoint creation, survey grid generation, 3D elevation profile, mission upload/download. |
| **Vehicle Parameters** | `qml/pages/ParametersPage.qml` | Autopilot parameter inspection, 1-click batch upload, custom parameter injection, quick flight dynamics tuning. |
| **Video & Payload** | `qml/pages/VideoPage.qml` | Live RTSP/RTP video streams, camera feeds, floating Picture-in-Picture (PiP). |
| **Logs & Analysis** | `qml/pages/DashboardPage.qml` | Chronological event logs, telemetry oscilloscope, historical flight replay, CSV export. |

---

## 5. Telemetry & MAVLink Communications Engine

### Supported Connection Types:
1. **USB Serial**: Default `/dev/ttyACM0` at `115200` baud (direct Pixhawk/Cube connection).
2. **Telemetry Radio**: Default `/dev/ttyUSB0` at `57600` baud (SiK 433/915 MHz, RFD900).
3. **UDP Inbound**: Port `14550` (companion computer or simulator broadcast).
4. **TCP Client**: `127.0.0.1:5760` (ArduPilot / PX4 SITL simulator instance).

### Dynamic Autopilot Flight Mode Mapping:
The system automatically detects whether the drone runs **ArduPilot** or **PX4** via MAVLink `HEARTBEAT.autopilot`. Flight modes are mapped dynamically:
- **ArduPilot**: `GUIDED`, `AUTO`, `LOITER`, `STABILIZE`, `ALT_HOLD`, `RTL`, `LAND`, `BRAKE`, `POSHOLD`.
- **PX4**: `HOLD`, `LOITER`, `POSCTL`, `ALTCTL`, `MISSION`, `TAKEOFF`, `RTL`, `LAND`, `OFFBOARD`.

---

## 6. 2D & 3D Geospatial Engine Integration

### WebEngine & QWebChannel Architecture
The GCS runs two interactive geospatial environments inside `QtWebEngineQuick`:
1. **2D Tactical Map (`map/map.html`, `map/map.js`)**:
   - Leaflet-based map with 6 base layers (Google Satellite, Google Hybrid, ESRI Satellite, OpenStreetMap, Tactical Dark, Google Terrain).
   - Dynamic heading-aligned vehicle markers, breadcrumb trails, and geofence polygons.
2. **3D Geospatial Globe (`map/map3d.html`, `map/map3d.js`)**:
   - CesiumJS engine providing real-time 3D terrain elevation rendering.
   - High-contrast 3D quadcopter model (`map/models/drone.glb`) updated from live telemetry with smooth orientation interpolation.
   - 4 Dynamic Camera Modes: **Free Camera**, **Follow Drone**, **Top-Down**, and **Overview**.
   - 3D Mission Polyline: Differentiates completed waypoints (cyan) from upcoming waypoints (amber/yellow).

---

## 7. Parameter Management & Tuning Engine

Located in `qml/pages/ParametersPage.qml`:
- **1-Click Batch Upload**: `Upload All to Drone (N)` uploads the complete parameter list to vehicle memory at once.
- **Paced Transmission**: C++ `uploadAllParameters()` transmits packets with 15ms timer intervals to prevent buffer drops over radio links.
- **Parameter Types Supported**: `REAL32 (Float)`, `INT32`, `INT16`, `INT8`.
- **Direct Parameter Injection (`+ Add Parameter`)**: Provides instant parameter entry with presets for ArduPilot (`WPNAV_SPEED`, `RTL_ALT`, `RTL_SPEED`, etc.) and PX4 (`MPC_XY_CRUISE`, `MPC_LAND_SPEED`, etc.).
- **Quick Dynamics Tuning**: Single unified controls for RTL Speed, Yaw Turn Rate, and Auto-Yaw behavior across both ArduPilot and PX4.
- **Feedback**: Non-clipping notification banner and auditory callout (*"Parameter uploaded"*).

---

## 8. Safety Systems, Failsafes & Geofencing

- **Critical Battery RTL Failsafe**: Automatically triggers Return-to-Launch if battery drops below 10%, with a user-configurable on/off master toggle in Flight Safety Settings.
- **Non-Destructive RTL Mission Integration**: Appends Return-to-Launch after the final user waypoint, strictly preserving all planned user waypoints.
- **Geofence Safety Console**: Configures cylindrical boundaries and keep-in/keep-out polygons with altitude ceilings and floors. Supports one-click auto-fetch from autopilot memory.
- **Slide-to-Confirm Action Sliders**: Prevents accidental activation of high-risk commands: Arm, Disarm, Takeoff (with target AGL altitude selector), RTL, Land, and Emergency Motor Kill.
- **Pre-Flight Verification Checklist**: Automated sensor diagnostics checking IMU, Compass, Barometer, GPS lock, Battery, and Telemetry link rate before arming.

---

## 9. Build System, Packaging & Deployment

### Build Script (`build.sh`):
```bash
./build.sh
```

### Standalone AppImage Packaging (`scripts/create_appimage.sh`):
Generates a portable, dependency-free Linux AppImage containing the binary, Qt 6.2.4 runtime, WebEngine process, OpenSSL libraries, and map assets:
```bash
./scripts/create_appimage.sh
```

### Atomic Deployment Command:
To update the system application without encountering `Text file busy` (`ETXTBUSY`) errors if the app is currently running:
```bash
cp build/DRONE_GCS-x86_64.AppImage DRONE_GCS-x86_64.AppImage.tmp && mv -f DRONE_GCS-x86_64.AppImage.tmp DRONE_GCS-x86_64.AppImage
cp build/DRONE_GCS-x86_64.AppImage ~/.local/bin/DroneGCS.AppImage.tmp && mv -f ~/.local/bin/DroneGCS.AppImage.tmp ~/.local/bin/DroneGCS.AppImage
chmod +x DRONE_GCS-x86_64.AppImage ~/.local/bin/DroneGCS.AppImage
```

---

## 10. Roadmap & Recommendations for Claude Code

When building your new institution project on top of this underlay stack:

1. **Retain the Core Vehicle & Telemetry Architecture**:
   - `DroneVehicle.cpp` and `DroneManager.cpp` contain thoroughly battle-tested MAVLink message serialization, heartbeat monitoring, and link state machines. Use them as the low-level telemetry driver.
2. **Follow Qt Quick Layout Conventions**:
   - Inside `ColumnLayout` and `RowLayout`, always set `Layout.preferredHeight` / `Layout.preferredWidth` and `visible: bool`. Never rely solely on bare `height` properties inside layouts.
3. **Paced Transmissions on Radio Links**:
   - Telemetry radios (e.g. SiK 57600 baud) have small FIFO buffers. Any new batch command or parameter protocol must use timed queues (10–20ms spacing) rather than synchronous loops.
4. **Preserve Non-Destructive Waypoint Handling**:
   - Do not overwrite the user's final waypoint when configuring return actions; always append return waypoints or manage return commands through MAVLink `MAV_CMD_NAV_RETURN_TO_LAUNCH`.
5. **Add Institution-Specific Payload Modules**:
   - The `VideoPage.qml` and `VideoManager.cpp` pipelines provide clean expansion points for thermal imaging, LiDAR visualization, or robotic arm payload controls.
