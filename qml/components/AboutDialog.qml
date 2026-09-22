import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform

// ── About Dialog — DroneGCS ──────────────────────────────────────────────────
Dialog {
    id: root
    width: 480
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
        color: "#0d1117"
        radius: 10
        border.color: "#30363d"
        border.width: 1

        // Subtle top glow
        Rectangle {
            width: parent.width * 0.6
            height: 2
            radius: 1
            color: "#00d4ff"
            opacity: 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Header ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Text {
                    text: "About DroneGCS"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#e6edf3"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28; height: 28; radius: 5
                    color: closeHover.containsMouse ? "#f8514920" : "transparent"
                    border.color: closeHover.containsMouse ? "#f85149" : "#30363d"
                    border.width: 1

                    Text {
                        text: "✕"
                        font.pixelSize: 13
                        color: closeHover.containsMouse ? "#f85149" : "#7d8590"
                        anchors.centerIn: parent
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
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // ── Logo + App Info block ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 130
            color: "#0d1117"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                // Logo
                Rectangle {
                    width: 88; height: 88
                    radius: 12
                    color: "#161b22"
                    border.color: "#30363d"
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: "qrc:/logo.png"
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                    }
                }

                // App name + version + tagline
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "DroneGCS"
                        font.pixelSize: 24
                        font.bold: true
                        color: "#e6edf3"
                    }

                    Text {
                        text: "Tactical Ground Control Station"
                        font.pixelSize: 12
                        color: "#8b949e"
                    }

                    Row {
                        spacing: 8
                        Rectangle {
                            width: vText.implicitWidth + 14; height: 22; radius: 4
                            color: "#00d4ff18"
                            border.color: "#00d4ff50"; border.width: 1
                            Text {
                                id: vText
                                text: "v1.0.0"
                                font.pixelSize: 11; font.bold: true
                                color: "#00d4ff"
                                anchors.centerIn: parent
                            }
                        }
                        Rectangle {
                            width: bText.implicitWidth + 14; height: 22; radius: 4
                            color: "#3fb95018"
                            border.color: "#3fb95050"; border.width: 1
                            Text {
                                id: bText
                                text: "MAVLink v2"
                                font.pixelSize: 11; font.bold: true
                                color: "#3fb950"
                                anchors.centerIn: parent
                            }
                        }
                        Rectangle {
                            width: qText.implicitWidth + 14; height: 22; radius: 4
                            color: "#a070f018"
                            border.color: "#a070f050"; border.width: 1
                            Text {
                                id: qText
                                text: "Qt 6 / QML"
                                font.pixelSize: 11; font.bold: true
                                color: "#a070f0"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // ── Developer Info ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 14

            // Section header
            Text {
                text: "DEVELOPER"
                font.pixelSize: 10
                font.bold: true
                color: "#7d8590"
                font.letterSpacing: 1.5
            }

            // Developer card
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 8
                color: "#161b22"
                border.color: "#30363d"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    // Avatar circle
                    Rectangle {
                        width: 44; height: 44; radius: 22
                        color: "#00d4ff20"
                        border.color: "#00d4ff60"; border.width: 2

                        Text {
                            text: "AG"
                            font.pixelSize: 16; font.bold: true
                            color: "#00d4ff"
                            anchors.centerIn: parent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: "Abhinav Goel"
                            font.pixelSize: 15; font.bold: true
                            color: "#e6edf3"
                        }
                        Text {
                            text: "Drone Systems Engineer · GCS Developer"
                            font.pixelSize: 11
                            color: "#8b949e"
                        }
                    }
                }
            }

            // Contact links section
            Text {
                text: "CONTACT & LINKS"
                font.pixelSize: 10
                font.bold: true
                color: "#7d8590"
                font.letterSpacing: 1.5
                Layout.topMargin: 2
            }

            // LinkedIn
            ContactRow {
                Layout.fillWidth: true
                icon: "in"
                iconColor: "#0a66c2"
                label: "LinkedIn"
                value: "abhinav-g-1b878a2b5"
                url: "https://www.linkedin.com/in/abhinav-g-1b878a2b5/"
            }

            // GitHub
            ContactRow {
                Layout.fillWidth: true
                icon: "GH"
                iconColor: "#e6edf3"
                label: "GitHub"
                value: "Humobot1812"
                url: "https://github.com/Humobot1812"
            }

            // Gmail
            ContactRow {
                Layout.fillWidth: true
                icon: "GM"
                iconColor: "#ea4335"
                label: "Gmail"
                value: "abhinav.goel.robotics@gmail.com"
                url: "mailto:abhinav.goel.robotics@gmail.com"
            }

            // Website / Portfolio
            ContactRow {
                Layout.fillWidth: true
                icon: "🌐"
                iconColor: "#00d4ff"
                label: "Website"
                value: "humobot1812.github.io/Portfolio"
                url: "https://humobot1812.github.io/Portfolio/"
            }

            // Repository
            ContactRow {
                Layout.fillWidth: true
                icon: "⚡"
                iconColor: "#a371f7"
                label: "Repository"
                value: "github.com/Humobot1812/DroneGCS"
                url: "https://github.com/Humobot1812/DroneGCS"
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

            // System info row
            Text {
                text: "SYSTEM INFO"
                font.pixelSize: 10
                font.bold: true
                color: "#7d8590"
                font.letterSpacing: 1.5
            }

            Grid {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 8

                InfoPill { label: "Version";   value: "1.0.0" }
                InfoPill { label: "Build Date"; value: "September 2026" }
                InfoPill { label: "Platform";  value: "Linux x86_64" }
                InfoPill { label: "Protocol";  value: "MAVLink v2" }
                InfoPill { label: "Stack";     value: "Qt 6 · QML · C++" }
                InfoPill { label: "License";   value: "MIT" }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

        // ── Footer ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Text {
                    text: "© 2026 Abhinav Goel · DroneGCS · All rights reserved"
                    font.pixelSize: 10
                    color: "#484f58"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 70; height: 30; radius: 5
                    color: closeBtnHover.containsMouse ? "#21262d" : "transparent"
                    border.color: closeBtnHover.containsMouse ? "#8b949e" : "#30363d"
                    border.width: 1

                    Text {
                        text: "Close"
                        font.pixelSize: 12; font.bold: true
                        color: "#8b949e"
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: closeBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
        }
    }

    // ── Reusable subcomponents ─────────────────────────────────────────────────
    component ContactRow: Rectangle {
        property string icon: ""
        property color iconColor: "#00d4ff"
        property string label: ""
        property string value: ""
        property string url: ""

        height: 44
        radius: 6
        color: rowHover.containsMouse ? "#161b22" : "#0d1117"
        border.color: rowHover.containsMouse ? "#30363d" : "#21262d"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                width: 28; height: 28; radius: 6
                color: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.15)
                border.color: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.5)
                border.width: 1

                Text {
                    text: parent.parent.parent.icon
                    font.pixelSize: 10; font.bold: true
                    color: parent.parent.parent.iconColor
                    anchors.centerIn: parent
                }
            }

            Text {
                text: parent.parent.label
                font.pixelSize: 11; font.bold: true
                color: "#8b949e"
                Layout.preferredWidth: 56
            }

            Text {
                text: parent.parent.value
                font.pixelSize: 12
                color: rowHover.containsMouse ? "#00d4ff" : "#e6edf3"
                font.family: "JetBrains Mono, monospace"
                Layout.fillWidth: true
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                text: "↗"
                font.pixelSize: 13
                color: rowHover.containsMouse ? "#00d4ff" : "#484f58"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(parent.url)
        }
    }

    component InfoPill: RowLayout {
        property string label: ""
        property string value: ""
        spacing: 8

        Text {
            text: label + ":"
            font.pixelSize: 11
            color: "#7d8590"
        }
        Text {
            text: value
            font.pixelSize: 11; font.bold: true
            color: "#e6edf3"
            font.family: "JetBrains Mono, monospace"
        }
    }
}
