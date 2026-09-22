import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Bottom status bar — connection info, GPS, heartbeat, EKF
Rectangle {
    id: root
    color: "#0d1117"

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: "#21262d"
    }

    property var drone: droneManager.activeDrone
    signal connectClicked()

    RowLayout {
        anchors { fill: parent; leftMargin: 28; rightMargin: 28 }
        spacing: 20

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
            label: drone ? ("GPS " + drone.gpsSats + " sat") : "GPS"
        }

        // Battery
        Row {
            spacing: 10
            Rectangle {
                width: 54
                height: 34
                radius: 5
                color: "#161b22"
                border.color: drone && drone.batteryPercent >= 0
                              ? (drone.batteryPercent > 30 ? "#3fb950" : "#f85149")
                              : "#30363d"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "BAT"
                    font.pixelSize: 14
                    font.bold: true
                    color: drone && drone.batteryPercent >= 0
                           ? (drone.batteryPercent > 30 ? "#3fb950" : "#f85149")
                           : "#7d8590"
                    anchors.centerIn: parent
                }
            }

            Text {
                text: drone && drone.batteryPercent >= 0
                      ? (drone.batteryPercent + "% (" + drone.batteryVoltage.toFixed(2) + "V)")
                      : "—"
                font.pixelSize: 14
                color: "#e6edf3"
                font.bold: true
                font.family: "JetBrains Mono, monospace"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Flight mode
        Rectangle {
            id: modeRect
            implicitWidth: modeText.implicitWidth + 28
            implicitHeight: 38
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: 38
            radius: 6
            color: drone && drone.isArmed ? "#2d1414" : "#142618"
            border.color: drone && drone.isArmed ? "#f85149" : "#3fb950"
            border.width: 1

            Text {
                id: modeText
                text: drone ? drone.flightMode : "DISCONNECTED"
                color: drone && drone.isArmed ? "#f85149" : "#3fb950"
                font.pixelSize: 16
                font.bold: true
                font.family: "JetBrains Mono, monospace"
                anchors.centerIn: parent
            }
        }

        Item { Layout.fillWidth: true }

        // Mission progress
        Row {
            spacing: 10
            visible: drone && drone.missionTotal > 0
            Text {
                text: "WP"
                font.pixelSize: 14
                font.bold: true
                color: "#7d8590"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: drone ? (drone.missionCurrent + "/" + drone.missionTotal) : "—"
                font.pixelSize: 14
                font.bold: true
                color: "#00d4ff"
                font.family: "JetBrains Mono, monospace"
                anchors.verticalCenter: parent.verticalCenter
            }
            // Progress bar
            Rectangle {
                width: 120
                height: 10
                radius: 5
                color: "#21262d"
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: drone && drone.missionTotal > 0
                           ? parent.width * (drone.missionCurrent / drone.missionTotal) : 0
                    height: parent.height
                    radius: parent.radius
                    color: "#00d4ff"
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
        }

        // Link status indicator
        Row {
            spacing: 10
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: drone && drone.isConnected ? "#3fb950" : "#7d8590"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: drone && drone.isConnected ? (drone.name || "LINK ACTIVE") : "NO LINK"
                font.pixelSize: 14
                font.bold: true
                color: drone && drone.isConnected ? "#8b949e" : "#7d8590"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // "+ Connect" button
        Rectangle {
            Layout.preferredWidth: 130
            Layout.preferredHeight: 38
            radius: 6
            color: connectMa.containsMouse ? "#00d4ff25" : "#161b22"
            border.color: "#00d4ff"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "+"
                    color: "#00d4ff"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Connect"
                    color: "#00d4ff"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: connectMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.connectClicked()
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
