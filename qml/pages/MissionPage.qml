import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Mission planning panel
Rectangle {
    id: root
    color: "#0d1117"

    property var polygon: []
    property var waypoints: []

    function setPolygon(coords) {
        polygon = coords;
        statusText.text = "Polygon set (" + coords.length + " pts). Configure and generate waypoints.";
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left panel: controls ─────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: "#161b22"
            border.color: "#21262d"; border.width: 0

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 16

                Text { text: "📍 Mission Planner"; font.pixelSize: 16; font.bold: true; color: "#e6edf3" }

                // Survey settings
                Rectangle {
                    Layout.fillWidth: true; height: 1; color: "#21262d"
                }

                Text { text: "Survey Configuration"; font.pixelSize: 11; color: "#7d8590" }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Altitude (m)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                    SpinBox {
                        id: altSpin; value: 15; from: 5; to: 120; stepSize: 5
                        Material.theme: Material.Dark; Material.accent: "#00d4ff"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Sweep spacing (m)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                    SpinBox {
                        id: spacingSpin; value: 25; from: 5; to: 100; stepSize: 5
                        Material.theme: Material.Dark; Material.accent: "#00d4ff"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Speed (m/s)"; color: "#e6edf3"; font.pixelSize: 12; Layout.fillWidth: true }
                    SpinBox { id: speedSpin; value: 5; from: 1; to: 20; stepSize: 1; Material.theme: Material.Dark }
                }

                // Generate
                Button {
                    Layout.fillWidth: true
                    text: "⚙  Generate Waypoints"
                    Material.background: "#00d4ff"
                    Material.foreground: "#0d1117"
                    font.bold: true
                    enabled: polygon.length >= 3
                    onClicked: {
                        var drone = droneManager.activeDrone;
                        var hLat = drone ? drone.homeLat : 0;
                        var hLon = drone ? drone.homeLon : 0;
                        var wps  = missionPlanner.generateZigzag(polygon, spacingSpin.value, hLat, hLon);
                        waypoints = wps;
                        waypointList.model = wps;
                        statusText.text = wps.length + " waypoints generated";
                        // Push to map
                        mapPage.setWaypoints(wps);
                    }
                }

                // Upload to drone
                Button {
                    Layout.fillWidth: true
                    text: "🚀  Upload to Drone"
                    Material.background: "#3fb950"
                    Material.foreground: "#0d1117"
                    font.bold: true
                    enabled: waypoints.length > 0 && droneManager.activeDrone
                    onClicked: uploadMission()
                }

                Button {
                    Layout.fillWidth: true
                    text: "▶  Start Mission"
                    enabled: droneManager.activeDrone
                    onClicked: if(droneManager.activeDrone) droneManager.activeDrone.startMission()
                }

                Button {
                    Layout.fillWidth: true
                    text: "⏸  Pause Mission"
                    enabled: droneManager.activeDrone
                    onClicked: if(droneManager.activeDrone) droneManager.activeDrone.pauseMission()
                }

                Item { Layout.fillHeight: true }

                // Status
                Rectangle {
                    Layout.fillWidth: true; height: 50; radius: 6
                    color: "#21262d"
                    Text {
                        id: statusText
                        anchors { fill: parent; margins: 8 }
                        text: "Draw a polygon on the Map page to get started."
                        color: "#7d8590"; font.pixelSize: 11; wrapMode: Text.Wrap
                    }
                }
            }
        }

        // ── Right panel: waypoint list ────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: "#0d1117"

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                Text {
                    text: "Waypoints (" + waypoints.length + ")"
                    font.pixelSize: 14; font.bold: true; color: "#e6edf3"
                }

                ListView {
                    id: waypointList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true

                    header: Rectangle {
                        width: parent.width; height: 32; color: "#161b22"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Text { text: "#";   color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 40 }
                            Text { text: "Lat"; color: "#7d8590"; font.pixelSize: 11; Layout.fillWidth: true }
                            Text { text: "Lon"; color: "#7d8590"; font.pixelSize: 11; Layout.fillWidth: true }
                            Text { text: "Alt(m)"; color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 60 }
                        }
                    }

                    delegate: Rectangle {
                        width: waypointList.width; height: 36
                        color: index % 2 === 0 ? "#0d1117" : "#161b22"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Text { text: index + 1; color: "#00d4ff"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.preferredWidth: 40 }
                            Text { text: modelData.lat.toFixed(7); color: "#e6edf3"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.fillWidth: true }
                            Text { text: modelData.lon.toFixed(7); color: "#e6edf3"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.fillWidth: true }
                            Text { text: altSpin.value;            color: "#3fb950"; font.pixelSize: 11; font.family: "JetBrains Mono, monospace"; Layout.preferredWidth: 60 }
                        }
                    }
                }
            }
        }
    }

    function uploadMission() {
        var drone = droneManager.activeDrone;
        if (!drone) return;
        // Build and send mission packets through PythonBridge or direct MAVLink
        pythonBridge.send("survey", {
            "cmd": "upload_mission",
            "waypoints": waypoints,
            "altitude": altSpin.value,
            "sysid": drone.sysId()
        });
        statusText.text = "Uploading " + waypoints.length + " waypoints to SYS:" + drone.sysId() + "...";
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
        statusText.text = "Survey mission ready (5 waypoints loaded).";
    }
}
