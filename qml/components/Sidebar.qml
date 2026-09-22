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
    signal aiCopilotClicked()
    signal aboutClicked()

    // Thin right border separator
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1
        color: "#21262d"
    }

    // ── Logo section (full sidebar width) ──────────────────────────────
    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 8 }
        spacing: 0

        // Logo/brand at top
        Item {
            width: parent.width
            height: 100

            Rectangle {
                anchors.centerIn: parent
                width: 90
                height: 90
                radius: 8
                color: "#161b22"
                border.color: "#30363d"
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "qrc:/logo.png"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: "#21262d" }
    }

    // ── Nav items — narrow 64px strip centered in sidebar ───────────────
    Column {
        anchors {
            top: parent.top
            topMargin: 100 + 8 + 1 + 8   // logo slot + topMargin + divider + gap
            horizontalCenter: parent.horizontalCenter
        }
        width: 64
        spacing: 6

        // Nav items
        Repeater {
            model: [
                { icon: "◈", label: "Map",     page: 0 },
                { icon: "◎", label: "Mission", page: 1 },
                { icon: "≡", label: "Params",  page: 2 },
                { icon: "▶", label: "Video",   page: 3 }
            ]

            delegate: Item {
                width: 64
                height: 58
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
                    anchors.rightMargin: 4
                    color: active ? "#1f3b4d" : (hoverMa.containsMouse ? "#161b22" : "transparent")
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: modelData.icon
                        font.pixelSize: 17
                        color: active ? "#00d4ff" : (hoverMa.containsMouse ? "#e6edf3" : "#8b949e")
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: modelData.label
                        font.pixelSize: 11
                        font.weight: active ? Font.Medium : Font.Normal
                        color: active ? "#00d4ff" : (hoverMa.containsMouse ? "#e6edf3" : "#7d8590")
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

    // Bottom actions: AI Copilot, About, Settings
    Column {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: 12 }
        spacing: 8

        // AI Copilot Button
        Rectangle {
            id: aiBtn
            width: 42
            height: 42
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: aiMa.containsMouse ? "#00d4ff25" : "#161b22"
            border.color: aiMa.containsMouse ? "#00d4ff" : "#30363d"
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    text: "❆"
                    font.pixelSize: 15
                    color: "#00d4ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "AI"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#00d4ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: aiMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.aiCopilotClicked()
            }
        }

        // About Button
        Rectangle {
            id: aboutBtn
            width: 42
            height: 42
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: aboutMa.containsMouse ? "#00d4ff15" : "#161b22"
            border.color: aboutMa.containsMouse ? "#00d4ff80" : "#30363d"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    text: "ⓘ"
                    font.pixelSize: 16
                    color: aboutMa.containsMouse ? "#00d4ff" : "#7d8590"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            MouseArea {
                id: aboutMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.aboutClicked()
            }
        }

        // Settings Button
        Rectangle {
            id: settingsBtn
            width: 42
            height: 42
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: settingsMa.containsMouse ? "#21262d" : "#161b22"
            border.color: settingsMa.containsMouse ? "#8b949e" : "#30363d"
            border.width: 1

            Text {
                text: "⚙"
                font.pixelSize: 18
                color: settingsMa.containsMouse ? "#e6edf3" : "#7d8590"
                anchors.centerIn: parent
                Behavior on color { ColorAnimation { duration: 150 } }
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
