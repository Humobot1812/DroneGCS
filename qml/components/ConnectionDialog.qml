import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Connection dialog — Serial / UDP / TCP
Dialog {
    id: root
    width: 420
    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    Material.theme: Material.Dark
    Material.accent: "#00d4ff"

    background: Rectangle {
        color: "#161b22"
        radius: 8
        border.color: "#30363d"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Text {
                    text: "Add Drone Connection"
                    font.pixelSize: 15
                    font.bold: true
                    color: "#e6edf3"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "✕"
                    font.pixelSize: 14
                    color: closeHover.containsMouse ? "#f85149" : "#7d8590"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#21262d"
        }

        // ── Body ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 16

            // Transport selector
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                Material.theme: Material.Dark

                TabButton { text: "Serial"; font.pixelSize: 12 }
                TabButton { text: "UDP";    font.pixelSize: 12 }
                TabButton { text: "TCP";    font.pixelSize: 12 }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: tabBar.currentIndex

                // ── Serial ──
                ColumnLayout {
                    spacing: 10
                    Text { text: "Serial Port"; color: "#8b949e"; font.pixelSize: 11 }
                    ComboBox {
                        id: portCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        model: droneManager.availableSerialPorts()
                        editable: true
                        Material.theme: Material.Dark
                        onActiveFocusChanged: if (activeFocus) model = droneManager.availableSerialPorts()
                    }
                    Text { text: "Baud Rate"; color: "#8b949e"; font.pixelSize: 11 }
                    ComboBox {
                        id: baudCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        model: ["57600", "115200", "921600", "1500000"]
                        currentIndex: 1
                        Material.theme: Material.Dark
                    }
                }

                // ── UDP ──
                ColumnLayout {
                    spacing: 10
                    Text { text: "Listen Port"; color: "#8b949e"; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 5
                        color: "#21262d"
                        border.color: udpPortField.activeFocus ? "#00d4ff" : "#30363d"
                        border.width: 1

                        TextInput {
                            id: udpPortField
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6edf3"
                            font.pixelSize: 13
                            font.family: "JetBrains Mono, monospace"
                            text: "14550"
                            inputMethodHints: Qt.ImhDigitsOnly
                            selectByMouse: true
                        }
                    }
                }

                // ── TCP ──
                ColumnLayout {
                    spacing: 10
                    Text { text: "Host"; color: "#8b949e"; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 5
                        color: "#21262d"
                        border.color: tcpHostField.activeFocus ? "#00d4ff" : "#30363d"
                        border.width: 1

                        TextInput {
                            id: tcpHostField
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6edf3"
                            font.pixelSize: 13
                            font.family: "JetBrains Mono, monospace"
                            text: "127.0.0.1"
                            selectByMouse: true
                        }
                    }

                    Text { text: "Port"; color: "#8b949e"; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 5
                        color: "#21262d"
                        border.color: tcpPortField.activeFocus ? "#00d4ff" : "#30363d"
                        border.width: 1

                        TextInput {
                            id: tcpPortField
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6edf3"
                            font.pixelSize: 13
                            font.family: "JetBrains Mono, monospace"
                            text: "5760"
                            inputMethodHints: Qt.ImhDigitsOnly
                            selectByMouse: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#21262d"
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // ── Auto-connect status panel — dynamic rows ────────────────────
            Item {
                id: autoStatusPanel
                Layout.fillWidth: true
                height: visible ? Math.min(statusList.contentHeight, 220) : 0
                clip: true
                visible: statusModel.count > 0

                ListModel { id: statusModel }
                Timer { id: closeTimer; interval: 1800; onTriggered: root.close() }

                Connections {
                    target: droneManager
                    function onAutoConnectStatus(success, transport, message) {
                        statusModel.append({ "ok": success, "transport": transport, "msg": message })
                        // TCP:14550 is the last one emitted — trigger auto-close if any succeeded
                        if (transport === "TCP:14550") {
                            for (var i = 0; i < statusModel.count; i++) {
                                if (statusModel.get(i).ok) { closeTimer.start(); break; }
                            }
                        }
                    }
                }

                ListView {
                    id: statusList
                    anchors.fill: parent
                    model: statusModel
                    spacing: 3
                    clip: true

                    delegate: Rectangle {
                        width: statusList.width
                        height: 26
                        radius: 4
                        color: model.ok ? "#0f2a1a" : "#2a1010"
                        border.color: model.ok ? "#3fb950" : "#f85149"
                        border.width: 1

                        Row {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            Text {
                                text: model.ok ? "✓" : "✗"
                                font.pixelSize: 11; font.bold: true
                                color: model.ok ? "#3fb950" : "#f85149"
                                width: 14
                            }
                            Text {
                                text: model.transport
                                font.pixelSize: 10; font.bold: true
                                font.family: "JetBrains Mono, monospace"
                                color: model.ok ? "#3fb950" : "#f85149"
                                width: 72
                            }
                            Text {
                                text: model.msg
                                font.pixelSize: 10
                                font.family: "JetBrains Mono, monospace"
                                color: model.ok ? "#7dbe8a" : "#e06060"
                            }
                        }
                    }
                }
            }


            // ── Footer Buttons ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Auto-Connect button (left side)
                Rectangle {
                    Layout.preferredWidth: autoConnectLabel.implicitWidth + 24
                    Layout.preferredHeight: 32
                    radius: 5
                    color: autoMa.containsMouse ? "#3fb95020" : "#161b22"
                    border.color: autoMa.containsMouse ? "#3fb950" : "#30363d"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "⚡"
                            font.pixelSize: 12
                            color: "#3fb950"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: autoConnectLabel
                            text: "Auto-Connect"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#3fb950"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: autoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            statusModel.clear()   // reset results from previous scan
                            droneManager.autoConnect()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    Layout.preferredHeight: 32
                    flat: true
                    Material.foreground: "#8b949e"
                    onClicked: root.close()
                }

                Button {
                    text: "Connect"
                    Layout.preferredHeight: 32
                    Material.background: "#00d4ff"
                    Material.foreground: "#0d1117"
                    font.bold: true
                    onClicked: {
                        switch (tabBar.currentIndex) {
                        case 0: droneManager.addSerialConnection(portCombo.editText, parseInt(baudCombo.currentText)); break;
                        case 1: droneManager.addUDPConnection("", parseInt(udpPortField.text)); break;
                        case 2: droneManager.addTCPConnection(tcpHostField.text, parseInt(tcpPortField.text)); break;
                        }
                        root.close();
                    }
                }
            }
        }
    }
}
