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
        Text {
            text: "◈"
            font.pixelSize: 48
            color: "#30363d"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "No Drone Connected"
            font.pixelSize: 15
            font.bold: true
            color: "#8b949e"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "Click '+' in the top bar to connect to an autopilot"
            font.pixelSize: 12
            color: "#484f58"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── Main PFD layout ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        visible: drone && drone.isConnected

        // Top Header: Active Drone Identifier & Mode Strip
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 6
            color: "#161b22"
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Drone color dot
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: drone ? drone.color : "#00d4ff"
                }

                // Drone name + vehicle type
                Column {
                    spacing: 1
                    Text {
                        text: drone ? drone.name : "Vehicle"
                        color: "#e6edf3"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: drone && drone.vehicleType !== "" ? drone.vehicleType : "Unknown Vehicle"
                        color: "#7d8590"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                    }
                }

                Rectangle { width: 1; height: 20; color: "#30363d" }

                Text {
                    text: "SYS " + (drone ? drone.sysId : "—")
                    color: "#8b949e"
                    font.pixelSize: 11
                    font.family: "JetBrains Mono, monospace"
                }

                Item { Layout.fillWidth: true }

                // ── Autopilot Logo Badge ──────────────────────────────────────
                Rectangle {
                    id: apBadge
                    height: 24
                    radius: 4
                    width: apBadgeRow.width + 14
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
                        spacing: 5

                        Canvas {
                            width: 14
                            height: 14
                            property string apType: drone ? drone.autopilotType : ""
                            onApTypeChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (apType === "ArduPilot") {
                                    ctx.strokeStyle = "#e05a1d";
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    ctx.moveTo(7, 2); ctx.lineTo(2, 12); ctx.moveTo(7, 2); ctx.lineTo(12, 12);
                                    ctx.moveTo(4, 8); ctx.lineTo(10, 8);
                                    ctx.stroke();
                                } else if (apType === "PX4") {
                                    ctx.strokeStyle = "#6e40c9";
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    ctx.moveTo(3, 3); ctx.lineTo(11, 11);
                                    ctx.moveTo(11, 3); ctx.lineTo(3, 11);
                                    ctx.stroke();
                                } else {
                                    ctx.strokeStyle = "#7d8590";
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    ctx.arc(7, 7, 3.5, 0, Math.PI * 2);
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
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "JetBrains Mono, monospace"
                        }
                    }
                }

                // Armed / Disarmed Badge
                Rectangle {
                    height: 24
                    width: 78
                    radius: 4
                    color: drone && drone.isArmed ? "#3d1b1b" : "#1b3d1b"
                    border.color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                        }
                        Text {
                            text: drone && drone.isArmed ? "ARMED" : "DISARMED"
                            color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                // Flight Mode Pill
                Rectangle {
                    height: 24
                    width: modeText.width + 16
                    radius: 4
                    color: "#1b222c"
                    border.color: "#00d4ff40"
                    border.width: 1
                    Text {
                        id: modeText
                        anchors.centerIn: parent
                        text: "MODE: " + (drone ? drone.flightMode : "—")
                        color: "#00d4ff"
                        font.pixelSize: 10
                        font.bold: true
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
            height: 48
            color: "#161b22"
            radius: 6
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Flight Mode Selector
                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        text: "MODE"
                        color: "#8b949e"
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ComboBox {
                        id: modeSelector
                        width: 135
                        height: 32
                        model: ["GUIDED", "AUTO", "LOITER", "STABILIZE", "ALT_HOLD", "RTL", "LAND", "BRAKE", "POSHOLD"]
                        currentIndex: {
                            if (!drone) return 0;
                            var idx = model.indexOf(drone.flightMode);
                            return idx >= 0 ? idx : 0;
                        }
                        font.pixelSize: 11
                        font.bold: true
                        Material.background: "#21262d"
                        Material.foreground: "#00d4ff"

                        onActivated: function(index) {
                            if (drone) drone.setFlightMode(currentText);
                        }
                    }
                }

                Rectangle { width: 1; height: 22; color: "#30363d" }

                // Arm / Disarm Toggle Button
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
                            if (drone.isArmed) drone.disarm();
                            else drone.arm();
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
                    onClicked: dashTakeoffDialog.open()
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
                    onClicked: if (drone) drone.land()
                }

                // Return To Launch Button
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
                    onClicked: if (drone) drone.returnToLaunch()
                }

                Item { Layout.fillWidth: true }

                // Emergency Kill / Cut Motors — isolated with explicit danger styling
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

        // Bottom row: High-Tech Telemetry Cards
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // 1. Ground Speed Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#161b22"
                border.color: "#21262d"
                border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 3
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 28; height: 16; radius: 3; color: "#00d4ff18"
                            Text { text: "GND"; font.pixelSize: 9; font.bold: true; color: "#00d4ff"; anchors.centerIn: parent }
                        }
                        Text { text: "Ground Speed"; font.pixelSize: 11; color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: drone ? drone.groundSpeed.toFixed(1) + " m/s" : "—"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "JetBrains Mono, monospace"
                        color: "#00d4ff"
                    }
                    Text {
                        text: "IAS: " + (drone ? drone.airSpeed.toFixed(1) + " m/s" : "—")
                        font.pixelSize: 10
                        color: "#7d8590"
                        font.family: "JetBrains Mono, monospace"
                    }
                }
            }

            // 2. Climb Rate Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#161b22"
                border.color: "#21262d"
                border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 3
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 28; height: 16; radius: 3; color: "#3fb95018"
                            Text { text: "CLB"; font.pixelSize: 9; font.bold: true; color: "#3fb950"; anchors.centerIn: parent }
                        }
                        Text { text: "Climb Rate"; font.pixelSize: 11; color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: drone ? ((drone.climbRate >= 0 ? "↑ +" : "↓ ") + drone.climbRate.toFixed(1) + " m/s") : "—"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "JetBrains Mono, monospace"
                        color: drone && drone.climbRate >= 0 ? "#3fb950" : "#d29922"
                    }
                    Text {
                        text: "Rel Alt: " + (drone ? drone.relAltitude.toFixed(1) + " m" : "—")
                        font.pixelSize: 10
                        color: "#7d8590"
                        font.family: "JetBrains Mono, monospace"
                    }
                }
            }

            // 3. GPS Positioning Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#161b22"
                border.color: "#21262d"
                border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 3
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 28; height: 16; radius: 3; color: "#30363d"
                            Text { text: "GPS"; font.pixelSize: 9; font.bold: true; color: "#e6edf3"; anchors.centerIn: parent }
                        }
                        Text { text: "Positioning"; font.pixelSize: 11; color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: drone ? drone.gpsSats + " Sats · 3D Fix" : "—"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrains Mono, monospace"
                        color: "#e6edf3"
                    }
                    Row {
                        spacing: 6
                        Text {
                            text: "HDOP: " + (drone ? drone.gpsHDOP.toFixed(1) : "—")
                            font.pixelSize: 10
                            color: "#3fb950"
                            font.family: "JetBrains Mono, monospace"
                        }
                        Text {
                            text: "• OK"
                            font.pixelSize: 10
                            color: "#7d8590"
                            font.bold: true
                        }
                    }
                }
            }

            // 4. Power State Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#161b22"
                border.color: "#21262d"
                border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 3
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 28; height: 16; radius: 3; color: "#d2992218"
                            Text { text: "BAT"; font.pixelSize: 9; font.bold: true; color: "#d29922"; anchors.centerIn: parent }
                        }
                        Text { text: "Power State"; font.pixelSize: 11; color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 8
                        Text {
                            text: drone ? drone.batteryPercent + "%" : "—"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "JetBrains Mono, monospace"
                            color: drone && drone.batteryPercent > 30 ? "#3fb950" : "#f85149"
                        }
                        Text {
                            text: drone ? drone.batteryVoltage.toFixed(2) + " V" : "—"
                            font.pixelSize: 11
                            font.family: "JetBrains Mono, monospace"
                            color: "#8b949e"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    // Mini Battery Level Progress Bar
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: "#21262d"
                        Rectangle {
                            width: drone ? parent.width * Math.min(1.0, Math.max(0.0, drone.batteryPercent / 100.0)) : 0
                            height: parent.height
                            radius: parent.radius
                            color: drone && drone.batteryPercent > 50 ? "#3fb950" : (drone && drone.batteryPercent > 25 ? "#f59e0b" : "#f85149")
                        }
                    }
                }
            }

            // 5. Geographic Position Card
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 6
                color: "#161b22"
                border.color: "#21262d"
                border.width: 1

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                    spacing: 2
                    Row {
                        spacing: 6
                        Rectangle {
                            width: 28; height: 16; radius: 3; color: "#30363d"
                            Text { text: "POS"; font.pixelSize: 9; font.bold: true; color: "#8b949e"; anchors.centerIn: parent }
                        }
                        Text { text: "Coordinates"; font.pixelSize: 11; color: "#8b949e"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: drone ? drone.latitude.toFixed(6) : "—"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: "#e6edf3"
                    }
                    Text {
                        text: drone ? drone.longitude.toFixed(6) : "—"
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: "#e6edf3"
                    }
                }
            }
        }

        // Status text ticker banner
        Rectangle {
            Layout.fillWidth: true
            height: 26
            color: "#161b22"
            radius: 5
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#00d4ff"
                }

                Text {
                    text: drone ? (drone.lastStatusText !== "" ? drone.lastStatusText : "System Ready — Standby") : "System Ready — Standby"
                    color: "#8b949e"
                    font.pixelSize: 11
                    font.family: "JetBrains Mono, monospace"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
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
                color: "#8b949e"
                font.pixelSize: 12
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
        title: "EMERGENCY MOTOR CUT"
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: parent
        modal: true
        Material.background: "#241616"
        Material.foreground: "#ff6b6b"

        ColumnLayout {
            spacing: 10
            Text {
                text: "DANGER: This cuts motor power immediately!"
                color: "#ff6b6b"
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                text: "The aircraft will drop if currently airborne. Confirm motor cut?"
                color: "#e6edf3"
                font.pixelSize: 11
            }
        }

        onAccepted: {
            if (drone) drone.emergencyKill();
        }
    }
}
