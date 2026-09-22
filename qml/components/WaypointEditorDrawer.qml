import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// WaypointEditorDrawer — Granular Waypoint Editing and Sequence Management
Rectangle {
    id: root
    width: 360
    color: "#161b22"
    border.color: "#30363d"
    border.width: 1
    radius: 8

    property var waypoints: []
    property var drone: droneManager.activeDrone

    signal waypointsModified(var newWaypoints)
    signal waypointSelected(int index)
    signal closeRequested()

    function setWaypoints(wps) {
        waypoints = wps || [];
    }

    function removeWaypoint(idx) {
        var copy = waypoints.slice();
        copy.splice(idx, 1);
        waypoints = copy;
        root.waypointsModified(waypoints);
    }

    function moveWaypointUp(idx) {
        if (idx <= 0) return;
        var copy = waypoints.slice();
        var temp = copy[idx - 1];
        copy[idx - 1] = copy[idx];
        copy[idx] = temp;
        waypoints = copy;
        root.waypointsModified(waypoints);
    }

    function moveWaypointDown(idx) {
        if (idx >= waypoints.length - 1) return;
        var copy = waypoints.slice();
        var temp = copy[idx + 1];
        copy[idx + 1] = copy[idx];
        copy[idx] = temp;
        waypoints = copy;
        root.waypointsModified(waypoints);
    }

    function updateWaypointAlt(idx, newAlt) {
        if (idx < 0 || idx >= waypoints.length) return;
        var copy = waypoints.slice();
        copy[idx].alt = newAlt;
        waypoints = copy;
        root.waypointsModified(waypoints);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "📍 Waypoint Mission Table (" + root.waypoints.length + ")"
                color: "#e6edf3"; font.pixelSize: 13; font.bold: true
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 22; height: 22; radius: 11; color: "#21262d"
                Text { text: "✕"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // Table Header
        Rectangle {
            Layout.fillWidth: true
            height: 26
            color: "#0d1117"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                Text { text: "#"; color: "#7d8590"; font.pixelSize: 10; Layout.preferredWidth: 24 }
                Text { text: "Lat / Lon"; color: "#7d8590"; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: "Alt (m)"; color: "#7d8590"; font.pixelSize: 10; Layout.preferredWidth: 65 }
                Text { text: "Actions"; color: "#7d8590"; font.pixelSize: 10; Layout.preferredWidth: 65 }
            }
        }

        // Waypoints List
        ListView {
            id: wpListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.waypoints

            delegate: Rectangle {
                width: wpListView.width
                height: 40
                color: index % 2 === 0 ? "#161b22" : "#0d1117"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 6

                    // Sequence Badge
                    Rectangle {
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                        color: "#00d4ff20"
                        border.color: "#00d4ff"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: (index + 1)
                            font.pixelSize: 10; font.bold: true; color: "#00d4ff"
                        }
                    }

                    // Coordinates
                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: modelData.lat.toFixed(5) + "° N"
                            color: "#e6edf3"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"
                        }
                        Text {
                            text: modelData.lon.toFixed(5) + "° E"
                            color: "#8b949e"; font.pixelSize: 9; font.family: "JetBrains Mono, monospace"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.waypointSelected(index)
                        }
                    }

                    // Altitude SpinBox
                    SpinBox {
                        Layout.preferredWidth: 70; Layout.preferredHeight: 26
                        from: 2; to: 200; stepSize: 5
                        value: modelData.alt || 15
                        editable: true
                        font.pixelSize: 10
                        onValueModified: root.updateWaypointAlt(index, value)
                    }

                    // Move Up/Down/Delete Actions
                    Row {
                        Layout.preferredWidth: 65
                        spacing: 2

                        Rectangle {
                            width: 20; height: 22; radius: 3; color: "#21262d"
                            Text { text: "▲"; color: "#8b949e"; font.pixelSize: 9; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.moveWaypointUp(index)
                            }
                        }
                        Rectangle {
                            width: 20; height: 22; radius: 3; color: "#21262d"
                            Text { text: "▼"; color: "#8b949e"; font.pixelSize: 9; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.moveWaypointDown(index)
                            }
                        }
                        Rectangle {
                            width: 20; height: 22; radius: 3; color: "#441b1b"
                            Text { text: "🗑"; color: "#ff6b6b"; font.pixelSize: 9; anchors.centerIn: parent }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeWaypoint(index)
                            }
                        }
                    }
                }
            }
        }

        // Action Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                text: "📍 Add Drone Pos"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                font.pixelSize: 10
                Material.background: "#21262d"
                enabled: drone && drone.isConnected
                onClicked: {
                    if (drone) {
                        var copy = waypoints.slice();
                        copy.push({ lat: drone.latitude, lon: drone.longitude, alt: Math.round(drone.relAltitude > 5 ? drone.relAltitude : 15) });
                        waypoints = copy;
                        root.waypointsModified(waypoints);
                    }
                }
            }

            Button {
                text: "🚀 Upload Mission"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                font.bold: true; font.pixelSize: 10
                Material.background: "#3fb950"
                Material.foreground: "#0d1117"
                enabled: drone && drone.isConnected && root.waypoints.length > 0
                onClicked: {
                    if (drone) drone.uploadWaypoints(root.waypoints);
                }
            }
        }
    }
}
