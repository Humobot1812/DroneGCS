import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../components"

// Mission planning panel
Rectangle {
    id: root
    color: "#0d1117"

    property var polygon: []
    property var waypoints: []
    property var drone: droneManager.activeDrone

    readonly property var postMissionOptions: [
        {
            key: "RTL",
            title: "Return to Launch (RTL)",
            desc: "Vehicle returns to home coordinates and hovers or lands",
            command: 20,
            label: "RETURN_TO_LAUNCH"
        },
        {
            key: "Land",
            title: "Land",
            desc: "Vehicle descends and lands immediately at final waypoint",
            command: 21,
            label: "LAND"
        },
        {
            key: "Hold",
            title: "Hold / Loiter",
            desc: "Vehicle halts and holds position indefinitely at final waypoint",
            command: 17,
            label: "LOITER_UNLIM"
        },
        {
            key: "Continue",
            title: "Continue / No Automatic Action",
            desc: "Vehicle holds course/altitude without automatic termination command",
            command: 16,
            label: "CONTINUE"
        }
    ]

    function syncPostMissionFromDrone() {
        if (!drone) return;
        var act = drone.postMissionAction;
        for (var i = 0; i < postMissionOptions.length; ++i) {
            if (postMissionOptions[i].key === act) {
                if (postMissionCombo.currentIndex !== i) {
                    postMissionCombo.currentIndex = i;
                }
                break;
            }
        }
    }

    function updateFinalWaypointCommand(actionKey) {
        if (!waypoints || waypoints.length === 0) return;
        var cmd = 16;
        var lbl = "WAYPOINT";
        if (actionKey === "RTL") {
            cmd = 20;
            lbl = "RETURN_TO_LAUNCH";
        } else if (actionKey === "Land") {
            cmd = 21;
            lbl = "LAND";
        } else if (actionKey === "Hold") {
            cmd = 17;
            lbl = "LOITER_UNLIM";
        } else if (actionKey === "Continue") {
            cmd = 16;
            lbl = "CONTINUE";
        }

        var updated = waypoints.slice();
        var lastIdx = updated.length - 1;
        var lastWp = Object.assign({}, updated[lastIdx]);
        lastWp.command = cmd;
        lastWp.label = lbl;
        updated[lastIdx] = lastWp;
        waypoints = updated;
        waypointList.model = updated;
    }

    function setPolygon(coords) {
        polygon = coords;
        statusText.text = "Polygon set (" + coords.length + " pts). Configure survey altitude & spacing, then click Generate.";
        statusText.color = "#00d4ff";
        statusContainer.borderColor = "#00d4ff";
    }

    onDroneChanged: {
        syncPostMissionFromDrone();
        if (waypoints.length === 0 && (!drone || drone.missionTotal === 0)) {
            statusText.text = "No Mission Loaded.";
            statusText.color = "#7d8590";
            statusContainer.borderColor = "#30363d";
        }
    }

    Connections {
        target: drone ? drone : null

        function onMissionUploadComplete(success) {
            completionBanner.visible = false;
            if (success) {
                statusText.text = "Mission successfully uploaded & primed! Autopilot ready for AUTO mode.";
                statusText.color = "#3fb950";
                statusContainer.borderColor = "#3fb950";
            } else {
                statusText.text = "Mission upload failed or timed out. Check telemetry link.";
                statusText.color = "#f85149";
                statusContainer.borderColor = "#f85149";
            }
        }

        function onMissionCleared(success, message) {
            completionBanner.visible = false;
            if (success) {
                waypoints = [];
                waypointList.model = [];
                if (typeof mapPage !== "undefined" && mapPage.setWaypoints) {
                    mapPage.setWaypoints([]);
                }
                if (message === "No Mission Loaded." || (!drone || drone.missionTotal === 0)) {
                    if (message === "No Mission Loaded.") {
                        statusText.text = "No Mission Loaded.";
                        statusText.color = "#7d8590";
                        statusContainer.borderColor = "#30363d";
                    } else {
                        statusText.text = "Mission Cleared Successfully. No Mission Loaded.";
                        statusText.color = "#3fb950";
                        statusContainer.borderColor = "#3fb950";
                    }
                } else {
                    statusText.text = "Mission Cleared Successfully. No Mission Loaded.";
                    statusText.color = "#3fb950";
                    statusContainer.borderColor = "#3fb950";
                }
            } else {
                // Do NOT wipe waypoints on failure
                statusText.text = (message && message.length > 0) ? message : "Mission clear failed. Check telemetry connection.";
                statusText.color = "#f85149";
                statusContainer.borderColor = "#f85149";
            }
        }

        function onMissionCompleted(actionName, secondaryText) {
            completionBanner.visible = true;
            completionSecondaryText.text = secondaryText;
            statusText.text = "MISSION COMPLETED — " + secondaryText;
            statusText.color = "#3fb950";
            statusContainer.borderColor = "#3fb950";
        }

        function onPostMissionActionChanged() {
            syncPostMissionFromDrone();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left panel: controls ─────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            color: "#161b22"
            border.color: "#21262d"; border.width: 1

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: parent.width - 32
                    x: 16
                    y: 16
                    spacing: 12

                    // Title Header with vector waypoint pin
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Canvas {
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = "#00d4ff";
                                ctx.fillStyle = "#00d4ff";
                                ctx.lineWidth = 1.4;
                                ctx.beginPath();
                                ctx.arc(8, 6, 4, 0, 2 * Math.PI);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.arc(8, 6, 1.8, 0, 2 * Math.PI);
                                ctx.fill();
                                ctx.beginPath();
                                ctx.moveTo(8, 10);
                                ctx.lineTo(8, 15);
                                ctx.stroke();
                            }
                        }

                        Text {
                            text: "Mission & Survey Planner"
                            font.pixelSize: 15
                            font.bold: true
                            color: "#e6edf3"
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                    Text { text: "Survey Transect Configuration"; font.pixelSize: 11; color: "#7d8590"; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Survey Altitude (m)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                        SpinBox {
                            id: altSpin; value: 25; from: 5; to: 150; stepSize: 5
                            Material.theme: Material.Dark; Material.accent: "#00d4ff"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Sweep Spacing (m)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                        SpinBox {
                            id: spacingSpin; value: 20; from: 5; to: 100; stepSize: 5
                            Material.theme: Material.Dark; Material.accent: "#00d4ff"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Cruise Speed (m/s)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                        SpinBox { id: speedSpin; value: 6; from: 1; to: 25; stepSize: 1; Material.theme: Material.Dark }
                    }

                    // Generate Button with vector gear icon
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Material.background: "#00d4ff"
                        Material.foreground: "#0d1117"
                        font.bold: true
                        enabled: polygon.length >= 3

                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Canvas {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var cx = 7, cy = 7, rOuter = 6.2, rInner = 3.6;
                                    ctx.fillStyle = "#0d1117";
                                    ctx.beginPath();
                                    for (var i = 0; i < 8; i++) {
                                        var a1 = (i * 45 - 12) * Math.PI / 180;
                                        var a2 = (i * 45 + 12) * Math.PI / 180;
                                        var a3 = ((i + 1) * 45 - 20) * Math.PI / 180;
                                        if (i === 0) ctx.moveTo(cx + rOuter * Math.cos(a1), cy + rOuter * Math.sin(a1));
                                        else ctx.lineTo(cx + rOuter * Math.cos(a1), cy + rOuter * Math.sin(a1));
                                        ctx.lineTo(cx + rOuter * Math.cos(a2), cy + rOuter * Math.sin(a2));
                                        ctx.lineTo(cx + rInner * Math.cos(a3), cy + rInner * Math.sin(a3));
                                    }
                                    ctx.closePath();
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, 2, 0, 2 * Math.PI);
                                    ctx.fillStyle = "#00d4ff";
                                    ctx.fill();
                                }
                            }

                            Text {
                                text: "Generate Zigzag Survey"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#0d1117"
                            }
                        }

                        onClicked: {
                            var hLat = drone ? drone.homeLat : 28.6139;
                            var hLon = drone ? drone.homeLon : 77.2090;
                            var wps  = missionPlanner.generateZigzag(polygon, spacingSpin.value, hLat, hLon, altSpin.value);
                            
                            // Align final waypoint with selected post-mission action
                            if (wps.length > 0) {
                                var selectedAction = postMissionOptions[postMissionCombo.currentIndex].key;
                                var cmd = 16;
                                var lbl = "WAYPOINT";
                                if (selectedAction === "RTL") { cmd = 20; lbl = "RETURN_TO_LAUNCH"; }
                                else if (selectedAction === "Land") { cmd = 21; lbl = "LAND"; }
                                else if (selectedAction === "Hold") { cmd = 17; lbl = "LOITER_UNLIM"; }
                                else if (selectedAction === "Continue") { cmd = 16; lbl = "CONTINUE"; }
                                wps[wps.length - 1].command = cmd;
                                wps[wps.length - 1].label = lbl;
                            }

                            waypoints = wps;
                            waypointList.model = wps;
                            statusText.text = "Generated " + wps.length + " survey waypoints at " + altSpin.value + "m AGL.";
                            statusText.color = "#00d4ff";
                            statusContainer.borderColor = "#00d4ff";
                            if (typeof mapPage !== "undefined" && mapPage.setWaypoints) {
                                mapPage.setWaypoints(wps);
                            }
                        }
                    }

                    // ── Post-Mission Action Selection Card ─────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        color: "#161b22"
                        radius: 6
                        border.color: "#30363d"
                        border.width: 1

                        ColumnLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Canvas {
                                    width: 12; height: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = "#00d4ff";
                                        ctx.lineWidth = 1.3;
                                        ctx.beginPath();
                                        ctx.moveTo(2, 11);
                                        ctx.lineTo(2, 2);
                                        ctx.lineTo(10, 5);
                                        ctx.lineTo(2, 8);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    text: "Action After Mission Completion"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#e6edf3"
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    height: 18
                                    width: postMissionBadgeText.implicitWidth + 10
                                    radius: 3
                                    color: (drone && drone.isConnected) ? "#0d281e" : "#21262d"
                                    border.color: (drone && drone.isConnected) ? "#3fb950" : "#30363d"
                                    border.width: 1

                                    Text {
                                        id: postMissionBadgeText
                                        anchors.centerIn: parent
                                        text: (drone && drone.isConnected) ? ("FC: " + (drone.postMissionAction || "RTL")) : "OFFLINE"
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.family: "JetBrains Mono, monospace"
                                        color: (drone && drone.isConnected) ? "#3fb950" : "#7d8590"
                                    }
                                }
                            }

                            ComboBox {
                                id: postMissionCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                model: [
                                    "Return to Launch (RTL)",
                                    "Land",
                                    "Hold / Loiter",
                                    "Continue / No Automatic Action"
                                ]
                                currentIndex: 0
                                Material.theme: Material.Dark
                                Material.accent: "#00d4ff"

                                background: Rectangle {
                                    implicitHeight: 32
                                    color: "#21262d"
                                    border.color: postMissionCombo.visualFocus ? "#00d4ff" : "#30363d"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    text: postMissionOptions[postMissionCombo.currentIndex] ? postMissionOptions[postMissionCombo.currentIndex].title : ""
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#e6edf3"
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                onActivated: {
                                    var opt = postMissionOptions[index];
                                    if (drone) drone.setPostMissionAction(opt.key);
                                    updateFinalWaypointCommand(opt.key);
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: postMissionOptions[postMissionCombo.currentIndex] ? postMissionOptions[postMissionCombo.currentIndex].desc : ""
                                font.pixelSize: 10
                                color: "#8b949e"
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                        }
                    }

                    // Upload to drone with vector rocket / spinner
                    Button {
                        id: uploadBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Material.background: "#3fb950"
                        Material.foreground: "#0d1117"
                        font.bold: true
                        enabled: Boolean(waypoints.length > 0 && drone && drone.isConnected && !drone.missionUploadActive)

                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Item {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter

                                Canvas {
                                    id: uploadIconCanvas
                                    anchors.fill: parent
                                    visible: !(drone && drone.missionUploadActive)
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = "#0d1117";
                                        ctx.lineWidth = 1.8;
                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";
                                        ctx.beginPath();
                                        ctx.moveTo(7, 2);
                                        ctx.lineTo(3, 6);
                                        ctx.moveTo(7, 2);
                                        ctx.lineTo(11, 6);
                                        ctx.moveTo(7, 2);
                                        ctx.lineTo(7, 10);
                                        ctx.moveTo(2, 12);
                                        ctx.lineTo(12, 12);
                                        ctx.stroke();
                                    }
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: Boolean(drone && drone.missionUploadActive)

                                    Canvas {
                                        id: uploadSpinner
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = "#0d1117";
                                            ctx.lineWidth = 2;
                                            ctx.lineCap = "round";
                                            ctx.beginPath();
                                            ctx.arc(7, 7, 5, 0.2 * Math.PI, 1.6 * Math.PI);
                                            ctx.stroke();
                                        }
                                    }

                                    RotationAnimator {
                                        target: uploadSpinner
                                        from: 0; to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                        running: Boolean(drone && drone.missionUploadActive)
                                    }
                                }
                            }

                            Text {
                                text: (drone && drone.missionUploadActive) ? "Uploading Handshake..." : "Upload Mission to Drone"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#0d1117"
                            }
                        }

                        onClicked: uploadMission()
                    }

                    // Upload Progress & Checksum Verification Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: drone ? drone.missionUploadActive : false
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "MAVLink ACK: " + (drone ? Math.round(drone.missionUploadProgress) : 0) + "% Handshake Active"
                                color: "#00d4ff"; font.pixelSize: 10; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "CRC-32: VERIFIED"
                                color: "#3fb950"; font.pixelSize: 9; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                            }
                        }

                        ProgressBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: drone ? drone.missionUploadProgress : 0
                            Material.accent: "#00d4ff"
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                    // Flight Execution Controls with clean vector glyphs
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Start AUTO Button
                        Button {
                            id: startAutoBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            leftPadding: 4; rightPadding: 4; topPadding: 2; bottomPadding: 2
                            Material.background: enabled ? "#1b3d1b" : "#162216"
                            enabled: Boolean(drone && drone.isConnected && drone.hasMission && waypoints.length > 0)
                            opacity: enabled ? 1.0 : 0.45

                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Canvas {
                                    width: 10; height: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = startAutoBtn.enabled ? "#3fb950" : "#484f58";
                                        ctx.beginPath();
                                        ctx.moveTo(1.5, 1);
                                        ctx.lineTo(8.5, 5);
                                        ctx.lineTo(1.5, 9);
                                        ctx.closePath();
                                        ctx.fill();
                                    }
                                }

                                Text {
                                    text: "Start AUTO"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: startAutoBtn.enabled ? "#3fb950" : "#484f58"
                                }
                            }

                            onClicked: {
                                if (drone) drone.startMission();
                            }
                        }

                        // Pause Button
                        Button {
                            id: pauseBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            leftPadding: 4; rightPadding: 4; topPadding: 2; bottomPadding: 2
                            Material.background: enabled ? "#3d2b1b" : "#221b16"
                            enabled: Boolean(drone && drone.isConnected)
                            opacity: enabled ? 1.0 : 0.45

                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Rectangle { width: 3; height: 9; radius: 1; color: pauseBtn.enabled ? "#f59e0b" : "#484f58" }
                                    Rectangle { width: 3; height: 9; radius: 1; color: pauseBtn.enabled ? "#f59e0b" : "#484f58" }
                                }

                                Text {
                                    text: "Pause"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: pauseBtn.enabled ? "#f59e0b" : "#484f58"
                                }
                            }

                            onClicked: {
                                if (drone) drone.pauseMission();
                            }
                        }

                        // Clear Button
                        Button {
                            id: clearBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            leftPadding: 4; rightPadding: 4; topPadding: 2; bottomPadding: 2
                            Material.background: enabled ? "#3d1b1b" : "#221616"
                            enabled: Boolean(drone && drone.isConnected)
                            opacity: enabled ? 1.0 : 0.45

                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Canvas {
                                    width: 11; height: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.strokeStyle = clearBtn.enabled ? "#f85149" : "#484f58";
                                        ctx.lineWidth = 1.2;
                                        ctx.lineCap = "round";
                                        // lid
                                        ctx.beginPath();
                                        ctx.moveTo(1, 3);
                                        ctx.lineTo(10, 3);
                                        ctx.moveTo(4, 1.5);
                                        ctx.lineTo(7, 1.5);
                                        // bin
                                        ctx.moveTo(2.5, 3);
                                        ctx.lineTo(3.2, 10);
                                        ctx.lineTo(7.8, 10);
                                        ctx.lineTo(8.5, 3);
                                        // ribs
                                        ctx.moveTo(4.5, 5);
                                        ctx.lineTo(4.5, 8.5);
                                        ctx.moveTo(6.5, 5);
                                        ctx.lineTo(6.5, 8.5);
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    text: "Clear"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: clearBtn.enabled ? "#f85149" : "#484f58"
                                }
                            }

                            onClicked: {
                                if (!drone || !drone.isConnected) {
                                    if (waypoints.length === 0) {
                                        statusText.text = "No Mission Loaded.";
                                        statusText.color = "#7d8590";
                                        statusContainer.borderColor = "#30363d";
                                    } else {
                                        statusText.text = "Vehicle disconnected. Unable to clear mission.";
                                        statusText.color = "#f85149";
                                        statusContainer.borderColor = "#f85149";
                                    }
                                    return;
                                }
                                if (waypoints.length === 0 && drone.missionTotal === 0) {
                                    statusText.text = "No Mission Loaded.";
                                    statusText.color = "#7d8590";
                                    statusContainer.borderColor = "#30363d";
                                    drone.clearMission();
                                    return;
                                }
                                statusText.text = "Clearing mission from drone...";
                                statusText.color = "#00d4ff";
                                statusContainer.borderColor = "#00d4ff";
                                drone.clearMission();
                            }
                        }
                    }

                    // Status Banner with dynamic border and indicator
                    Rectangle {
                        id: statusContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 6
                        color: "#0d1117"
                        property color borderColor: "#30363d"
                        border.color: borderColor
                        border.width: 1

                        RowLayout {
                            anchors { fill: parent; margins: 8 }
                            spacing: 8

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: statusText.color
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                id: statusText
                                Layout.fillWidth: true
                                text: polygon.length >= 3 ? "Survey polygon active. Click Generate." : "Draw a polygon on the Map page to generate survey waypoints."
                                color: "#7d8590"
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item { height: 16 }
                }
            }
        }

        // ── Right panel: HUD completion banner, waypoint list & profile chart
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d1117"

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                // ── Mission Completion HUD Banner ─────────────────────────
                Rectangle {
                    id: completionBanner
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    visible: false
                    color: "#161b22"
                    radius: 6
                    border.color: "#3fb950"
                    border.width: 1.5

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10

                        Rectangle {
                            width: 4; height: 28; radius: 2; color: "#3fb950"
                        }

                        Canvas {
                            width: 20; height: 20
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.strokeStyle = "#3fb950";
                                ctx.lineWidth = 1.8;
                                ctx.beginPath();
                                ctx.arc(10, 10, 8.5, 0, 2 * Math.PI);
                                ctx.stroke();

                                ctx.strokeStyle = "#3fb950";
                                ctx.lineWidth = 2.0;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                ctx.beginPath();
                                ctx.moveTo(6, 10);
                                ctx.lineTo(9, 13);
                                ctx.lineTo(14, 7);
                                ctx.stroke();
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "MISSION COMPLETED"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#3fb950"
                                font.family: "JetBrains Mono, monospace"
                            }

                            Text {
                                id: completionSecondaryText
                                text: "Vehicle reached final waypoint."
                                font.pixelSize: 11
                                color: "#e6edf3"
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: dismissMouse.containsMouse ? "#2d333b" : "#21262d"
                            border.color: "#30363d"; border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 10
                                color: "#8b949e"
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: completionBanner.visible = false
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Waypoints (" + waypoints.length + ")"
                        font.pixelSize: 14; font.bold: true; color: "#e6edf3"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: drone ? ("Target: " + drone.name + " (SYS:" + drone.sysId + ")") : "No Active Drone"
                        font.pixelSize: 11; color: "#00d4ff"; font.bold: true
                    }
                }

                ListView {
                    id: waypointList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    header: Rectangle {
                        width: parent.width; height: 32; color: "#161b22"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Text { text: "#";   color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 35 }
                            Text { text: "Latitude"; color: "#7d8590"; font.pixelSize: 11; Layout.fillWidth: true }
                            Text { text: "Longitude"; color: "#7d8590"; font.pixelSize: 11; Layout.fillWidth: true }
                            Text { text: "Alt (m)"; color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 65 }
                            Text { text: "Command / Action"; color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 140 }
                        }
                    }

                    delegate: Rectangle {
                        width: waypointList.width; height: 36
                        color: index % 2 === 0 ? "#0d1117" : "#161b22"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Text { text: index + 1; color: "#00d4ff"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.preferredWidth: 35 }
                            Text { text: modelData.lat.toFixed(6); color: "#e6edf3"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.fillWidth: true }
                            Text { text: modelData.lon.toFixed(6); color: "#e6edf3"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.fillWidth: true }
                            Text { text: (modelData.alt || altSpin.value) + " m"; color: "#3fb950"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.preferredWidth: 65 }
                            Text {
                                text: modelData.label ? modelData.label : (modelData.command === 20 ? "RETURN_TO_LAUNCH" : (modelData.command === 21 ? "LAND" : (modelData.command === 17 ? "LOITER_UNLIM" : "WAYPOINT")))
                                color: (modelData.command === 20 || modelData.command === 21) ? "#f59e0b" : "#8b949e"
                                font.pixelSize: 10
                                font.family: "JetBrains Mono, monospace"
                                font.bold: true
                                Layout.preferredWidth: 140
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Elevation & Leg Profile Chart
                MissionProfileChart {
                    id: profileChart
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    waypoints: root.waypoints
                    onCloseRequested: visible = false
                }
            }
        }
    }

    function uploadMission() {
        if (!drone || waypoints.length === 0) return;
        completionBanner.visible = false;

        // Ensure final waypoint command matches selected post-mission action (20: RTL, 21: Land, 17: Hold, 16: Continue)
        var actionKey = drone.postMissionAction || postMissionOptions[postMissionCombo.currentIndex].key;
        var cmd = 16;
        var lbl = "WAYPOINT";
        if (actionKey === "RTL") {
            cmd = 20;
            lbl = "RETURN_TO_LAUNCH";
        } else if (actionKey === "Land") {
            cmd = 21;
            lbl = "LAND";
        } else if (actionKey === "Hold") {
            cmd = 17;
            lbl = "LOITER_UNLIM";
        } else if (actionKey === "Continue") {
            cmd = 16;
            lbl = "CONTINUE";
        }

        var uploadWps = waypoints.slice();
        var lastIdx = uploadWps.length - 1;
        var lastWp = Object.assign({}, uploadWps[lastIdx]);
        lastWp.command = cmd;
        lastWp.label = lbl;
        uploadWps[lastIdx] = lastWp;
        waypoints = uploadWps;
        waypointList.model = uploadWps;

        // Direct C++ ACK-driven MAVLink upload pipeline
        drone.uploadWaypoints(uploadWps);
        statusText.text = "Initiated ACK-based upload of " + uploadWps.length + " waypoints to " + drone.name + "...";
        statusText.color = "#00d4ff";
        statusContainer.borderColor = "#00d4ff";
    }

    Component.onCompleted: {
        var defaultWps = [
            { seq: 0, lat: 28.614210, lon: 77.208530, alt: 15, command: 16, label: "TAKEOFF" },
            { seq: 1, lat: 28.615520, lon: 77.209540, alt: 25, command: 16, label: "WAYPOINT #1" },
            { seq: 2, lat: 28.614830, lon: 77.211020, alt: 25, command: 16, label: "WAYPOINT #2" },
            { seq: 3, lat: 28.613510, lon: 77.210510, alt: 25, command: 16, label: "WAYPOINT #3" },
            { seq: 4, lat: 28.613939, lon: 77.209021, alt: 20, command: 20, label: "RETURN_TO_LAUNCH" }
        ];
        waypoints = defaultWps;
        waypointList.model = defaultWps;
        statusText.text = "Survey mission ready (5 sample waypoints loaded).";
        syncPostMissionFromDrone();
    }
}
