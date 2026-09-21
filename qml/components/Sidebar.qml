import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Left icon sidebar — navigation
Rectangle {
    id: root
    color: "#0d1117"
    property int currentPage: 0
    signal pageSelected(int page)
    signal settingsClicked()

    // Thin right border separator
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1; color: "#21262d"
    }

    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }
        spacing: 4

        // Logo/brand at top
        Item {
            width: parent.width; height: 56
            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    text: "✈"
                    font.pixelSize: 22
                    color: "#00d4ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "GCS"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 2
                    color: "#7d8590"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#21262d" }
        Item { width: parent.width; height: 8 }

        // Nav items
        Repeater {
            model: [
                { icon: "🗺",  label: "Map",      page: 0 },
                { icon: "📍", label: "Mission",  page: 1 },
                { icon: "⚙",  label: "Params",   page: 2 },
                { icon: "📷", label: "Video",    page: 3 },
            ]

            delegate: Item {
                width: parent.width; height: 60
                property bool active: root.currentPage === modelData.page

                // Active left accent bar
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    color: active ? "#00d4ff" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Hover/active background
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 3
                    color: active ? "#00d4ff18" : (hoverMa.containsMouse ? "#ffffff08" : "transparent")
                    radius: 4
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: modelData.icon
                        font.pixelSize: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: modelData.label
                        font.pixelSize: 8
                        color: active ? "#00d4ff" : "#7d8590"
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: hoverMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageSelected(modelData.page)
                }
            }
        }
    }

    // Bottom actions: Simulation toggle and settings
    Column {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: 12 }
        spacing: 10

        // Simulation / Demo toggle button
        Rectangle {
            width: 48; height: 30; radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: droneManager.isSimulating ? "#3fb95025" : "#21262d"
            border.color: droneManager.isSimulating ? "#3fb950" : "#30363d"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: droneManager.isSimulating ? "SIM ●" : "SIM ○"
                font.pixelSize: 10; font.bold: true
                color: droneManager.isSimulating ? "#3fb950" : "#7d8590"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (droneManager.isSimulating) {
                        droneManager.stopSimulation();
                    } else {
                        droneManager.startSimulation(2);
                    }
                }
            }
        }

        // Settings Button (⚙)
        Rectangle {
            id: settingsBtn
            width: 44; height: 38; radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: settingsMa.containsMouse ? "#00d4ff20" : "transparent"
            border.color: settingsMa.containsMouse ? "#00d4ff" : "transparent"
            border.width: 1

            Text {
                text: "⚙"
                font.pixelSize: 20
                color: settingsMa.containsMouse ? "#00d4ff" : "#7d8590"
                anchors.centerIn: parent
            }

            MouseArea {
                id: settingsMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsClicked()
            }
        }
    }
}
