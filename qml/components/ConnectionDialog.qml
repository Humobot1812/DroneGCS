import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Connection dialog — Serial / UDP / TCP
Dialog {
    id: root
    title: "Add Drone Connection"
    width: 420
    modal: true
    anchors.centerIn: Overlay.overlay

    Material.theme: Material.Dark
    Material.accent: "#00d4ff"

    background: Rectangle {
        color: "#161b22"; radius: 10
        border.color: "#30363d"; border.width: 1
    }

    header: Rectangle {
        color: "transparent"; height: 56
        Text {
            text: "🔗  Add Drone Connection"
            font.pixelSize: 16; font.bold: true
            color: "#e6edf3"
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
        }
    }

    ColumnLayout {
        width: parent.width
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

            // ── Serial ──────────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Text { text: "Serial Port"; color: "#7d8590"; font.pixelSize: 11 }
                ComboBox {
                    id: portCombo
                    Layout.fillWidth: true
                    model: droneManager.availableSerialPorts()
                    editable: true
                    Material.theme: Material.Dark
                    onActiveFocusChanged: if(activeFocus) model = droneManager.availableSerialPorts()
                }
                Text { text: "Baud Rate"; color: "#7d8590"; font.pixelSize: 11 }
                ComboBox {
                    id: baudCombo
                    Layout.fillWidth: true
                    model: ["57600", "115200", "921600", "1500000"]
                    currentIndex: 1
                    Material.theme: Material.Dark
                }
            }

            // ── UDP ─────────────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Text { text: "Listen Port"; color: "#7d8590"; font.pixelSize: 11 }
                TextField {
                    id: udpPortField
                    Layout.fillWidth: true
                    text: "14550"
                    placeholderText: "14550"
                    inputMethodHints: Qt.ImhDigitsOnly
                    Material.theme: Material.Dark
                }
            }

            // ── TCP ─────────────────────────────────────────────────────────
            ColumnLayout {
                spacing: 12
                Text { text: "Host"; color: "#7d8590"; font.pixelSize: 11 }
                TextField {
                    id: tcpHostField
                    Layout.fillWidth: true
                    text: "127.0.0.1"
                    Material.theme: Material.Dark
                }
                Text { text: "Port"; color: "#7d8590"; font.pixelSize: 11 }
                TextField {
                    id: tcpPortField
                    Layout.fillWidth: true
                    text: "5760"
                    inputMethodHints: Qt.ImhDigitsOnly
                    Material.theme: Material.Dark
                }
            }
        }

        // Buttons
        RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                flat: true
                Material.foreground: "#7d8590"
                onClicked: root.close()
            }

            Button {
                text: "Connect"
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
