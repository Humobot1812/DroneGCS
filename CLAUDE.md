# CLAUDE.md — DroneGCS Engineering Context & Handover Guide

> **Target Agent**: Claude Code  
> **Project**: DroneGCS (Tactical Multi-UAV Ground Control Station)  
> **Repository**: [https://github.com/Humobot1812/DroneGCS](https://github.com/Humobot1812/DroneGCS)  
> **Underlay Stack**: C++17, Qt 6.2.4, QML (Qt Quick Controls 2), MAVLink v2.0, QtWebEngine (Leaflet 2D + CesiumJS 3D), GStreamer 1.0, Google Gemini AI.

---

## 1. Executive Summary & Purpose

This repository contains **DroneGCS**, a production-grade, tactical multi-UAV Ground Control Station engineered for autonomous flight operations, fleet telemetry, 2D/3D geospatial visualization, and mission planning.

You are receiving this repository as the **underlay stack** for a new institution ground control station project. All core networking, MAVLink v2 communication, hardware auto-discovery, telemetry state estimation, geospatial engines (Leaflet 2D + CesiumJS 3D), avionics widgets, and AppImage packaging toolchains are fully implemented, tested, and operational.

---

## 2. Core Tech Stack & Prerequisites

| Layer | Technology | Details / Paths |
|---|---|---|
| **Language & Standard** | C++17 | GCC / G++ (>= 11.4) |
| **GUI Framework** | Qt 6.2.4 | Bundled at `$HOME/Qt/6.2.4/gcc_64` |
| **Declarative UI** | QML / Qt Quick 2.15 | Qt Quick Controls 2 Material Dark theme |
| **Protocol** | MAVLink v2.0 | Header-only in `mavlink/v2.0/ardupilotmega/` |
| **Geospatial 2D** | Leaflet.js | Embedded in QtWebEngine (`map/map.html`) |
| **Geospatial 3D** | CesiumJS + WebGL | Embedded in QtWebEngine (`map/map3d.html`) |
| **Video Pipeline** | GStreamer 1.0 | Ultra-low-latency RTSP, UDP RTP, H.264 |
| **Voice Annunciator** | System TTS | `spd-say` / `espeak` non-blocking queue |
| **AI Copilot** | Google Gemini REST API | Live telemetry prompt reasoning in `AiAssistant` |
| **Packaging** | Linux AppImage | Standalone bundling script in `scripts/create_appimage.sh` |

---

## 3. Essential Commands (Build, Run & Deploy)

### Quick Automated Build
```bash
# Uses Qt 6.2.4 at $HOME/Qt/6.2.4/gcc_64
./build.sh
```

### Manual CMake Build
```bash
mkdir -p build && cd build
cmake .. -DCMAKE_PREFIX_PATH="$HOME/Qt/6.2.4/gcc_64" -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build . -j$(nproc)
```

### Running the Application
```bash
# From build directory:
./build/DRONE_GCS

# Or run the standalone AppImage:
./DRONE_GCS-x86_64.AppImage
# Or system launcher:
~/.local/bin/DroneGCS.AppImage
```

### Packaging & Deploying the AppImage
```bash
# 1. Package the AppImage
./scripts/create_appimage.sh

# 2. Deploy atomically (prevents 'Text file busy' error if app is running):
cp build/DRONE_GCS-x86_64.AppImage DRONE_GCS-x86_64.AppImage.tmp && mv -f DRONE_GCS-x86_64.AppImage.tmp DRONE_GCS-x86_64.AppImage
cp build/DRONE_GCS-x86_64.AppImage ~/.local/bin/DroneGCS.AppImage.tmp && mv -f ~/.local/bin/DroneGCS.AppImage.tmp ~/.local/bin/DroneGCS.AppImage
chmod +x DRONE_GCS-x86_64.AppImage ~/.local/bin/DroneGCS.AppImage
```

---

## 4. Architecture & Codebase Map

```
DRONE_GCS/
├── CMakeLists.txt              # Primary CMake configuration and QML module registration
├── build.sh                    # Automated dependency checker and Qt 6.2.4 builder
├── README.md                   # Full product overview with 22 reference screenshots
├── CLAUDE.md                   # This handover context file
├── scripts/
│   └── create_appimage.sh      # Self-contained AppImage generator with bundled Qt/WebEngine
├── mavlink/v2.0/               # Complete MAVLink v2.0 C headers (ArduPilot + PX4 dialects)
├── map/                        # WebEngine HTML/JS mapping assets
│   ├── map.html / map.js       # 2D Leaflet engine (6 map providers, drawing tools)
│   ├── map3d.html / map3d.js   # 3D CesiumJS engine (terrain, 3D model, 4 camera modes)
│   ├── qwebchannel.js          # Bidirectional Qt <-> Web JavaScript communication bridge
│   └── models/drone.glb        # Custom dark high-contrast 3D quadcopter model
├── qml/                        # Presentation Layer (Qt Quick 2 / Material Dark)
│   ├── main.qml                # Root window, header bar, sidebar, and workspace stack
│   ├── components/             # Reusable avionics instruments and modal dialogs
│   │   ├── AttitudeIndicator.qml   # Synthetic horizon / PFD pitch & roll ladder
│   │   ├── SpeedAltGauge.qml       # Vertical rolling tape airspeed & altitude gauges
│   │   ├── CompassRose.qml         # Heading tape with Home vector and waypoint bug
│   │   ├── BatteryWidget.qml       # Multi-cell voltage, current draw, and mAh gauge
│   │   ├── SlideToConfirm.qml      # Safeguarded action slider for high-risk commands
│   │   ├── PreFlightChecklist.qml  # Automated pre-arm sensor verification checklist
│   │   ├── GeofenceConsole.qml     # Cylindrical and polygon geofence manager
│   │   ├── ConnectionDialog.qml    # Serial, UDP, TCP connection manager
│   │   ├── SettingsDialog.qml      # Flight safety, audio, telemetry, map, Gemini AI
│   │   ├── AiCopilotDrawer.qml     # Google Gemini natural language copilot drawer
│   │   └── FlightReplayBar.qml     # Historic telemetry playback with scrub bar
│   └── pages/                  # Primary Workspaces
│       ├── MapPage.qml             # Operational Cockpit (2D/3D map, PFD HUD, action bar)
│       ├── MissionPage.qml         # Waypoint sequencing, survey grids, 3D terrain profile
│       ├── ParametersPage.qml      # Parameter tree, 1-click batch upload, dynamics tuning
│       ├── VideoPage.qml           # Live HD video stream and payload controls
│       └── DashboardPage.qml       # Chronological event logs, telemetry charts
└── src/                        # C++17 Core Engine
    ├── main.cpp                # App initialization, QML context injection, audio wiring
    ├── core/
    │   ├── DroneManager.h/.cpp     # Fleet coordinator, link life-cycle, auto-connect scanner
    │   ├── DroneVehicle.h/.cpp     # Vehicle model, MAVLink decoder, telemetry state, upload
    │   ├── MissionPlanner.h/.cpp   # Waypoint mission compiler, survey grid math
    │   ├── AppSettings.h/.cpp      # Persistent configuration (QSettings)
    │   ├── AudioAnnunciator.h/.cpp # Non-blocking speech synthesis queue (spd-say/espeak)
    │   ├── AiAssistant.h/.cpp      # Gemini AI client, SITREP reporter, natural language parser
    │   └── TelemetryStore.h/.cpp   # High-frequency telemetry ring buffer for oscilloscope
    ├── mavlink/
    │   ├── AbstractLink.h/.cpp     # Base transport interface for MAVLink streams
    │   ├── SerialLink.h/.cpp       # QSerialPort link (USB / SiK / RFD900 radios)
    │   ├── UDPLink.h/.cpp          # QUdpSocket link (companion computers, SITL)
    │   └── TCPLink.h/.cpp          # QTcpSocket client link (SITL simulator ports)
    └── video/
        └── VideoManager.h/.cpp     # GStreamer 1.0 pipeline, RTSP/RTP/H.264 decoding
```

---

## 5. Key Subsystems & How They Work

### A. Telemetry & Autopilot Communication (`DroneVehicle.cpp`)
- Listens to incoming bytes parsed by `mavlink_parse_char()`.
- Automatically decodes MAVLink packets: `HEARTBEAT`, `GLOBAL_POSITION_INT`, `ATTITUDE`, `VFR_HUD`, `SYS_STATUS`, `GPS_RAW_INT`, `PARAM_VALUE`, `MISSION_ACK`, `STATUSTEXT`.
- Dynamically identifies autopilot: `m_autopilotType` is either `"ArduPilot"` or `"PX4"`.
- Available flight modes dynamically populate depending on the connected autopilot.

### B. 2D & 3D Geospatial Map Architecture (`MapPage.qml`, `map.js`, `map3d.js`)
- `MapPage.qml` hosts a `WebEngineView` and a view toggle button (`2D / 3D`).
- A `QWebChannel` registers the active `DroneVehicle` as `"drone"` in JavaScript.
- **2D Mode (`map/map.js`)**: Uses Leaflet with offline/online tile providers.
- **3D Mode (`map/map3d.js`)**: Uses CesiumJS with a dark high-contrast 3D quadcopter model (`map/models/drone.glb`). Reflects live telemetry (attitude, heading, position, altitude) with visual interpolation.
- **4 Camera Modes**: Free Camera, Follow Drone, Top-Down, and Overview.
- **3D Mission Paths**: Color-coded segments differentiating completed waypoints (cyan) from upcoming waypoints (amber/yellow) with dynamic RTL return vectors.

### C. Unified Vehicle Parameter Subsystem (`ParametersPage.qml`)
- **1-Click Batch Upload**: `⬆ Upload All to Drone` collects all parameters from `paramModel` and calls `drone.uploadAllParameters(list)`.
- **Paced MAVLink Transmission**: C++ transmits parameters with a 15ms timer interval (`m_paramUploadTimer`) to ensure zero packet loss over serial and telemetry radios.
- **Direct Parameter Injection (`+ Add Parameter`)**: Modal dialog with type selection (`REAL32`, `INT32`, `INT16`, `INT8`) and auto-presets for ArduPilot and PX4.
- **Unified Dynamics Tuning**: Adjusts Return-to-Launch Speed, Yaw Turn Rate, and Auto-Yaw behavior on both ArduPilot and PX4 with single unified controls.
- **Feedback**: Clean notification banner and voice annunciator callout: *"Parameter uploaded"*.

### D. Mission Planning & Safety Failsafes (`MissionPage.qml`)
- Interactive point-and-click waypoints with altitude, speed, and loiter controls.
- **Automated Survey Grid Generator**: Computes transect paths for mapping and agriculture.
- **3D Terrain Elevation Profile**: Evaluates ground clearance and warns against CFIT.
- **Non-Destructive RTL**: Automatically appends an RTL waypoint after the final user waypoint without replacing user waypoints.
- **Auditory Confirmation**: Announces *"Mission uploaded, ready for auto mode"* upon upload.
- **Critical Battery RTL Failsafe**: Triggers automatic Return-to-Launch when battery is below 10% (configurable via master toggle in Settings).

---

## 6. Critical Engineering Guidelines for New Development

1. **Information Architecture**:
   - The **Map workspace is the primary operational screen**. Do not introduce a redundant standalone dashboard or duplicate PFD navigation tabs.
   - Every piece of information has one primary home: coordinates on Map, waypoints in Mission Planner, parameters in Parameters, video in Video & Payload.

2. **Qt Quick / QML Layout Rules**:
   - Inside any `ColumnLayout` or `RowLayout`, **never rely solely on raw `height` or `width`** without specifying `Layout.preferredHeight` / `Layout.preferredWidth` and `visible`. Failure to do so will cause child elements to overlap.

3. **MAVLink Serialization & Radio Links**:
   - When sending batches of MAVLink commands or parameters, always pace transmissions (10–20ms) using a `QTimer`. Never flood a serial or 57600 baud radio link in a synchronous loop.

4. **AppImage Replacement on Linux**:
   - If overwriting a running AppImage binary, never use direct `cp source destination` (causes `Text file busy` / `ETXTBUSY`). Always use atomic copy-and-rename:
     `cp source dest.tmp && mv -f dest.tmp dest`.

5. **Audio Annunciator**:
   - Use `audioAnnunciator.say("message text")` for auditory feedback. Keep spoken callouts concise, calm, and professional.

---

## 7. Connecting to Simulators for Testing (SITL)

### ArduPilot SITL (TCP or UDP)
```bash
# ArduPilot SITL typically broadcasts MAVLink on UDP 14550 or listens on TCP 5760:
sim_vehicle.py -v ArduCopter --console --map
```
In DroneGCS, click **Auto-Connect** or select **TCP -> Connect to 127.0.0.1:5760**.

### PX4 SITL (UDP)
```bash
# PX4 typically broadcasts MAVLink on UDP 14540 / 14550:
make px4_sitl jmavsim
```
In DroneGCS, click **Auto-Connect** or select **UDP -> Port 14550**.
