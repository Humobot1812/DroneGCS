import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.15
import QtWebChannel 1.15
import "../components"

// Map Page — Master Flight Command Center & Interactive Map with Live Telemetry HUD
Rectangle {
    id: root
    color: "#0d1117"

    property var drone: droneManager.activeDrone
    property string activeInteractionMode: "none"
    property bool hudCollapsed: false
    property bool showPfdGauge: true

    // QWebChannel bridge object exposed to JavaScript
    WebChannel {
        id: webChannel
        registeredObjects: [mapBridge]
    }

    // QObject exposed to JS — receives calls from Leaflet map
    QtObject {
        id: mapBridge
        WebChannel.id: "bridge"

        // Called by JS when user draws a polygon
        function onPolygonDrawn(coordsJson) {
            var coords = JSON.parse(coordsJson);
            if (typeof missionPage !== "undefined" && missionPage.setPolygon) {
                missionPage.setPolygon(coords);
            }
            if (drone && drone.geofenceEnabled) {
                drone.uploadGeofence(coords, drone.geofenceMaxAlt, drone.geofenceMinAlt, drone.geofenceRadius, drone.geofenceAction);
            }
        }

        // Called by JS when a waypoint is moved
        function onWaypointMoved(seq, lat, lon) {
            if (typeof waypointDrawer !== "undefined" && waypointDrawer.waypoints) {
                var wps = waypointDrawer.waypoints.slice();
                if (seq >= 0 && seq < wps.length) {
                    wps[seq].lat = lat;
                    wps[seq].lon = lon;
                    waypointDrawer.setWaypoints(wps);
                }
            }
        }
    }

    // Update map with all drone positions on telemetry change
    Connections {
        target: droneManager
        function onDroneAdded(drone) { connectDroneToMap(drone) }
    }

    Connections {
        target: drone ? drone : null
        function onPositionChanged() {
            if (drone && drone.homeLat !== 0) {
                mapView.runJavaScript("setBatteryRthRadius(" + drone.homeLat + "," + drone.homeLon + "," + drone.safeReturnRadius + ");");
                if (drone.geofenceEnabled && drone.circularFenceEnabled) {
                    mapView.runJavaScript("setGeofenceRadius(" + drone.homeLat + "," + drone.homeLon + "," + drone.geofenceRadius + ");");
                }
            }
        }
        function onBatteryChanged() {
            if (drone && drone.homeLat !== 0) {
                mapView.runJavaScript("setBatteryRthRadius(" + drone.homeLat + "," + drone.homeLon + "," + drone.safeReturnRadius + ");");
            }
        }
        function onGeofenceChanged() {
            if (drone && drone.homeLat !== 0 && drone.geofenceEnabled && drone.circularFenceEnabled) {
                mapView.runJavaScript("setGeofenceRadius(" + drone.homeLat + "," + drone.homeLon + "," + drone.geofenceRadius + ");");
            } else if (!drone || !drone.geofenceEnabled) {
                mapView.runJavaScript("clearGeofence();");
            } else if (!drone.circularFenceEnabled) {
                mapView.runJavaScript("clearGeofenceCircle();");
            }
        }
        function onCircularFenceEnabledChanged() {
            if (drone && drone.homeLat !== 0 && drone.geofenceEnabled && drone.circularFenceEnabled) {
                mapView.runJavaScript("setGeofenceRadius(" + drone.homeLat + "," + drone.homeLon + "," + drone.geofenceRadius + ");");
            } else {
                mapView.runJavaScript("clearGeofenceCircle();");
            }
        }
    }

    function connectDroneToMap(drone) {
        drone.positionChanged.connect(function() {
            var js = "if (typeof updateDroneMarker === 'function') updateDroneMarker(" +
                     drone.sysId + "," + drone.latitude + "," + drone.longitude + "," +
                     drone.headingDeg + ",'" + drone.color + "','" + drone.name + "');";
            mapView.runJavaScript(js);
        });
    }

    function setWaypoints(wps) {
        mapView.runJavaScript("setWaypoints(" + JSON.stringify(wps) + ")");
    }

    function setGeofence(poly) {
        mapView.runJavaScript("setGeofence(" + JSON.stringify(poly) + ")");
    }

    signal requestCloseAiDrawer()
    property bool isReplayActive: false

    function openFlightLogs() {
        flightLogDialog.open();
    }

    function setAiDrawerOpen(isOpen) {
        if (mapView) {
            mapView.runJavaScript("if (typeof setAiDrawerOpen === 'function') setAiDrawerOpen(" + (isOpen ? "true" : "false") + ");");
        }
        if (isOpen) {
            geofenceDrawer.visible = false;
            waypointDrawer.visible = false;
        }
    }

    function startFlightReplay(records) {
        if (!records || records.length === 0) return;
        isReplayActive = true;
        geofenceDrawer.visible = false;
        waypointDrawer.visible = false;
        root.requestCloseAiDrawer();

        replayBar.loadRecords(records);
        var coords = [];
        for (var i = 0; i < records.length; ++i) {
            var r = records[i];
            if (r.lat && r.lon && (r.lat !== 0 || r.lon !== 0)) {
                coords.push({
                    lat: r.lat,
                    lon: r.lon,
                    alt: r.relAlt || 0,
                    speed: r.groundSpeed || 0,
                    time: r.timeShort || ""
                });
            }
        }
        if (mapView) {
            mapView.runJavaScript("if (typeof setReplayTrack === 'function') setReplayTrack(" + JSON.stringify(coords) + ");");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═════════════════════════════════════════════════════════════════════
        // 1. TOP FLIGHT CONTROL DECK & AUTOPILOT BADGE (Master Flight Header)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: flightHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            z: 20
            color: "#161b22"
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Drone color indicator dot
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: drone ? drone.color : "#00d4ff"
                }

                // Drone Name & Vehicle Type
                Column {
                    spacing: 1
                    Text {
                        text: drone ? drone.name : "No Drone"
                        color: "#e6edf3"; font.pixelSize: 12; font.bold: true
                    }
                    Text {
                        text: drone && drone.vehicleType !== "" ? drone.vehicleType : "Quadrotor"
                        color: "#7d8590"; font.pixelSize: 9
                        font.family: "JetBrains Mono, monospace"
                    }
                }

                Rectangle { width: 1; height: 18; color: "#30363d" }

                Text {
                    text: "SYS " + (drone ? drone.sysId : "—")
                    color: "#8b949e"; font.pixelSize: 10
                    font.family: "JetBrains Mono, monospace"
                }

                Rectangle { width: 1; height: 18; color: "#30363d" }

                // ── Flight Log Console Launcher (Top-Left) ───────────────────
                Rectangle {
                    implicitWidth: flightLogBtnRow.implicitWidth + 16
                    implicitHeight: 28
                    Layout.preferredHeight: 28
                    radius: 4
                    color: flightLogMouse.containsMouse ? "#21262d" : "#0d1117"
                    border.color: flightLogMouse.containsMouse ? "#00d4ff" : "#30363d"
                    border.width: 1

                    RowLayout {
                        id: flightLogBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "📋"; font.pixelSize: 12 }
                        Text {
                            text: "Flight Logs"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#e6edf3"
                        }
                        Rectangle {
                            height: 16; width: flCountTxt.implicitWidth + 8; radius: 8
                            color: "#00d4ff"
                            Text {
                                id: flCountTxt
                                anchors.centerIn: parent
                                text: drone ? drone.flightLogCount : 0
                                font.pixelSize: 9
                                font.bold: true
                                color: "#0d1117"
                            }
                        }
                    }

                    MouseArea {
                        id: flightLogMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: flightLogDialog.open()
                    }
                }

                Rectangle { width: 1; height: 22; color: "#30363d" }

                // ── Autopilot Logo Badge (ArduPilot / PX4) ────────────────────
                Rectangle {
                    id: apBadge
                    implicitWidth: apBadgeRow.implicitWidth + 24
                    implicitHeight: 28
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: 28
                    radius: 5
                    visible: drone && drone.autopilotType !== ""

                    color: {
                        if (!drone) return "#21262d";
                        if (drone.autopilotType === "ArduPilot") return "#2d1a0a";
                        if (drone.autopilotType === "PX4")       return "#1a0d2d";
                        return "#21262d";
                    }
                    border.color: {
                        if (!drone) return "#30363d";
                        if (drone.autopilotType === "ArduPilot") return "#e05a1d";
                        if (drone.autopilotType === "PX4")       return "#6e40c9";
                        return "#30363d";
                    }
                    border.width: 1

                    Row {
                        id: apBadgeRow
                        anchors.centerIn: parent
                        spacing: 6

                        Canvas {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            property string apType: drone ? drone.autopilotType : ""
                            onApTypeChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (apType === "ArduPilot") {
                                    ctx.strokeStyle = "#e05a1d";
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    ctx.moveTo(8, 2); ctx.lineTo(2, 14); ctx.moveTo(8, 2); ctx.lineTo(14, 14);
                                    ctx.moveTo(4.5, 9.5); ctx.lineTo(11.5, 9.5);
                                    ctx.stroke();
                                } else if (apType === "PX4") {
                                    ctx.strokeStyle = "#a070f0";
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    ctx.moveTo(3, 3); ctx.lineTo(13, 13);
                                    ctx.moveTo(13, 3); ctx.lineTo(3, 13);
                                    ctx.stroke();
                                }
                            }
                        }

                        Text {
                            text: drone ? drone.autopilotType : "—"
                            color: {
                                if (!drone) return "#7d8590";
                                if (drone.autopilotType === "ArduPilot") return "#e05a1d";
                                if (drone.autopilotType === "PX4")       return "#a070f0";
                                return "#7d8590";
                            }
                            font.pixelSize: 11; font.bold: true
                            font.family: "JetBrains Mono, monospace"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ── Armed / Disarmed Badge ────────────────────────────────────
                Rectangle {
                    implicitWidth: armedRow.implicitWidth + 20
                    implicitHeight: 28
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: 28
                    radius: 5
                    color: drone && drone.isArmed ? "#3d1b1b" : "#1b3d1b"
                    border.color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                    border.width: 1

                    Row {
                        id: armedRow
                        anchors.centerIn: parent; spacing: 5
                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: drone && drone.isArmed ? "ARMED" : "DISARMED"
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // ── Flight Mode Selector Dropdown ─────────────────────────────
                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                    Text { text: "MODE:"; color: "#8b949e"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

                    ComboBox {
                        id: flightModeCombo
                        implicitWidth: 135
                        implicitHeight: 30
                        Layout.preferredWidth: 135
                        Layout.preferredHeight: 30
                        model: ["GUIDED", "AUTO", "LOITER", "STABILIZE", "ALT_HOLD", "RTL", "LAND", "BRAKE", "POSHOLD"]
                        currentIndex: {
                            if (!drone) return 0;
                            var idx = model.indexOf(drone.flightMode);
                            return idx >= 0 ? idx : 0;
                        }
                        font.pixelSize: 11; font.bold: true
                        Material.background: "#21262d"
                        Material.foreground: "#00d4ff"

                        onActivated: function(index) {
                            if (drone) drone.setFlightMode(currentText);
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ── Quick Flight Action Buttons ───────────────────────────────
                RowLayout {
                    spacing: 6

                    // Arm / Disarm Button
                    Button {
                        text: drone && drone.isArmed ? "DISARM" : "ARM"
                        Layout.preferredHeight: 32
                        font.bold: true
                        font.pixelSize: 11
                        Material.background: drone && drone.isArmed ? "#3d1b1b" : "#1b3d1b"
                        contentItem: Text {
                            text: parent.text
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (drone) {
                                if (drone.isArmed) disarmDialog.open();
                                else preflightChecklistDialog.open();
                            }
                        }
                    }

                    // Takeoff Button
                    Button {
                        text: "TAKEOFF"
                        Layout.preferredHeight: 32
                        font.bold: true
                        font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text
                            color: "#00d4ff"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: takeoffPopup.open()
                    }

                    // Land Button
                    Button {
                        text: "LAND"
                        Layout.preferredHeight: 32
                        font.bold: true
                        font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text
                            color: "#d29922"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: landDialog.open()
                    }

                    // RTL Button
                    Button {
                        text: "RTL"
                        Layout.preferredHeight: 32
                        font.bold: true
                        font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text
                            color: "#3fb950"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: rtlDialog.open()
                    }

                    Rectangle { width: 1; height: 20; color: "#30363d" }

                    // Emergency Kill Button (visually separated)
                    Button {
                        text: "EMERGENCY MOTOR CUT"
                        Layout.preferredHeight: 32
                        font.bold: true
                        font.pixelSize: 10
                        Material.background: "#351010"
                        contentItem: Text {
                            text: parent.text
                            color: "#ff6b6b"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: emergencyDialog.open()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2. MAP TOOLS TOOLBAR (Layers, Measure, Survey, Add WP, Upload, Clear)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: toolbar
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            z: 15
            color: "#161b22"
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 6

                // Map Provider ComboBox
                ComboBox {
                    id: mapProviderCombo
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 26
                    model: [
                        "Google Hybrid",
                        "Google Satellite",
                        "ESRI Satellite",
                        "OpenStreetMap",
                        "Tactical Dark",
                        "Google Terrain"
                    ]
                    currentIndex: 0
                    font.pixelSize: 11
                    Material.background: "#21262d"
                    Material.foreground: "#e6edf3"

                    onActivated: function(index) {
                        mapView.runJavaScript("setMapProvider('" + currentText + "');");
                    }
                }

                // Custom Tile / API Configuration Button
                Button {
                    text: "API Keys"
                    Layout.preferredHeight: 26
                    font.pixelSize: 10
                    Material.background: "#21262d"
                    contentItem: Text {
                        text: parent.text; color: "#00d4ff"; font: parent.font
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: apiDialog.open()
                }

                Rectangle { width: 1; height: 16; color: "#30363d" }

                // Measure Tool
                Rectangle {
                    id: measureBtn
                    width: 76; height: 26; radius: 4
                    property bool active: root.activeInteractionMode === "measure"
                    color: active ? "#f59e0b25" : "#21262d"
                    border.color: active ? "#f59e0b" : "#30363d"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "MEASURE"
                        color: measureBtn.active ? "#f59e0b" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: measureBtn.active
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeInteractionMode === "measure") {
                                root.activeInteractionMode = "none";
                                mapView.runJavaScript("setInteractionMode(null)");
                            } else {
                                root.activeInteractionMode = "measure";
                                mapView.runJavaScript("setInteractionMode('measure')");
                                mapView.forceActiveFocus();
                            }
                        }
                    }
                }

                // Draw Survey Polygon
                Rectangle {
                    id: drawBtn
                    width: 86; height: 26; radius: 4
                    property bool drawActive: false
                    color: drawActive ? "#3fb95025" : "#21262d"
                    border.color: drawActive ? "#3fb950" : "#30363d"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: drawBtn.drawActive ? "DRAWING..." : "SURVEY AREA"
                        color: drawBtn.drawActive ? "#3fb950" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: drawBtn.drawActive
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            drawBtn.drawActive = !drawBtn.drawActive;
                            mapView.runJavaScript(drawBtn.drawActive ? "startDrawPolygon()" : "stopDraw()");
                            if (drawBtn.drawActive) mapView.forceActiveFocus();
                        }
                    }
                }

                // Add Manual Waypoint Tool
                Rectangle {
                    id: addWpBtn
                    width: 72; height: 26; radius: 4
                    property bool active: root.activeInteractionMode === "addwp"
                    color: active ? "#f59e0b25" : "#21262d"
                    border.color: active ? "#f59e0b" : "#30363d"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "+ WP"
                        color: addWpBtn.active ? "#f59e0b" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: addWpBtn.active
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeInteractionMode === "addwp") {
                                root.activeInteractionMode = "none";
                                mapView.runJavaScript("setInteractionMode(null)");
                            } else {
                                root.activeInteractionMode = "addwp";
                                mapView.runJavaScript("setInteractionMode('addwp')");
                                mapView.forceActiveFocus();
                            }
                        }
                    }
                }

                // WP Altitude Spinner (visible when adding waypoints)
                Row {
                    spacing: 4; visible: root.activeInteractionMode === "addwp"
                    Text { text: "Alt:"; color: "#8b949e"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    SpinBox {
                        id: wpAltSpin; from: 5; to: 120; value: 15; stepSize: 5
                        width: 75; height: 24
                        onValueChanged: mapView.runJavaScript("setManualWpAlt(" + value + ")")
                    }
                    Text { text: "m"; color: "#8b949e"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }

                // ── Upload Waypoint Mission Button ────────────────────────────
                Rectangle {
                    id: uploadWpBtn
                    width: 110; height: 26; radius: 4
                    color: "#21262d"
                    border.color: "#3fb950"; border.width: 1
                    visible: drone && drone.isConnected

                    Text {
                        anchors.centerIn: parent
                        text: "UPLOAD MISSION"
                        color: "#3fb950"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mapView.runJavaScript("getWaypoints()", function(result) {
                                if (!result || result === "[]") {
                                    wpUploadStatus.text = "⚠ No waypoints placed!";
                                    wpUploadStatus.color = "#f59e0b";
                                    wpUploadStatus.visible = true;
                                    wpStatusTimer.restart();
                                    return;
                                }
                                var wps = JSON.parse(result);
                                if (drone) {
                                    drone.uploadWaypoints(wps);
                                    wpUploadStatus.text = "✅ Uploaded " + wps.length + " waypoints!";
                                    wpUploadStatus.color = "#3fb950";
                                    wpUploadStatus.visible = true;
                                    wpStatusTimer.restart();
                                }
                            });
                        }
                    }
                }

                // ── Clear Current Uploaded Mission Button ─────────────────────
                Rectangle {
                    id: clearMissionBtn
                    width: 100; height: 26; radius: 4
                    color: "#21262d"
                    border.color: "#f85149"; border.width: 1
                    visible: drone && drone.isConnected

                    Text {
                        anchors.centerIn: parent
                        text: "CLEAR MISSION"
                        color: "#f85149"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (drone) {
                                drone.clearMission();
                            }
                            mapView.runJavaScript("clearWaypoints()");
                            wpUploadStatus.text = "Mission Cleared";
                            wpUploadStatus.color = "#f85149";
                            wpUploadStatus.visible = true;
                            wpStatusTimer.restart();
                        }
                    }
                }

                // Toast status for mission upload / clear
                Text {
                    id: wpUploadStatus
                    visible: false; font.pixelSize: 11; font.bold: true
                    Timer {
                        id: wpStatusTimer
                        interval: 3500
                        onTriggered: wpUploadStatus.visible = false
                    }
                }

                // ── Geofence Drawer Button ──
                Rectangle {
                    width: 78; height: 26; radius: 4
                    property bool active: geofenceDrawer.visible
                    color: active ? "#3fb95025" : "#21262d"
                    border.color: active ? "#3fb950" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "GEOFENCE"
                        color: parent.active ? "#3fb950" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: parent.active
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            geofenceDrawer.visible = !geofenceDrawer.visible;
                            if (geofenceDrawer.visible) {
                                waypointDrawer.visible = false;
                                root.requestCloseAiDrawer();
                            }
                        }
                    }
                }

                // ── Pre-flight Systems Verification Button ──
                Rectangle {
                    width: 82; height: 26; radius: 4
                    color: "#21262d"; border.color: "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "CHECKLIST"
                        color: "#e6edf3"
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: preflightChecklistDialog.open()
                    }
                }

                // ── PIP Video Toggle Button ──
                Rectangle {
                    width: 74; height: 26; radius: 4
                    property bool active: pipVideo.visible
                    color: active ? "#00d4ff25" : "#21262d"
                    border.color: active ? "#00d4ff" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "PIP CAM"
                        color: parent.active ? "#00d4ff" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: parent.active
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: pipVideo.visible = !pipVideo.visible
                    }
                }

                // ── Oscilloscope / Telemetry Grapher Button ──
                Rectangle {
                    width: 66; height: 26; radius: 4
                    property bool active: telemetryScope.visible
                    color: active ? "#c084fc25" : "#21262d"
                    border.color: active ? "#c084fc" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "SCOPE"
                        color: parent.active ? "#c084fc" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: parent.active
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: telemetryScope.visible = !telemetryScope.visible
                    }
                }

                // ── Waypoint Mission Table Drawer Button ──
                Rectangle {
                    width: 78; height: 26; radius: 4
                    property bool active: waypointDrawer.visible
                    color: active ? "#f59e0b25" : "#21262d"
                    border.color: active ? "#f59e0b" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "WP TABLE"
                        color: parent.active ? "#f59e0b" : "#e6edf3"
                        font.pixelSize: 10
                        font.bold: parent.active
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            waypointDrawer.visible = !waypointDrawer.visible;
                            if (waypointDrawer.visible) {
                                geofenceDrawer.visible = false;
                                root.requestCloseAiDrawer();
                                mapView.runJavaScript("getWaypoints()", function(res) {
                                    if (res) waypointDrawer.setWaypoints(JSON.parse(res));
                                });
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear Overlays
                Rectangle {
                    width: 60; height: 26; radius: 4
                    color: "#21262d"; border.color: "#30363d"; border.width: 1
                    Text { text: "RESET"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeInteractionMode = "none";
                            drawBtn.drawActive = false;
                            mapView.runJavaScript("clearAll()");
                        }
                    }
                }

                // Center / Follow Drone
                Rectangle {
                    width: 96; height: 26; radius: 4
                    color: "#21262d"; border.color: "#00d4ff"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "LOCATE DRONE"
                        color: "#00d4ff"
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var d = droneManager.activeDrone;
                            if (d) mapView.runJavaScript("centerOn(" + d.latitude + "," + d.longitude + ")");
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 3. MAP VIEW (Leaflet WebEngineView)
        // ═════════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WebEngineView {
                id: mapView
                anchors.fill: parent
                url: "file://" + appDirPath + "/map/map.html"
                webChannel: webChannel
                settings.javascriptEnabled: true
                settings.localContentCanAccessRemoteUrls: true
                settings.localContentCanAccessFileUrls: true

                onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
                    console.log("[Leaflet Map JS]", message, "line:", lineNumber);
                }
            }

            // ── Flashing Geofence Breach Alarm Banner ──
            Rectangle {
                id: geofenceAlarmBanner
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                height: 42
                z: 60
                radius: 6
                color: "#551a1a"
                border.color: "#ff6b6b"
                border.width: 2
                visible: drone ? drone.geofenceBreached : false

                SequentialAnimation on opacity {
                    running: geofenceAlarmBanner.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.4; duration: 500 }
                    NumberAnimation { from: 0.4; to: 1.0; duration: 500 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 12
                    Text {
                        text: "🚨 WARNING: GEOFENCE BREACH DETECTED! " + (drone ? drone.geofenceBreachReason : "")
                        font.pixelSize: 12; font.bold: true; color: "#ffffff"
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Button {
                        text: "🏠 OVERRIDE: RTL"
                        font.bold: true; font.pixelSize: 11
                        Material.background: "#ff6b6b"
                        Material.foreground: "#ffffff"
                        onClicked: if (drone) drone.returnToLaunch()
                    }
                }
            }

            // ── Geofence Console Drawer ──
            GeofenceConsole {
                id: geofenceDrawer
                visible: false
                anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 14 }
                z: 45
                onCloseRequested: visible = false
                onDrawKeepInRequested: mapView.runJavaScript("startDrawPolygon()")
                onDrawKeepOutRequested: mapView.runJavaScript("startDrawPolygon()")
                onClearMapFenceRequested: mapView.runJavaScript("clearGeofence()")
            }

            // ── Waypoint Mission Table Drawer ──
            WaypointEditorDrawer {
                id: waypointDrawer
                visible: false
                anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 14 }
                z: 45
                onCloseRequested: visible = false
                onWaypointSelected: function(index) {
                    mapView.runJavaScript("highlightWaypoint(" + index + ")");
                }
                onWaypointsModified: function(newWps) {
                    mapView.runJavaScript("setManualWaypointList(" + JSON.stringify(newWps) + ")");
                }
            }

            // ── Floating PIP Video Feed ──
            PipVideoWidget {
                id: pipVideo
                visible: false
                anchors { right: parent.right; bottom: parent.bottom; margins: 14 }
                onCloseRequested: visible = false
                onExpandToFullVideoRequested: {
                    if (typeof root.parent !== "undefined" && typeof root.parent.currentPage !== "undefined") {
                        root.parent.currentPage = 3;
                    }
                }
            }

            // ── Real-time Telemetry Oscilloscope ──
            TelemetryGrapher {
                id: telemetryScope
                visible: false
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 14 }
                z: 45
                onCloseRequested: visible = false
            }

            // ── Flight Replay Scrubber Floating Deck ──
            FlightReplayBar {
                id: replayBar
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                z: 48
                visible: root.isReplayActive

                onPositionChanged: function(record) {
                    if (mapView && record) {
                        var lat = record.lat || 0;
                        var lon = record.lon || 0;
                        var hdg = record.heading || 0;
                        var alt = record.relAlt || 0;
                        var spd = record.groundSpeed || 0;
                        mapView.runJavaScript("if (typeof setReplayGhost === 'function') setReplayGhost(" + lat + "," + lon + "," + hdg + "," + alt + "," + spd + ");");
                    }
                }

                onCloseRequested: {
                    root.isReplayActive = false;
                    if (mapView) {
                        mapView.runJavaScript("if (typeof clearReplayTrack === 'function') clearReplayTrack();");
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // 4. FLOATING LIVE TELEMETRY & INSTRUMENT HUD (HUD on Map)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                id: mapHud
                anchors { top: parent.top; left: parent.left; margins: 14 }
                width: 310
                height: root.hudCollapsed ? 42 : (root.showPfdGauge ? 370 : 220)
                z: 30
                radius: 10

                // 100% OPAQUE SOLID DARK PANEL — Never washed out by map terrain!
                color: "#0d1117"
                border.color: "#30363d"
                border.width: 1

                Behavior on height { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // HUD Header Bar: Title + PFD Toggle + Collapse Button
                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: drone && drone.isConnected ? "#3fb950" : "#f85149"
                        }

                        Text {
                            text: drone ? drone.name.toUpperCase() : "FLIGHT TELEMETRY"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrains Mono, monospace"
                            Layout.fillWidth: true
                        }

                        // Toggle Attitude Indicator (PFD)
                        Rectangle {
                            width: 50; height: 22; radius: 4
                            visible: !root.hudCollapsed
                            color: root.showPfdGauge ? "#00d4ff25" : "#21262d"
                            border.color: root.showPfdGauge ? "#00d4ff" : "#30363d"
                            Text {
                                text: "PFD"
                                font.pixelSize: 10; font.bold: true
                                color: root.showPfdGauge ? "#00d4ff" : "#8b949e"
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.showPfdGauge = !root.showPfdGauge
                            }
                        }

                        // Collapse / Expand toggle button
                        Rectangle {
                            width: 24; height: 22; radius: 4
                            color: "#21262d"
                            border.color: "#30363d"
                            Text {
                                text: root.hudCollapsed ? "▼" : "▲"
                                color: "#8b949e"; font.pixelSize: 10; font.bold: true
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.hudCollapsed = !root.hudCollapsed
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d"; visible: !root.hudCollapsed }

                    // Telemetry Values Grid (High Contrast, Bold, Dark Theme)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 12
                        visible: !root.hudCollapsed

                        // 1. Altitude
                        Column {
                            spacing: 2
                            Text { text: "ALTITUDE"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 4
                                Text {
                                    text: drone ? drone.relAltitude.toFixed(1) + " m" : "0.0 m"
                                    color: "#3fb950"; font.pixelSize: 15; font.bold: true
                                    font.family: "JetBrains Mono, monospace"
                                }
                                Text {
                                    text: "AGL"
                                    color: "#7d8590"; font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 2. Ground Speed
                        Column {
                            spacing: 2
                            Text { text: "GROUND SPEED"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 4
                                Text {
                                    text: drone ? drone.groundSpeed.toFixed(1) + " m/s" : "0.0 m/s"
                                    color: "#00d4ff"; font.pixelSize: 15; font.bold: true
                                    font.family: "JetBrains Mono, monospace"
                                }
                                Text {
                                    text: drone ? ("(" + (drone.groundSpeed * 3.6).toFixed(0) + " km/h)") : ""
                                    color: "#7d8590"; font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 3. Vertical Climb Rate
                        Column {
                            spacing: 2
                            Text { text: "CLIMB RATE"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Text {
                                text: drone ? ((drone.climbRate >= 0 ? "↑ +" : "↓ ") + drone.climbRate.toFixed(1) + " m/s") : "0.0 m/s"
                                color: drone && drone.climbRate >= 0 ? "#3fb950" : "#d29922"
                                font.pixelSize: 14; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                            }
                        }

                        // 4. Battery Level
                        Column {
                            spacing: 2
                            Text { text: "BATTERY"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 5
                                Text {
                                    text: drone && drone.batteryPercent >= 0 ? drone.batteryPercent + "%" : "—"
                                    color: drone && drone.batteryPercent > 25 ? "#3fb950" : "#f85149"
                                    font.pixelSize: 14; font.bold: true
                                    font.family: "JetBrains Mono, monospace"
                                }
                                Text {
                                    text: drone && drone.batteryVoltage > 0 ? drone.batteryVoltage.toFixed(2) + "V" : ""
                                    color: "#8b949e"; font.pixelSize: 12
                                    font.family: "JetBrains Mono, monospace"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 5. GPS Satellites & Fix
                        Column {
                            spacing: 2
                            Text { text: "GPS POSITION"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Text {
                                text: drone ? (drone.gpsSats + " Sats · " + (drone.gpsFixType >= 3 ? "3D Fix" : "No Fix")) : "—"
                                color: drone && drone.gpsFixType >= 3 ? "#e6edf3" : "#f85149"
                                font.pixelSize: 13; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                            }
                        }

                        // 6. Heading
                        Column {
                            spacing: 2
                            Text { text: "HEADING"; color: "#c9d1d9"; font.pixelSize: 11; font.bold: true }
                            Text {
                                text: drone ? (drone.headingDeg.toFixed(0) + "°") : "0°"
                                color: "#00d4ff"; font.pixelSize: 14; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                            }
                        }
                    }

                    // Mini Attitude Indicator (Artificial Horizon Instrument)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 145
                        color: "#161b22"
                        radius: 8
                        visible: !root.hudCollapsed && root.showPfdGauge

                        AttitudeIndicator {
                            id: ai
                            roll: drone ? drone.roll : 0
                            pitch: drone ? drone.pitch : 0
                            anchors.centerIn: parent
                            width: 135
                            height: 135
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // 5. MAVLINK STATUSTEXT BANNER (Autopilot Messages)
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                id: statusBanner
                anchors {
                    top: parent.top; topMargin: 12
                    horizontalCenter: parent.horizontalCenter
                }
                visible: drone && drone.lastStatusText !== ""
                width: Math.min(statusMsgText.implicitWidth + 36, 600)
                height: 32
                radius: 6
                z: 25
                color: "#161b22f0"
                border.color: "#00d4ff"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "💬"; font.pixelSize: 12 }
                    Text {
                        id: statusMsgText
                        text: drone ? drone.lastStatusText : ""
                        color: "#e6edf3"
                        font.pixelSize: 11; font.bold: true
                        font.family: "JetBrains Mono, monospace"
                    }
                }
            }
        }
    }

    // ── Pre-flight Systems Verification Modal ──
    PreFlightChecklist {
        id: preflightChecklistDialog
    }

    // ── Disarm Confirmation Dialog with Slide-To-Confirm ──
    Dialog {
        id: disarmDialog
        title: "Disarm Vehicle Motors"
        anchors.centerIn: parent
        width: 360
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 12
            Text {
                text: "Confirm command to stop and disarm motors on " + (drone ? drone.name : "drone") + ":"
                color: "#8b949e"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            SlideToConfirm {
                Layout.fillWidth: true
                label: "SLIDE TO DISARM"
                iconText: "⬛"
                accentColor: "#f85149"
                dangerMode: true
                onConfirmed: {
                    if (drone) drone.disarm();
                    disarmDialog.close();
                }
            }
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Material.background: "#21262d"
                onClicked: disarmDialog.close()
            }
        }
    }

    // ── Quick Takeoff Altitude Dialog with Slide-To-Confirm ──
    Dialog {
        id: takeoffPopup
        title: "🛫 Takeoff Clearance"
        anchors.centerIn: parent
        width: 380
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 14
            Text {
                text: "Set target climb altitude and swipe to initiate takeoff:"
                color: "#8b949e"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            RowLayout {
                spacing: 8
                Text { text: "Altitude AGL:"; color: "#e6edf3"; font.pixelSize: 12 }
                SpinBox {
                    id: altSpinBox
                    from: 2; to: 120; value: 15; stepSize: 5
                    editable: true
                    font.pixelSize: 12
                    Material.background: "#21262d"
                }
                Text { text: "meters"; color: "#8b949e"; font.pixelSize: 11 }
            }
            SlideToConfirm {
                Layout.fillWidth: true
                label: "SLIDE TO TAKEOFF"
                iconText: "🛫"
                accentColor: "#00d4ff"
                onConfirmed: {
                    if (drone) drone.takeoff(altSpinBox.value);
                    takeoffPopup.close();
                }
            }
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Material.background: "#21262d"
                onClicked: takeoffPopup.close()
            }
        }
    }

    // ── Land Dialog with Slide-To-Confirm ──
    Dialog {
        id: landDialog
        title: "🛬 Initiate Landing"
        anchors.centerIn: parent
        width: 360
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 12
            Text {
                text: "Command " + (drone ? drone.name : "vehicle") + " to descend and land at current location:"
                color: "#8b949e"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            SlideToConfirm {
                Layout.fillWidth: true
                label: "SLIDE TO LAND"
                iconText: "🛬"
                accentColor: "#d29922"
                onConfirmed: {
                    if (drone) drone.land();
                    landDialog.close();
                }
            }
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Material.background: "#21262d"
                onClicked: landDialog.close()
            }
        }
    }

    // ── Return-To-Launch (RTL) Dialog with Slide-To-Confirm ──
    Dialog {
        id: rtlDialog
        title: "🏠 Return To Launch (RTL)"
        anchors.centerIn: parent
        width: 360
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 12
            Text {
                text: "Command " + (drone ? drone.name : "vehicle") + " to return to home position and land:"
                color: "#8b949e"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            SlideToConfirm {
                Layout.fillWidth: true
                label: "SLIDE TO RETURN HOME"
                iconText: "🏠"
                accentColor: "#3fb950"
                onConfirmed: {
                    if (drone) drone.returnToLaunch();
                    rtlDialog.close();
                }
            }
            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Material.background: "#21262d"
                onClicked: rtlDialog.close()
            }
        }
    }

    // ── Emergency Motor Cut Confirmation Dialog with Slide-To-Confirm ──
    Dialog {
        id: emergencyDialog
        title: "⚠️ EMERGENCY MOTOR CUTOFF"
        anchors.centerIn: parent
        width: 380
        modal: true
        Material.background: "#241616"
        Material.foreground: "#ff6b6b"

        ColumnLayout {
            width: parent.width
            spacing: 12
            Text {
                text: "CRITICAL SAFETY WARNING: Motors will cut IMMEDIATELY! If airborne, the aircraft will fall."
                color: "#ff6b6b"; font.pixelSize: 11; font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            SlideToConfirm {
                Layout.fillWidth: true
                label: "SLIDE FOR MOTOR CUT"
                iconText: "⛔"
                accentColor: "#ff6b6b"
                dangerMode: true
                onConfirmed: {
                    if (drone) drone.emergencyKill();
                    emergencyDialog.close();
                }
            }
            Button {
                text: "Abort / Cancel"
                Layout.fillWidth: true
                Material.background: "#21262d"
                onClicked: emergencyDialog.close()
            }
        }
    }

    // ── Map API Link / Custom Tile Provider Dialog ──
    Dialog {
        id: apiDialog
        title: "Map Tile Provider & API Configuration"
        standardButtons: Dialog.Apply | Dialog.Close
        anchors.centerIn: parent
        width: 520
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 12

            Text {
                text: "Select a high-resolution satellite provider or attach your custom Map API URL:"
                color: "#8b949e"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            // Quick Preset Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Button {
                    text: "Google Hybrid"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    font.pixelSize: 10
                    Material.background: "#21262d"
                    onClicked: {
                        customUrlField.text = "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}";
                    }
                }
                Button {
                    text: "ESRI Satellite"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    font.pixelSize: 10
                    Material.background: "#21262d"
                    onClicked: {
                        customUrlField.text = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}";
                    }
                }
                Button {
                    text: "Mapbox Template"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    font.pixelSize: 10
                    Material.background: "#21262d"
                    onClicked: {
                        customUrlField.text = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/{z}/{x}/{y}?access_token=YOUR_MAPBOX_TOKEN";
                    }
                }
                Button {
                    text: "OpenStreetMap"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    font.pixelSize: 10
                    Material.background: "#21262d"
                    onClicked: {
                        customUrlField.text = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
                    }
                }
            }

            Text { text: "Tile Server URL Template (XYZ format):"; color: "#00d4ff"; font.pixelSize: 11; font.bold: true }

            TextField {
                id: customUrlField
                text: "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"
                Layout.fillWidth: true
                font.family: "JetBrains Mono, monospace"; font.pixelSize: 11
                selectByMouse: true
                Material.background: "#21262d"
                Material.foreground: "#e6edf3"
            }

            Text {
                text: "Tip: Supports Google lyrs=y (hybrid), lyrs=s (sat), ESRI World Imagery, Mapbox, Bing, or local WMS/TMS proxy servers."
                color: "#7d8590"; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }

        onApplied: {
            if (customUrlField.text.trim() !== "") {
                mapView.runJavaScript("setCustomTileUrl('" + customUrlField.text.trim() + "', 21);");
            }
        }
    }

    FlightLogDialog {
        id: flightLogDialog
        drone: root.drone
        onReplayRequested: function(records) {
            flightLogDialog.close();
            root.startFlightReplay(records);
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < droneManager.droneCount; i++) {
            var d = droneManager.droneAt(i);
            if (d) connectDroneToMap(d);
        }
        if (typeof initialOpenLogs !== "undefined" && initialOpenLogs) {
            flightLogDialog.open();
        }
    }
}
