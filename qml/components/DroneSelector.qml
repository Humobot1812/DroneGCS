import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Multi-drone selector tabs — one tab per connected drone
Rectangle {
    id: root
    color: "#161b22"

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1; color: "#21262d"
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 4

        // Drone tabs from model
        ListView {
            id: tabList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: droneManager
            orientation: ListView.Horizontal
            clip: true
            spacing: 4

            delegate: Item {
                width: 180; height: tabList.height

                property bool active: index === droneManager.activeDroneIndex

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: active ? 0 : 4
                    color: active ? "#21262d" : "transparent"
                    radius: active ? 6 : 4

                    // Color dot
                    Rectangle {
                        id: colorDot
                        width: 8; height: 8; radius: 4
                        color: model.color
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }

                        // Pulse animation if connected
                        SequentialAnimation on opacity {
                            running: model.connected
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }

                    Column {
                        anchors { left: colorDot.right; leftMargin: 8; verticalCenter: parent.verticalCenter; right: closeBtn.left; rightMargin: 4 }
                        spacing: 1
                        Text {
                            text: model.droneName
                            font.pixelSize: 11
                            color: active ? "#e6edf3" : "#7d8590"
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: model.connected ? (model.flightMode + (model.armed ? " ● ARMED" : "")) : "DISCONNECTED"
                            font.pixelSize: 9
                            color: model.connected ? (model.armed ? "#f85149" : "#3fb950") : "#7d8590"
                        }
                    }

                    // Close button
                    Item {
                        id: closeBtn
                        width: 20; height: parent.height
                        anchors.right: parent.right
                        Text {
                            text: "✕"
                            font.pixelSize: 10
                            color: "#7d8590"
                            anchors.centerIn: parent
                            visible: closeHover.containsMouse
                        }
                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: droneManager.removeConnection(index)
                        }
                    }

                    MouseArea {
                        anchors { fill: parent; rightMargin: 20 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: droneManager.setActiveDroneIndex(index)
                    }
                }
            }
        }

        // "+" Add drone button
        Item {
            width: 36; height: parent.height
            Rectangle {
                anchors.centerIn: parent
                width: 28; height: 28; radius: 6
                color: addHover.containsMouse ? "#21262d" : "transparent"
                border.color: "#30363d"; border.width: 1
                Text { text: "+"; color: "#7d8590"; font.pixelSize: 16; anchors.centerIn: parent }
            }
            MouseArea {
                id: addHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: connectionDialog.open()
            }
        }

        // Swarm Operations master button (visible when 2+ drones connected)
        Item {
            visible: droneManager.droneCount > 1
            width: 125; height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: 115; height: 28; radius: 6
                color: swarmHover.containsMouse ? "#00d4ff20" : "#21262d"
                border.color: "#00d4ff"; border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: "🐝"; font.pixelSize: 11 }
                    Text { text: "Swarm Deck"; color: "#00d4ff"; font.pixelSize: 11; font.bold: true }
                }
            }

            MouseArea {
                id: swarmHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: swarmDialog.open()
            }
        }
    }

    // Swarm Master Command Dialog
    Dialog {
        id: swarmDialog
        title: "🐝 Swarm Master Operations (" + droneManager.droneCount + " Drones)"
        standardButtons: Dialog.Close
        anchors.centerIn: parent
        width: 420
        modal: true
        Material.background: "#161b22"
        Material.foreground: "#e6edf3"

        ColumnLayout {
            width: parent.width
            spacing: 12

            Text {
                text: "Broadcast simultaneous flight commands across ALL connected swarm vehicles:"
                color: "#8b949e"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Button {
                    text: "▲ ARM ALL"
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    Material.background: "#1b3d1b"
                    contentItem: Text { text: parent.text; color: "#3fb950"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { droneManager.armAll(); swarmDialog.close(); }
                }
                Button {
                    text: "⬛ DISARM ALL"
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    Material.background: "#3d1b1b"
                    contentItem: Text { text: parent.text; color: "#f85149"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { droneManager.disarmAll(); swarmDialog.close(); }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Button {
                    text: "🛫 TAKEOFF ALL (15m)"
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    Material.background: "#21262d"
                    contentItem: Text { text: parent.text; color: "#00d4ff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { droneManager.takeoffAll(15.0); swarmDialog.close(); }
                }
                Button {
                    text: "🏠 RTL ALL"
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    Material.background: "#21262d"
                    contentItem: Text { text: parent.text; color: "#d29922"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: { droneManager.returnAllToLaunch(); swarmDialog.close(); }
                }
            }

            Button {
                text: "🛬 LAND ALL"
                Layout.fillWidth: true; Layout.preferredHeight: 34
                Material.background: "#21262d"
                contentItem: Text { text: parent.text; color: "#e6edf3"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: { droneManager.landAll(); swarmDialog.close(); }
            }
        }
    }
}
