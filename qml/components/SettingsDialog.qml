import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: root
    title: "⚙ Ground Control Station Settings"
    modal: true
    width: 520
    height: 480
    anchors.centerIn: parent

    Material.theme: Material.Dark
    Material.accent: "#00d4ff"
    Material.background: "#161b22"
    Material.foreground: "#e6edf3"

    standardButtons: Dialog.Save | Dialog.Cancel

    onAccepted: {
        if (typeof appSettings !== "undefined") {
            appSettings.udpPort = udpPortSpin.value;
            appSettings.defaultAlt = defaultAltSpin.value;
            appSettings.sweepSpacing = sweepSpacingSpin.value;
            appSettings.save();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        TabBar {
            id: settingsTabBar
            Layout.fillWidth: true
            background: Rectangle { color: "#0d1117"; radius: 6 }

            TabButton {
                text: "Flight & Safety"
                font.pixelSize: 11; font.bold: true
            }
            TabButton {
                text: "Telemetry / Link"
                font.pixelSize: 11; font.bold: true
            }
            TabButton {
                text: "Map & Survey"
                font.pixelSize: 11; font.bold: true
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: settingsTabBar.currentIndex

            // Tab 1: Flight & Safety
            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Default Takeoff Altitude"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Altitude used when initiating quick takeoff"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    SpinBox {
                        id: defaultAltSpin
                        from: 2; to: 120; value: (typeof appSettings !== "undefined") ? Math.round(appSettings.defaultAlt) : 15
                        editable: true
                        font.pixelSize: 12
                    }
                    Text { text: "m"; color: "#8b949e"; font.pixelSize: 12 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Return-To-Launch (RTL) Altitude"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Minimum return altitude above home"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    SpinBox {
                        id: rtlAltSpin
                        from: 10; to: 150; value: 25
                        editable: true
                        font.pixelSize: 12
                    }
                    Text { text: "m"; color: "#8b949e"; font.pixelSize: 12 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Autopilot Auto-Detection"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Automatically adapt commands for ArduPilot / PX4"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    Switch {
                        checked: true
                        enabled: false
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Tab 2: Telemetry / Link
            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Default UDP Listen Port"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Standard MAVLink UDP port (14550 for SITL/Autopilot)"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    SpinBox {
                        id: udpPortSpin
                        from: 1024; to: 65535; value: (typeof appSettings !== "undefined") ? appSettings.udpPort : 14550
                        editable: true
                        font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "GCS System ID"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "MAVLink system ID broadcast by this ground station"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    SpinBox {
                        from: 1; to: 255; value: 255
                        editable: true
                        font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Default Serial Baud Rate"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Baud rate for telemetry radios (SiK, Holybro, RFD900)"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    ComboBox {
                        model: ["57600", "115200", "921600", "38400"]
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Tab 3: Map & Survey
            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Survey Sweep Spacing"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Distance between flight grid transects"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    SpinBox {
                        id: sweepSpacingSpin
                        from: 5; to: 100; value: (typeof appSettings !== "undefined") ? Math.round(appSettings.sweepSpacing) : 20
                        editable: true
                        font.pixelSize: 12
                    }
                    Text { text: "m"; color: "#8b949e"; font.pixelSize: 12 }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Distance Units"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Display units for telemetry and waypoint distance"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    ComboBox {
                        model: ["Metric (m, km/h, m/s)", "Imperial (ft, mph)"]
                        font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Offline Tile Cache"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Auto-cache downloaded map tiles for offline field operations"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    Switch {
                        checked: true
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
