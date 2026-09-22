import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// GeofenceConsole — Tactical QGroundControl-Style Geofence Subsystem Drawer
Rectangle {
    id: root
    width: 340
    color: "#161b22"
    border.color: "#30363d"
    border.width: 1
    radius: 8

    property var drone: droneManager.activeDrone
    signal drawKeepInRequested()
    signal drawKeepOutRequested()
    signal clearMapFenceRequested()
    signal closeRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "🛡️ Geofence Safety Console"
                font.pixelSize: 13; font.bold: true; color: "#e6edf3"
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 24; height: 24; radius: 12; color: "#21262d"
                Text { text: "✕"; color: "#8b949e"; font.pixelSize: 11; anchors.centerIn: parent }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // Real-time breach status banner
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 5
            visible: drone && drone.geofenceBreached
            color: "#441b1b"
            border.color: "#ff6b6b"
            border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 8
                Text {
                    text: "🚨 BREACH: " + (drone ? drone.geofenceBreachReason : "")
                    font.pixelSize: 10; font.bold: true; color: "#ff6b6b"
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Button {
                    text: "🏠 RTL"
                    Layout.preferredHeight: 24
                    font.pixelSize: 10; font.bold: true
                    Material.background: "#ff6b6b"
                    Material.foreground: "#ffffff"
                    onClicked: if (drone) drone.returnToLaunch()
                }
            }
        }

        // Master Geofence Switch
        RowLayout {
            Layout.fillWidth: true
            Column {
                Layout.fillWidth: true
                Text { text: "Master Geofence Protection"; font.pixelSize: 12; font.bold: true; color: "#e6edf3" }
                Text { text: "MAVLink FENCE_ENABLE onboard guard"; font.pixelSize: 10; color: "#7d8590" }
            }
            Switch {
                id: masterSwitch
                checked: drone ? drone.geofenceEnabled : false
                onToggled: {
                    if (drone) drone.setGeofenceEnabled(checked);
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // Breach Action Selector
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { text: "Action on Breach (FENCE_ACTION):"; font.pixelSize: 11; font.bold: true; color: "#8b949e" }
            ComboBox {
                id: actionCombo
                Layout.fillWidth: true
                model: ["⚠️ Warning Only (GCS-Alert)", "🏠 Return to Launch (RTL)", "🛬 Land Immediately", "⏸ Loiter / Hold Position"]
                currentIndex: drone ? drone.geofenceAction : 1
                onActivated: {
                    if (drone) drone.setGeofenceAction(index);
                }
            }
        }

        // Circular Radius Boundary On/Off Switch & Value
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Column {
                    Layout.fillWidth: true
                    Text { text: "Circular Distance Geofence"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                    Text { text: "Enable circular perimeter around Home"; font.pixelSize: 9; color: "#7d8590" }
                }
                Switch {
                    id: circleFenceSwitch
                    checked: drone ? drone.circularFenceEnabled : false
                    onToggled: {
                        if (drone) drone.setCircularFenceEnabled(checked);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: circleFenceSwitch.checked
                Text { text: "Radius Limit (m):"; font.pixelSize: 10; color: "#8b949e"; Layout.fillWidth: true }
                SpinBox {
                    id: radiusSpin
                    from: 50; to: 5000; stepSize: 50
                    value: drone ? Math.round(drone.geofenceRadius) : 300
                    editable: true
                    onValueModified: if (drone) drone.setGeofenceRadius(value)
                }
            }
        }

        // Max Altitude Ceiling
        RowLayout {
            Layout.fillWidth: true
            Column {
                Layout.fillWidth: true
                Text { text: "Altitude Ceiling (m AGL)"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                Text { text: "Max permissible flight level"; font.pixelSize: 9; color: "#7d8590" }
            }
            SpinBox {
                id: maxAltSpin
                from: 10; to: 500; stepSize: 10
                value: drone ? Math.round(drone.geofenceMaxAlt) : 120
                editable: true
                onValueModified: if (drone) drone.setGeofenceMaxAlt(value)
            }
        }

        // Min Altitude Floor
        RowLayout {
            Layout.fillWidth: true
            Column {
                Layout.fillWidth: true
                Text { text: "Altitude Floor (m AGL)"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                Text { text: "Minimum ground clearance limit"; font.pixelSize: 9; color: "#7d8590" }
            }
            SpinBox {
                id: minAltSpin
                from: 0; to: 50; stepSize: 1
                value: drone ? Math.round(drone.geofenceMinAlt) : 2
                editable: true
                onValueModified: if (drone) drone.setGeofenceMinAlt(value)
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // Inclusion / Exclusion Polygon Controls
        Text { text: "Boundary Polygons (Map Layer):"; font.pixelSize: 11; font.bold: true; color: "#8b949e" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Button {
                text: "🟩 Draw Keep-In"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                font.pixelSize: 10
                Material.background: "#21262d"
                onClicked: root.drawKeepInRequested()
            }
            Button {
                text: "🟥 Draw Keep-Out"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                font.pixelSize: 10
                Material.background: "#21262d"
                onClicked: root.drawKeepOutRequested()
            }
        }

        Item { Layout.fillHeight: true }

        // Action Buttons: Sync and Clear
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "🛡️ Sync to Drone"
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                font.bold: true
                Material.background: "#3fb950"
                Material.foreground: "#0d1117"
                onClicked: {
                    if (drone) {
                        drone.uploadGeofence(
                            drone.geofencePolygon,
                            maxAltSpin.value,
                            minAltSpin.value,
                            radiusSpin.value,
                            actionCombo.currentIndex
                        );
                    }
                }
            }

            Button {
                text: "🗑 Clear"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 34
                font.bold: true
                Material.background: "#441b1b"
                Material.foreground: "#ff6b6b"
                onClicked: {
                    if (drone) drone.clearGeofence();
                    root.clearMapFenceRequested();
                }
            }
        }
    }
}
