import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import "../components"

// Primary Flight Display (PFD) with Command Deck & Flight Mode Controller
Rectangle {
    id: root
    color: "#0d1117"

    property var drone: droneManager.activeDrone

    // ── No drone connected placeholder ──────────────────────────────────────
    Column {
        visible: !drone || !drone.isConnected
        anchors.centerIn: parent
        spacing: 16
        Text { text: "✈"; font.pixelSize: 64; color: "#30363d"; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: "No drone connected"; font.pixelSize: 20; color: "#7d8590"; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: "Press Ctrl+N to connect or enable Demo simulation"; font.pixelSize: 13; color: "#30363d"; anchors.horizontalCenter: parent.horizontalCenter }
    }

    // ── Main PFD layout ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: drone && drone.isConnected

        // Top Header: Active Drone Identifier & Mode Strip
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#161b22"
            border.color: "#21262d"; border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                // Drone color dot
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: drone ? drone.color : "#00d4ff"
                }

                // Drone name + vehicle type
                Column {
                    spacing: 0
                    Text {
                        text: drone ? drone.name : "Vehicle"
                        color: "#e6edf3"; font.pixelSize: 12; font.bold: true
                    }
                    Text {
                        text: drone && drone.vehicleType !== "" ? drone.vehicleType : "Unknown Vehicle"
                        color: "#7d8590"; font.pixelSize: 9
                        font.family: "JetBrains Mono, monospace"
                    }
                }

                Rectangle { width: 1; height: 24; color: "#30363d" }

                // Vehicle type icon (emoji for quick ID)
                Text {
                    font.pixelSize: 18
                    text: {
                        if (!drone || drone.vehicleType === "") return "✈";
                        var vt = drone.vehicleType;
                        if (vt === "Quadrotor")   return "🔲";
                        if (vt === "Hexarotor")   return "⬡";
                        if (vt === "Octorotor")   return "⭘";
                        if (vt === "Tricopter")   return "△";
                        if (vt === "Fixed Wing")  return "✈";
                        if (vt === "Helicopter")  return "🚁";
                        if (vt === "Rover")       return "🚗";
                        if (vt === "Boat")        return "🚤";
                        if (vt.startsWith("VTOL")) return "🛩";
                        return "✈";
                    }
                }

                Rectangle { width: 1; height: 24; color: "#30363d" }

                Text {
                    text: "SYS: " + (drone ? drone.sysId : "—")
                    color: "#8b949e"; font.pixelSize: 10
                    font.family: "JetBrains Mono, monospace"
                }

                Item { Layout.fillWidth: true }

                // ── Autopilot Logo Badge ──────────────────────────────────────
                Rectangle {
                    id: apBadge
                    height: 26; radius: 5
                    width: apBadgeRow.width + 16
                    visible: drone && drone.autopilotType !== ""

                    // ArduPilot = orange-red tint, PX4 = purple, others = grey
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
                        spacing: 5

                        // Autopilot logo mark
                        Canvas {
                            width: 16; height: 16
                            property string apType: drone ? drone.autopilotType : ""
                            onApTypeChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (apType === "ArduPilot") {
                                    // ArduPilot: stylized "A" in orange
                                    ctx.strokeStyle = "#e05a1d";
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    ctx.moveTo(8, 2); ctx.lineTo(2, 14); ctx.moveTo(8, 2); ctx.lineTo(14, 14);
                                    ctx.moveTo(5, 9); ctx.lineTo(11, 9);
                                    ctx.stroke();
                                } else if (apType === "PX4") {
                                    // PX4: stylized "X" in purple
                                    ctx.strokeStyle = "#6e40c9";
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    ctx.moveTo(3, 3); ctx.lineTo(13, 13);
                                    ctx.moveTo(13, 3); ctx.lineTo(3, 13);
                                    ctx.stroke();
                                } else {
                                    // Generic gear icon
                                    ctx.strokeStyle = "#7d8590";
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    ctx.arc(8, 8, 4, 0, Math.PI * 2);
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
                            font.pixelSize: 10; font.bold: true
                            font.family: "JetBrains Mono, monospace"
                        }
                    }
                }

                // Armed / Disarmed Badge
                Rectangle {
                    height: 26; width: 82; radius: 4
                    color: drone && drone.isArmed ? "#3d1b1b" : "#1b3d1b"
                    border.color: drone && drone.isArmed ? "#f85149" : "#3fb950"; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                        }
                        Text {
                            text: drone && drone.isArmed ? "ARMED" : "DISARMED"
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            font.pixelSize: 10; font.bold: true
                        }
                    }
                }

                // Flight Mode Pill
                Rectangle {
                    height: 26; width: modeText.width + 18; radius: 4
                    color: "#1b222c"; border.color: "#00d4ff40"; border.width: 1
                    Text {
                        id: modeText
                        anchors.centerIn: parent
                        text: "MODE: " + (drone ? drone.flightMode : "—")
                        color: "#00d4ff"; font.pixelSize: 10; font.bold: true
                        font.family: "JetBrains Mono, monospace"
                    }
                }
            }
        }

        // Mid row: Attitude + flanking gauges
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Speed tape (left)
            SpeedAltGauge {
                value:  drone ? drone.airSpeed : 0
                range:  30
                unit:   "m/s"
                label:  "IAS"
                accentColor: "#00d4ff"
                Layout.alignment: Qt.AlignVCenter
            }

            // Center: Attitude Indicator + Compass
            Column {
                Layout.fillWidth: true
                spacing: 10

                AttitudeIndicator {
                    id: ai
                    roll:  drone ? drone.roll  : 0
                    pitch: drone ? drone.pitch : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 300)
                    height: width
                }

                CompassRose {
                    heading: drone ? drone.headingDeg : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Altitude tape (right)
            SpeedAltGauge {
                value:  drone ? drone.relAltitude : 0
                range:  60
                unit:   "m"
                label:  "ALT"
                accentColor: "#3fb950"
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Flight Control Deck & Action Bar
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#161b22"; radius: 8
            border.color: "#21262d"; border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10

                // Flight Mode Selector
                Row {
                    spacing: 8; Layout.alignment: Qt.AlignVCenter
                    Text { text: "MODE:"; color: "#8b949e"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

                    ComboBox {
                        id: modeSelector
                        width: 145; height: 34
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

                Rectangle { width: 1; height: 26; color: "#30363d" }

                // Arm / Disarm Toggle Button
                Button {
                    text: drone && drone.isArmed ? "⬛ DISARM" : "▲ ARM"
                    Layout.preferredHeight: 34
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
                    Layout.preferredHeight: 34
                    font.bold: true; font.pixelSize: 11
                    Material.background: "#21262d"
                    contentItem: Text {
                        text: parent.text; color: "#00d4ff"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: dashTakeoffDialog.open()
                }

                // Land Button
                Button {
                    text: "🛬 LAND"
                    Layout.preferredHeight: 34
                    font.bold: true; font.pixelSize: 11
                    Material.background: "#21262d"
                    contentItem: Text {
                        text: parent.text; color: "#d29922"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: if (drone) drone.land()
                }

                // Return To Launch Button
                Button {
                    text: "🏠 RTL"
                    Layout.preferredHeight: 34
                    font.bold: true; font.pixelSize: 11
                    Material.background: "#21262d"
                    contentItem: Text {
                        text: parent.text; color: "#3fb950"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: if (drone) drone.returnToLaunch()
                }

                Item { Layout.fillWidth: true }

                // Emergency Kill / Cut Motors
                Button {
                    text: "⛔ EMERGENCY KILL"
                    Layout.preferredHeight: 34
                    font.bold: true; font.pixelSize: 11
                    Material.background: "#441b1b"
                    contentItem: Text {
                        text: parent.text; color: "#ff6b6b"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: emergencyDialog.open()
                }
            }
        }

        // Bottom row: High-Tech Telemetry Cards with Gauges
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // 1. Ground Speed Card
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 8
                color: "#161b22"; border.color: "#21262d"; border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 4
                    Row {
                        spacing: 6
                        Text { text: "⚡"; font.pixelSize: 13 }
                        Text { text: "Ground Speed"; font.pixelSize: 10; color: "#8b949e" }
                    }
                    Text {
                        text: drone ? drone.groundSpeed.toFixed(1) + " m/s" : "—"
                        font.pixelSize: 15; font.bold: true; font.family: "JetBrains Mono, monospace"
                        color: "#00d4ff"
                    }
                    Text {
                        text: "IAS: " + (drone ? drone.airSpeed.toFixed(1) + " m/s" : "—")
                        font.pixelSize: 9; color: "#7d8590"; font.family: "JetBrains Mono, monospace"
                    }
                }
            }

            // 2. Climb Rate Card
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 8
                color: "#161b22"; border.color: "#21262d"; border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 4
                    Row {
                        spacing: 6
                        Text { text: "📈"; font.pixelSize: 13 }
                        Text { text: "Climb Rate"; font.pixelSize: 10; color: "#8b949e" }
                    }
                    Text {
                        text: drone ? ((drone.climbRate >= 0 ? "↑ +" : "↓ ") + drone.climbRate.toFixed(1) + " m/s") : "—"
                        font.pixelSize: 15; font.bold: true; font.family: "JetBrains Mono, monospace"
                        color: drone && drone.climbRate >= 0 ? "#3fb950" : "#d29922"
                    }
                    Text {
                        text: "Rel Alt: " + (drone ? drone.relAltitude.toFixed(1) + " m" : "—")
                        font.pixelSize: 9; color: "#7d8590"; font.family: "JetBrains Mono, monospace"
                    }
                }
            }

            // 3. GPS Sats & Signal Health Card
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 8
                color: "#161b22"; border.color: "#21262d"; border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 4
                    Row {
                        spacing: 6
                        Text { text: "🛰"; font.pixelSize: 13 }
                        Text { text: "GPS Positioning"; font.pixelSize: 10; color: "#8b949e" }
                    }
                    Text {
                        text: drone ? drone.gpsSats + " Sats · 3D Fix" : "—"
                        font.pixelSize: 14; font.bold: true; font.family: "JetBrains Mono, monospace"
                        color: "#e6edf3"
                    }
                    Row {
                        spacing: 6
                        Text {
                            text: "HDOP: " + (drone ? drone.gpsHDOP.toFixed(1) : "—")
                            font.pixelSize: 9; color: "#3fb950"; font.family: "JetBrains Mono, monospace"
                        }
                        Text {
                            text: "• EXCELLENT"
                            font.pixelSize: 9; color: "#7d8590"; font.bold: true
                        }
                    }
                }
            }

            // 4. Battery Level & Voltage Card
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 8
                color: "#161b22"; border.color: "#21262d"; border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 4
                    Row {
                        spacing: 6
                        Text { text: "🔋"; font.pixelSize: 13 }
                        Text { text: "Power State"; font.pixelSize: 10; color: "#8b949e" }
                    }
                    Row {
                        spacing: 8
                        Text {
                            text: drone ? drone.batteryPercent + "%" : "—"
                            font.pixelSize: 15; font.bold: true; font.family: "JetBrains Mono, monospace"
                            color: drone && drone.batteryPercent > 30 ? "#3fb950" : "#f85149"
                        }
                        Text {
                            text: drone ? drone.batteryVoltage.toFixed(2) + " V" : "—"
                            font.pixelSize: 12; font.family: "JetBrains Mono, monospace"
                            color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    // Mini Battery Level Progress Bar
                    Rectangle {
                        width: parent.width; height: 5; radius: 2.5
                        color: "#21262d"
                        Rectangle {
                            width: drone ? parent.width * Math.min(1.0, Math.max(0.0, drone.batteryPercent / 100.0)) : 0
                            height: parent.height; radius: parent.radius
                            color: drone && drone.batteryPercent > 50 ? "#3fb950" : (drone && drone.batteryPercent > 25 ? "#f59e0b" : "#f85149")
                        }
                    }
                }
            }

            // 5. Geographic Position Card
            Rectangle {
                Layout.fillWidth: true; height: 72; radius: 8
                color: "#161b22"; border.color: "#21262d"; border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 3
                    Row {
                        spacing: 6
                        Text { text: "📍"; font.pixelSize: 13 }
                        Text { text: "Coordinates"; font.pixelSize: 10; color: "#8b949e" }
                    }
                    Text {
                        text: drone ? drone.latitude.toFixed(6) : "—"
                        font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; color: "#e6edf3"
                    }
                    Text {
                        text: drone ? drone.longitude.toFixed(6) : "—"
                        font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; color: "#e6edf3"
                    }
                }
            }
        }

        // Status text ticker banner
        Rectangle {
            Layout.fillWidth: true
            height: 28; color: "#161b22"; radius: 6
            border.color: "#21262d"; border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: "#d29922"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
                Text {
                    text: "MAVLINK: " + (drone ? drone.lastStatusText : "System Ready — Standby")
                    color: "#d29922"; font.pixelSize: 11
                    font.family: "JetBrains Mono, monospace"
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
            }
        }
    }

    // ── Takeoff Dialog ──
    Dialog {
        id: dashTakeoffDialog
        title: "Initiate Takeoff"
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            spacing: 12
            Text {
                text: "Select target climb altitude:"
                color: "#8b949e"; font.pixelSize: 12
            }
            RowLayout {
                spacing: 6
                Repeater {
                    model: [5, 10, 15, 25, 50]
                    Button {
                        text: modelData + "m"
                        Layout.preferredHeight: 30
                        Material.background: dashAltSpinBox.value === modelData ? "#00d4ff30" : "#21262d"
                        contentItem: Text { text: parent.text; color: "#00d4ff"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
                        onClicked: dashAltSpinBox.value = modelData
                    }
                }
            }
            RowLayout {
                spacing: 8
                SpinBox {
                    id: dashAltSpinBox
                    from: 2; to: 150; value: 15; stepSize: 5
                    editable: true
                    font.pixelSize: 13
                    Material.background: "#21262d"
                }
                Text { text: "Meters AGL"; color: "#e6edf3"; font.pixelSize: 12 }
            }
        }

        onAccepted: {
            if (drone) drone.takeoff(dashAltSpinBox.value);
        }
    }

    // ── Emergency Confirmation Dialog ──
    Dialog {
        id: emergencyDialog
        title: "⚠️ EMERGENCY MOTOR STOP"
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: parent
        modal: true
        Material.background: "#241616"
        Material.foreground: "#ff6b6b"

        ColumnLayout {
            spacing: 10
            Text {
                text: "DANGER: This cuts motor power immediately!"
                color: "#ff6b6b"; font.pixelSize: 12; font.bold: true
            }
            Text {
                text: "The aircraft will drop if currently airborne. Confirm motor cut?"
                color: "#e6edf3"; font.pixelSize: 11
            }
        }

        onAccepted: {
            if (drone) drone.emergencyKill();
        }
    }
}
