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
        }

        // Called by JS when a waypoint is moved
        function onWaypointMoved(seq, lat, lon) {
            console.log("WP moved on map:", seq, lat, lon);
        }
    }

    // Update map with all drone positions on telemetry change
    Connections {
        target: droneManager
        function onDroneAdded(drone) { connectDroneToMap(drone) }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═════════════════════════════════════════════════════════════════════
        // 1. TOP FLIGHT CONTROL DECK & AUTOPILOT BADGE (Master Flight Header)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: flightHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 46
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
                    width: 10; height: 10; radius: 5
                    color: drone ? drone.color : "#00d4ff"
                }

                // Drone Name & Vehicle Type
                Column {
                    spacing: 0
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

                // Vehicle Type Icon (Emoji)
                Text {
                    font.pixelSize: 16
                    text: {
                        if (!drone || drone.vehicleType === "") return "🔲";
                        var vt = drone.vehicleType;
                        if (vt === "Quadrotor")    return "🔲";
                        if (vt === "Hexarotor")    return "⬡";
                        if (vt === "Octorotor")    return "⭘";
                        if (vt === "Tricopter")    return "△";
                        if (vt === "Fixed Wing")   return "✈";
                        if (vt === "Helicopter")   return "🚁";
                        if (vt === "Rover")        return "🚗";
                        if (vt === "Boat")         return "🚤";
                        if (vt.startsWith("VTOL")) return "🛩";
                        return "🔲";
                    }
                }

                Text {
                    text: "SYS:" + (drone ? drone.sysId : "—")
                    color: "#8b949e"; font.pixelSize: 10
                    font.family: "JetBrains Mono, monospace"
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
                        text: drone && drone.isArmed ? "⬛ DISARM" : "▲ ARM"
                        Layout.preferredHeight: 30
                        font.bold: true; font.pixelSize: 11
                        Material.background: drone && drone.isArmed ? "#3d1b1b" : "#1b3d1b"
                        contentItem: Text {
                            text: parent.text
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (drone) {
                                if (drone.isArmed) drone.disarm();
                                else drone.arm();
                            }
                        }
                    }

                    // Takeoff Button
                    Button {
                        text: "🛫 TAKEOFF"
                        Layout.preferredHeight: 30
                        font.bold: true; font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text; color: "#00d4ff"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: takeoffPopup.open()
                    }

                    // Land Button
                    Button {
                        text: "🛬 LAND"
                        Layout.preferredHeight: 30
                        font.bold: true; font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text; color: "#d29922"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: if (drone) drone.land()
                    }

                    // RTL Button
                    Button {
                        text: "🏠 RTL"
                        Layout.preferredHeight: 30
                        font.bold: true; font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text; color: "#3fb950"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: if (drone) drone.returnToLaunch()
                    }

                    // Emergency Kill Button
                    Button {
                        text: "⛔ KILL"
                        Layout.preferredHeight: 30
                        font.bold: true; font.pixelSize: 11
                        Material.background: "#441b1b"
                        contentItem: Text {
                            text: parent.text; color: "#ff6b6b"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
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
            Layout.preferredHeight: 40
            z: 15
            color: "#161b22"
            border.color: "#21262d"; border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Text {
                    text: "🗺 Map Layers"
                    font.pixelSize: 11
                    color: "#e6edf3"
                    font.bold: true
                }

                // Map Provider ComboBox
                ComboBox {
                    id: mapProviderCombo
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 28
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
                    text: "⚙ Map API"
                    Layout.preferredHeight: 28
                    font.pixelSize: 11
                    Material.background: "#21262d"
                    contentItem: Text {
                        text: parent.text; color: "#00d4ff"; font: parent.font
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: apiDialog.open()
                }

                Rectangle { width: 1; height: 18; color: "#30363d" }

                // Measure Tool
                Rectangle {
                    id: measureBtn
                    width: 88; height: 28; radius: 5
                    property bool active: root.activeInteractionMode === "measure"
                    color: active ? "#f59e0b30" : "#21262d"
                    border.color: active ? "#f59e0b" : "#30363d"; border.width: 1

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "📏"; font.pixelSize: 11 }
                        Text { text: "Measure"; color: measureBtn.active ? "#f59e0b" : "#e6edf3"; font.pixelSize: 11; font.bold: measureBtn.active }
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
                            }
                        }
                    }
                }

                // Draw Survey Polygon
                Rectangle {
                    id: drawBtn
                    width: 105; height: 28; radius: 5
                    property bool drawActive: false
                    color: drawActive ? "#3fb95030" : "#21262d"
                    border.color: drawActive ? "#3fb950" : "#30363d"; border.width: 1

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "✏"; font.pixelSize: 11 }
                        Text { text: drawBtn.drawActive ? "Drawing..." : "Survey Area"; color: drawBtn.drawActive ? "#3fb950" : "#e6edf3"; font.pixelSize: 11 }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            drawBtn.drawActive = !drawBtn.drawActive;
                            mapView.runJavaScript(drawBtn.drawActive ? "startDrawPolygon()" : "stopDraw()");
                        }
                    }
                }

                // Add Manual Waypoint Tool
                Rectangle {
                    id: addWpBtn
                    width: 88; height: 28; radius: 5
                    property bool active: root.activeInteractionMode === "addwp"
                    color: active ? "#f59e0b30" : "#21262d"
                    border.color: active ? "#f59e0b" : "#30363d"; border.width: 1

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "📍"; font.pixelSize: 11 }
                        Text { text: "Add WP"; color: addWpBtn.active ? "#f59e0b" : "#e6edf3"; font.pixelSize: 11; font.bold: addWpBtn.active }
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
                        width: 75; height: 26
                        onValueChanged: mapView.runJavaScript("setManualWpAlt(" + value + ")")
                    }
                    Text { text: "m"; color: "#8b949e"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }

                // ── Upload Waypoint Mission Button ────────────────────────────
                Rectangle {
                    id: uploadWpBtn
                    width: 125; height: 28; radius: 5
                    color: "#21262d"
                    border.color: "#3fb950"; border.width: 1
                    visible: drone && drone.isConnected

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🚀"; font.pixelSize: 11 }
                        Text { text: "Upload Mission"; color: "#3fb950"; font.pixelSize: 11; font.bold: true }
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
                    width: 115; height: 28; radius: 5
                    color: "#21262d"
                    border.color: "#f85149"; border.width: 1
                    visible: drone && drone.isConnected

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "🗑"; font.pixelSize: 11 }
                        Text { text: "Clear Mission"; color: "#f85149"; font.pixelSize: 11; font.bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (drone) {
                                drone.clearMission();
                            }
                            mapView.runJavaScript("clearWaypoints()");
                            wpUploadStatus.text = "🗑 Mission Cleared!";
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

                Item { Layout.fillWidth: true }

                // Clear Overlays
                Rectangle {
                    width: 70; height: 28; radius: 5
                    color: "#21262d"; border.color: "#30363d"; border.width: 1
                    Text { text: "🧹 Clear"; color: "#8b949e"; font.pixelSize: 11; anchors.centerIn: parent }
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
                    width: 105; height: 28; radius: 5
                    color: "#21262d"; border.color: "#00d4ff"; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "📍"; font.pixelSize: 11 }
                        Text { text: "Follow Drone"; color: "#00d4ff"; font.pixelSize: 11; font.bold: true }
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

    // ── Quick Takeoff Altitude Dialog ──
    Dialog {
        id: takeoffPopup
        title: "Initiate Takeoff"
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            spacing: 12
            Text {
                text: "Command " + (drone ? drone.name : "drone") + " to arm and climb to:"
                color: "#8b949e"; font.pixelSize: 12
            }
            RowLayout {
                spacing: 8
                SpinBox {
                    id: altSpinBox
                    from: 2; to: 120; value: 15; stepSize: 5
                    editable: true
                    font.pixelSize: 13
                    Material.background: "#21262d"
                }
                Text { text: "Meters AGL"; color: "#e6edf3"; font.pixelSize: 12 }
            }
        }

        onAccepted: {
            if (drone) drone.takeoff(altSpinBox.value);
        }
    }

    // ── Emergency Motor Cut Confirmation Dialog ──
    Dialog {
        id: emergencyDialog
        title: "⚠️ EMERGENCY MOTOR KILL"
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: parent
        modal: true
        Material.background: "#241616"
        Material.foreground: "#ff6b6b"

        ColumnLayout {
            spacing: 10
            Text {
                text: "DANGER: This commands the flight controller to cut motors immediately!"
                color: "#ff6b6b"; font.pixelSize: 12; font.bold: true
            }
            Text {
                text: "If the drone is currently airborne, it will drop instantly. Confirm motor cut?"
                color: "#e6edf3"; font.pixelSize: 11
            }
        }

        onAccepted: {
            if (drone) drone.emergencyKill();
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

    Component.onCompleted: {
        for (var i = 0; i < droneManager.droneCount; i++) {
            var d = droneManager.droneAt(i);
            if (d) connectDroneToMap(d);
        }
    }
}
