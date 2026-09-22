import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// FlightReplayBar — Tactical Telemetry Flight Playback Scrubber Deck
Rectangle {
    id: root
    width: Math.min(820, parent ? (parent.width - 40) : 800)
    height: 94
    radius: 10
    color: "#0d1117"
    border.color: "#00d4ff"
    border.width: 1.5
    clip: true

    property var flightLogs: []
    property int currentIndex: 0
    property bool isPlaying: false
    property real playbackSpeed: 1.0 // 1x, 2x, 5x, 10x

    signal positionChanged(var record)
    signal closeRequested()

    function loadRecords(records) {
        if (!records || records.length === 0) return;
        flightLogs = records;
        currentIndex = 0;
        isPlaying = false;
        if (flightLogs.length > 0) {
            root.positionChanged(flightLogs[0]);
        }
    }

    Timer {
        id: playTimer
        interval: Math.max(20, 200 / root.playbackSpeed)
        running: root.isPlaying && root.flightLogs && root.flightLogs.length > 1
        repeat: true
        onTriggered: {
            if (root.currentIndex < root.flightLogs.length - 1) {
                root.currentIndex++;
                root.positionChanged(root.flightLogs[root.currentIndex]);
            } else {
                root.isPlaying = false;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // ── 1. Header Bar: Title, Live Telemetry Snapshot, Close Button ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 20; height: 20; radius: 4
                color: "#00d4ff25"
                border.color: "#00d4ff"
                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    font.pixelSize: 10
                    color: "#00d4ff"
                }
            }

            Text {
                text: "TACTICAL FLIGHT TELEMETRY REPLAY"
                color: "#f0f6fc"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 0.8
            }

            Rectangle {
                height: 18; width: recCountText.implicitWidth + 10; radius: 4
                color: "#21262d"
                border.color: "#30363d"
                Text {
                    id: recCountText
                    anchors.centerIn: parent
                    text: (root.currentIndex + 1) + " / " + (root.flightLogs ? root.flightLogs.length : 0) + " PTS"
                    font.pixelSize: 9
                    color: "#8b949e"
                    font.family: "JetBrains Mono, monospace"
                }
            }

            Item { Layout.fillWidth: true }

            // Current Telemetry Metric Badges
            Row {
                spacing: 10
                visible: root.flightLogs && root.flightLogs.length > 0 && root.currentIndex < root.flightLogs.length

                readonly property var cur: root.flightLogs[root.currentIndex] || {}

                Text {
                    text: "⏱ " + (parent.cur.timeShort || "00:00:00")
                    color: "#8b949e"; font.pixelSize: 10
                    font.family: "JetBrains Mono, monospace"
                }
                Text {
                    text: "ALT: " + (parent.cur.relAlt ? parent.cur.relAlt.toFixed(1) : "0.0") + "m"
                    color: "#3fb950"; font.pixelSize: 10; font.bold: true
                    font.family: "JetBrains Mono, monospace"
                }
                Text {
                    text: "SPD: " + (parent.cur.groundSpeed ? parent.cur.groundSpeed.toFixed(1) : "0.0") + "m/s"
                    color: "#00d4ff"; font.pixelSize: 10; font.bold: true
                    font.family: "JetBrains Mono, monospace"
                }
                Text {
                    text: "MODE: " + (parent.cur.flightMode || "GUIDED")
                    color: "#d29922"; font.pixelSize: 10; font.bold: true
                    font.family: "JetBrains Mono, monospace"
                }
            }

            // Close button
            Rectangle {
                width: 22; height: 22; radius: 4
                color: closeHover.containsMouse ? "#f8514930" : "#21262d"
                border.color: closeHover.containsMouse ? "#f85149" : "#30363d"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: closeHover.containsMouse ? "#f85149" : "#8b949e"
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isPlaying = false;
                        root.closeRequested();
                    }
                }
            }
        }

        // ── 2. Playback Scrubber & Speed Controls ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Play / Pause Button
            Rectangle {
                width: 32; height: 32; radius: 6
                color: root.isPlaying ? "#238636" : "#21262d"
                border.color: root.isPlaying ? "#3fb950" : "#30363d"

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "⏸" : "▶"
                    font.pixelSize: 13
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isPlaying = !root.isPlaying
                }
            }

            // Interactive Timeline Slider
            Slider {
                id: scrubSlider
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, (root.flightLogs ? root.flightLogs.length - 1 : 1))
                value: root.currentIndex
                stepSize: 1.0

                onMoved: {
                    root.currentIndex = Math.round(value);
                    if (root.flightLogs && root.flightLogs.length > root.currentIndex) {
                        root.positionChanged(root.flightLogs[root.currentIndex]);
                    }
                }
            }

            // Playback Speed Selector Chips
            Row {
                spacing: 4

                Repeater {
                    model: [
                        { label: "1x", speed: 1.0 },
                        { label: "2x", speed: 2.0 },
                        { label: "5x", speed: 5.0 },
                        { label: "10x", speed: 10.0 }
                    ]

                    delegate: Rectangle {
                        width: 32; height: 26; radius: 4
                        color: root.playbackSpeed === modelData.speed ? "#00d4ff" : "#21262d"
                        border.color: root.playbackSpeed === modelData.speed ? "#00d4ff" : "#30363d"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 10
                            font.bold: true
                            color: root.playbackSpeed === modelData.speed ? "#0d1117" : "#c9d1d9"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playbackSpeed = modelData.speed
                        }
                    }
                }
            }
        }
    }
}
