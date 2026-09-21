import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Bottom status bar — connection info, GPS, heartbeat, EKF
Rectangle {
    id: root
    color: "#0d1117"

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1; color: "#21262d"
    }

    property var drone: droneManager.activeDrone

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 16

        // Heartbeat LED
        LEDIndicator {
            id: hbLed
            active: drone ? drone.isConnected : false
            color: "#00d4ff"
            label: "HB"
        }

        // GPS fix
        LEDIndicator {
            active: drone ? drone.gpsFixType >= 3 : false
            color: "#3fb950"
            label: drone ? ("GPS " + drone.gpsSats + "sat") : "GPS"
        }

        // Battery
        Row {
            spacing: 5
            Text {
                text: "🔋"
                font.pixelSize: 13
                color: drone && drone.batteryPercent >= 0
                       ? (drone.batteryPercent > 30 ? "#3fb950" : "#f85149")
                       : "#7d8590"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: drone && drone.batteryPercent >= 0
                      ? (drone.batteryPercent + "% " + drone.batteryVoltage.toFixed(2) + "V")
                      : "—"
                font.pixelSize: 12
                color: "#e6edf3"
                font.bold: true
                font.family: "JetBrains Mono, monospace"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Flight mode (with robust Layout sizing so mode text like STABILIZE never overflows)
        Rectangle {
            id: modeRect
            implicitWidth: modeText.implicitWidth + 24
            implicitHeight: 24
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: 24
            radius: 5
            color: drone && drone.isArmed ? "#2d1b1b" : "#1b2d1b"
            border.color: drone && drone.isArmed ? "#f85149" : "#3fb950"
            border.width: 1

            Text {
                id: modeText
                text: drone ? drone.flightMode : "—"
                color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                font.pixelSize: 12; font.bold: true
                font.family: "JetBrains Mono, monospace"
                anchors.centerIn: parent
            }
        }

        Item { Layout.fillWidth: true }

        // Mission progress
        Row {
            spacing: 6
            visible: drone && drone.missionTotal > 0
            Text { text: "WP"; font.pixelSize: 11; font.bold: true; color: "#7d8590"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: drone ? (drone.missionCurrent + "/" + drone.missionTotal) : "—"
                font.pixelSize: 12; font.bold: true; color: "#00d4ff"
                font.family: "JetBrains Mono, monospace"
                anchors.verticalCenter: parent.verticalCenter
            }
            // Progress bar
            Rectangle {
                width: 90; height: 7; radius: 3; color: "#21262d"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: drone && drone.missionTotal > 0
                           ? parent.width * (drone.missionCurrent / drone.missionTotal) : 0
                    height: parent.height; radius: parent.radius; color: "#00d4ff"
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }

        // "Add connection" button
        Rectangle {
            Layout.preferredWidth: 110; Layout.preferredHeight: 26
            radius: 5
            color: addMa.containsMouse ? "#00d4ff20" : "#161b22"
            border.color: "#00d4ff"; border.width: 1
            Text { text: "+ Connect"; color: "#00d4ff"; font.pixelSize: 12; font.bold: true; anchors.centerIn: parent }
            MouseArea {
                id: addMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: connectionDialog.open()
            }
        }
    }

    // Heartbeat pulse animation
    SequentialAnimation {
        running: drone ? drone.isConnected : false
        loops: Animation.Infinite
        NumberAnimation { target: hbLed; property: "opacity"; to: 0.4; duration: 500 }
        NumberAnimation { target: hbLed; property: "opacity"; to: 1.0; duration: 500 }
    }
}
