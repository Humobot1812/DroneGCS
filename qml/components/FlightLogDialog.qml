import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// FlightLogDialog — Professional Flight Recorder and CSV Telemetry Exporter
Dialog {
    id: root
    title: ""
    modal: true
    dim: true
    anchors.centerIn: parent
    width: Math.min(940, parent.width - 40)
    height: Math.min(680, parent.height - 40)

    Material.theme: Material.Dark
    Material.accent: "#00d4ff"
    Material.background: "#161b22"

    property var drone: null
    property string activeFilter: "ALL"
    property string searchQuery: ""
    property string exportedFilePath: ""

    signal replayRequested(var records)

    background: Rectangle {
        color: "#161b22"
        radius: 8
        border.color: "#30363d"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── 1. Header ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 32; height: 32; radius: 5
                color: "#21262d"
                border.color: "#00d4ff"; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "≡"
                    font.pixelSize: 18
                    color: "#00d4ff"
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 2
                Row {
                    spacing: 8
                    Text {
                        text: "Flight Recorder & Telemetry Logs"
                        color: "#e6edf3"
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 0.8
                    }
                    Rectangle {
                        height: 18; width: logCountText.implicitWidth + 12; radius: 9
                        color: "#21262d"
                        border.color: "#00d4ff"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: logCountText
                            anchors.centerIn: parent
                            text: (root.drone ? root.drone.flightLogCount : 0) + " EVENTS"
                            font.pixelSize: 9; font.bold: true; color: "#00d4ff"
                        }
                    }
                }
                Text {
                    text: (root.drone ? root.drone.name : "Target Drone") + 
                          " (SYS:" + (root.drone ? root.drone.sysId : 1) + ") — Full Chronological Mission & Telemetry Data"
                    color: "#8b949e"
                    font.pixelSize: 11
                }
            }

            // Replay Track on Map Button
            Button {
                implicitHeight: 32
                Material.background: "#0c2d6b"
                Material.foreground: "#58a6ff"
                font.pixelSize: 11
                font.bold: true
                text: "▶ Replay Track on Map"
                enabled: root.drone && root.drone.flightLogCount > 0
                onClicked: {
                    if (root.drone && root.drone.flightLogs) {
                        root.replayRequested(root.drone.flightLogs);
                    }
                }
            }

            Button {
                text: "✕"
                flat: true
                implicitWidth: 32; implicitHeight: 32
                Material.foreground: "#8b949e"
                onClicked: root.close()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#30363d" }

        // ── 2. Filter Bar & Search ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Filter Chips
            Row {
                spacing: 6
                Repeater {
                    model: [
                        { label: "ALL", tag: "ALL" },
                        { label: "⚠️ ALERTS & WARN", tag: "WARN" },
                        { label: "🎯 MODES & NAV", tag: "NAV" },
                        { label: "📊 TELEMETRY", tag: "TELEMETRY" }
                    ]
                    delegate: Rectangle {
                        width: chipText.implicitWidth + 16
                        height: 28
                        radius: 14
                        color: root.activeFilter === modelData.tag ? "#00d4ff" : "#21262d"
                        border.color: root.activeFilter === modelData.tag ? "#00d4ff" : "#30363d"
                        border.width: 1

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 10
                            font.bold: true
                            color: root.activeFilter === modelData.tag ? "#0d1117" : "#c9d1d9"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeFilter = modelData.tag
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Search input
            Rectangle {
                implicitWidth: 200; height: 28; radius: 14
                color: "#0d1117"
                border.color: searchInput.activeFocus ? "#00d4ff" : "#30363d"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { text: "🔍"; font.pixelSize: 11; color: "#8b949e" }
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: "#e6edf3"
                        font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.searchQuery = text.trim().toLowerCase()
                    }
                    Text {
                        text: "✕"
                        font.pixelSize: 10
                        color: "#8b949e"
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }
        }

        // ── 3. Log Records View ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d1117"
            radius: 8
            border.color: "#21262d"
            border.width: 1
            clip: true

            ListView {
                id: logList
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4
                clip: true

                model: {
                    if (!root.drone) return [];
                    var logs = root.drone.flightLogs;
                    if (!logs) return [];

                    var filtered = [];
                    for (var i = 0; i < logs.length; ++i) {
                        var e = logs[i];
                        // Filter by category
                        if (root.activeFilter === "WARN") {
                            if (e.level !== "WARN" && e.level !== "CRITICAL") continue;
                        } else if (root.activeFilter === "NAV") {
                            if (e.level !== "NAV" && e.level !== "MODE") continue;
                        } else if (root.activeFilter === "TELEMETRY") {
                            if (e.level !== "TELEMETRY") continue;
                        }

                        // Filter by search query
                        if (root.searchQuery !== "") {
                            var textContent = (e.message + " " + e.level + " " + e.flightMode).toLowerCase();
                            if (textContent.indexOf(root.searchQuery) === -1) continue;
                        }

                        filtered.push(e);
                    }
                    return filtered;
                }

                delegate: Rectangle {
                    width: logList.width
                    implicitHeight: logRow.implicitHeight + 10
                    radius: 5
                    color: index % 2 === 0 ? "#161b22" : "#0d1117"
                    border.color: {
                        if (modelData.level === "CRITICAL") return "#f85149";
                        if (modelData.level === "WARN")     return "#d29922";
                        return "transparent";
                    }
                    border.width: (modelData.level === "CRITICAL" || modelData.level === "WARN") ? 1 : 0

                    RowLayout {
                        id: logRow
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 10

                        // Timestamp
                        Text {
                            text: modelData.timeShort || ""
                            font.family: "JetBrains Mono, monospace"
                            font.pixelSize: 11
                            color: "#8b949e"
                            Layout.preferredWidth: 90
                        }

                        // Level badge
                        Rectangle {
                            width: levelText.implicitWidth + 12
                            height: 20
                            radius: 4
                            color: {
                                if (modelData.level === "CRITICAL")  return "#490202";
                                if (modelData.level === "WARN")      return "#382305";
                                if (modelData.level === "MODE")      return "#271052";
                                if (modelData.level === "NAV")       return "#0d2b45";
                                if (modelData.level === "TELEMETRY") return "#0e331c";
                                return "#0d313d";
                            }
                            border.color: {
                                if (modelData.level === "CRITICAL")  return "#f85149";
                                if (modelData.level === "WARN")      return "#d29922";
                                if (modelData.level === "MODE")      return "#a371f7";
                                if (modelData.level === "NAV")       return "#58a6ff";
                                if (modelData.level === "TELEMETRY") return "#3fb950";
                                return "#00d4ff";
                            }
                            border.width: 1

                            Text {
                                id: levelText
                                anchors.centerIn: parent
                                text: modelData.level || "INFO"
                                font.pixelSize: 9
                                font.bold: true
                                color: {
                                    if (modelData.level === "CRITICAL")  return "#ff7b72";
                                    if (modelData.level === "WARN")      return "#f0883e";
                                    if (modelData.level === "MODE")      return "#d2a8ff";
                                    if (modelData.level === "NAV")       return "#79c0ff";
                                    if (modelData.level === "TELEMETRY") return "#56d364";
                                    return "#00d4ff";
                                }
                            }
                        }

                        // Message content
                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: modelData.message || ""
                                color: "#e6edf3"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            // Telemetry Snapshot
                            Text {
                                visible: modelData.alt !== undefined && modelData.battery !== undefined
                                text: "Alt: " + (modelData.alt ? modelData.alt.toFixed(1) : "0.0") + "m | " +
                                      "Bat: " + modelData.battery + "% | " +
                                      "Spd: " + (modelData.speed ? modelData.speed.toFixed(1) : "0.0") + "m/s | " +
                                      "Mode: " + (modelData.flightMode || "—") + 
                                      (modelData.armed ? " (ARMED)" : " (DISARMED)")
                                color: "#7d8590"
                                font.pixelSize: 9
                                font.family: "JetBrains Mono, monospace"
                            }
                        }
                    }
                }
            }

            // Empty state placeholder
            Text {
                anchors.centerIn: parent
                text: "No flight logs recorded yet"
                color: "#7d8590"
                font.pixelSize: 12
                visible: logList.count === 0
            }
        }

        // ── 4. Export notification banner (if exported) ──────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: "#0e331c"
            border.color: "#3fb950"; border.width: 1
            visible: root.exportedFilePath !== ""

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                Text {
                    text: "✅ Flight logs successfully exported to: " + root.exportedFilePath
                    color: "#56d364"
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Button {
                    text: "✕"
                    flat: true
                    implicitWidth: 20; implicitHeight: 20
                    Material.foreground: "#56d364"
                    onClicked: root.exportedFilePath = ""
                }
            }
        }

        // ── 5. Bottom Action Bar ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "🗑 Clear Logs"
                Material.background: "#21262d"
                Material.foreground: "#f85149"
                font.bold: true
                font.pixelSize: 11
                onClicked: {
                    if (root.drone) {
                        root.drone.clearFlightLogs();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: exportBtn
                text: "⬇ Download Flight Log (.CSV)"
                Material.background: "#238636"
                Material.foreground: "#ffffff"
                font.bold: true
                font.pixelSize: 12
                onClicked: {
                    if (root.drone) {
                        var path = root.drone.exportFlightLogsToCsv();
                        if (path) {
                            root.exportedFilePath = path;
                        }
                    }
                }
            }

            Button {
                text: "Close"
                Material.background: "#30363d"
                Material.foreground: "#e6edf3"
                font.pixelSize: 11
                onClicked: root.close()
            }
        }
    }
}
