import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// AiCopilotDrawer — Tactical Autonomous AI Flight Copilot Interface
// Powered by Google Gemini AI API with Complete Live Context & Autonomous Execution
Rectangle {
    id: root
    width: 440
    height: parent ? parent.height : 700
    color: "#161b22"
    border.color: "#30363d"
    border.width: 1

    property var drone: null
    property bool showKeyConfig: false

    signal closeRequested()
    signal pageNavigationRequested(int page)
    signal togglePipRequested()
    signal openLogsRequested()
    signal openSettingsRequested()
    signal runPreflightRequested()

    Connections {
        target: (typeof aiAssistant !== "undefined") ? aiAssistant : null
        function onRequestPageNavigation(pageIndex) {
            root.pageNavigationRequested(pageIndex);
        }
        function onRequestTogglePip() {
            root.togglePipRequested();
        }
        function onRequestOpenFlightLogs() {
            root.openLogsRequested();
        }
        function onRequestOpenSettings() {
            root.openSettingsRequested();
        }
        function onRequestRunPreflight() {
            root.runPreflightRequested();
        }
    }

    // ── Prevent any mouse clicks, drags, or wheel events from falling through to the underlying map ──
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true; }
        onPressed: function(mouse) { mouse.accepted = true; }
        onClicked: function(mouse) { mouse.accepted = true; }
        onDoubleClicked: function(mouse) { mouse.accepted = true; }
    }

    Shortcut {
        sequence: "Escape"
        enabled: typeof aiAssistant !== "undefined" && aiAssistant.hasPendingHazardAction
        onActivated: {
            if (typeof aiAssistant !== "undefined") {
                aiAssistant.abortHazardAction();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═════════════════════════════════════════════════════════════════════
        // 1. TOP HEADER (Tactical AI Status & Controls)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: "#0d1117"
            border.color: "#21262d"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { wheel.accepted = true; }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 12
                spacing: 10

                // Glowing AI Avatar
                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#0c2d6b" : "#161b22"
                    border.color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#58a6ff" : "#30363d"
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        font.pixelSize: 16
                        color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#58a6ff" : "#00d4ff"
                    }

                    // Pulsing glow ring
                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        color: "transparent"
                        border.color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#58a6ff" : "#3fb950"
                        border.width: 1.5
                        opacity: 0.4
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.25; duration: 1500; easing.type: Easing.OutQuad }
                            NumberAnimation { from: 1.25; to: 1.0; duration: 1500; easing.type: Easing.InQuad }
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Row {
                        spacing: 6
                        Text {
                            text: "TACTICAL AI COPILOT"
                            color: "#f0f6fc"
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#58a6ff" : "#3fb950"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text {
                        text: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) 
                              ? ("✨ " + ((typeof appSettings !== "undefined" && appSettings.geminiModel !== "") ? appSettings.geminiModel : "Gemini AI") + " • Full GCS Control") 
                              : "⚡ Local Autonomous Copilot • Standby"
                        color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#58a6ff" : "#8b949e"
                        font.pixelSize: 10
                    }
                }

                // Gemini API Key toggle button
                Rectangle {
                    width: keyBtnRow.implicitWidth + 14; height: 28; radius: 6
                    color: root.showKeyConfig ? "#1f242c" : "#161b22"
                    border.color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#238636" : "#d29922"
                    border.width: 1

                    Row {
                        id: keyBtnRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "🔑 Key Active" : "🔑 Add Key"
                            font.pixelSize: 10
                            font.bold: true
                            color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#3fb950" : "#d29922"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showKeyConfig = !root.showKeyConfig;
                        }
                    }
                }

                // Close Button (✕)
                Rectangle {
                    width: 30; height: 30; radius: 6
                    color: closeHover.containsMouse ? "#f8514925" : "#21262d"
                    border.color: closeHover.containsMouse ? "#f85149" : "#30363d"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        font.bold: true
                        color: closeHover.containsMouse ? "#f85149" : "#c9d1d9"
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeRequested();
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 1.1 INLINE GEMINI API KEY CONFIG PANEL (Collapsible)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showKeyConfig ? 96 : 0
            visible: root.showKeyConfig
            color: "#0d1117"
            border.color: "#30363d"
            border.width: root.showKeyConfig ? 1 : 0
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Google Gemini AI API Key"
                        color: "#e6edf3"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "Active • Ready" : "Unset • Local Mode"
                        color: (typeof aiAssistant !== "undefined" && aiAssistant.hasGeminiKey) ? "#3fb950" : "#d29922"
                        font.pixelSize: 10
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 6
                        color: "#161b22"
                        border.color: keyField.activeFocus ? "#58a6ff" : "#30363d"
                        border.width: 1

                        TextInput {
                            id: keyField
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 11
                            color: "#e6edf3"
                            echoMode: TextInput.Password
                            clip: true
                            text: (typeof aiAssistant !== "undefined") ? aiAssistant.getGeminiApiKey() : ""

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Paste your AI Studio Gemini API Key..."
                                color: "#6e7681"
                                font.pixelSize: 11
                                visible: !keyField.text && !keyField.activeFocus
                            }
                        }
                    }

                    Button {
                        implicitWidth: 64; implicitHeight: 32
                        Material.background: "#238636"
                        Material.foreground: "#ffffff"
                        text: "Save"
                        font.pixelSize: 11
                        font.bold: true
                        onClicked: {
                            if (typeof aiAssistant !== "undefined") {
                                aiAssistant.setGeminiApiKey(keyField.text.trim());
                                root.showKeyConfig = false;
                            }
                        }
                    }
                }

                Text {
                    text: "Context includes real-time telemetry, flight modes, geofence, waypoints, and full GCS actuation permissions."
                    color: "#7d8590"
                    font.pixelSize: 9
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2. QUICK TACTICAL ACTION CHIPS
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: "#161b22"
            border.color: "#21262d"
            border.width: 1

            Flickable {
                id: chipFlickable
                anchors.fill: parent
                contentWidth: chipRow.width + 20
                contentHeight: parent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    anchors.fill: parent
                    z: 1
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var delta = (wheel.pixelDelta.x !== 0) ? (wheel.pixelDelta.x * 3) : ((wheel.pixelDelta.y !== 0) ? (wheel.pixelDelta.y * 3) : (wheel.angleDelta.y / 2));
                        chipFlickable.contentX = Math.max(0, Math.min(Math.max(0, chipFlickable.contentWidth - chipFlickable.width), chipFlickable.contentX - delta));
                        wheel.accepted = true;
                    }
                }

                Row {
                    id: chipRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "🚁 Takeoff 20m", cmd: "take off to 20 meters" },
                            { label: "🏠 Return Home", cmd: "return to launch" },
                            { label: "📊 SITREP Report", cmd: "report status sitrep" },
                            { label: "🔋 Battery Status", cmd: "how much battery is remaining" },
                            { label: "🛡️ Arm Geofence", cmd: "enable geofence" },
                            { label: "🎯 Guided Mode", cmd: "switch to guided" },
                            { label: "▶ Start Mission", cmd: "start mission" },
                            { label: "📋 Flight Logs", cmd: "open flight logs" },
                            { label: "📷 Camera Feed", cmd: "show video" }
                        ]
                        delegate: Rectangle {
                            width: chipLbl.implicitWidth + 16
                            height: 28
                            radius: 14
                            color: chipArea.containsMouse ? "#21262d" : "#0d1117"
                            border.color: chipArea.containsMouse ? "#58a6ff" : "#30363d"
                            border.width: 1

                            Text {
                                id: chipLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 10
                                font.bold: true
                                color: "#c9d1d9"
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof aiAssistant !== "undefined") {
                                        aiAssistant.processCommand(modelData.cmd);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2.1 DYNAMIC SITREP REASONING & TELEMETRY PULSE (Cognition Indicator)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: (typeof aiAssistant !== "undefined" && aiAssistant.isProcessing) ? 38 : 0
            visible: typeof aiAssistant !== "undefined" && aiAssistant.isProcessing
            color: "#081b3a"
            border.color: "#58a6ff"
            border.width: 1
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 150 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                // Glowing pulsing radar circle
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#58a6ff"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 450 }
                        NumberAnimation { to: 1.0; duration: 450 }
                    }
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.35; duration: 450 }
                        NumberAnimation { to: 1.0; duration: 450 }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: (typeof aiAssistant !== "undefined" && aiAssistant.thinkingPhase !== "")
                              ? aiAssistant.thinkingPhase
                              : "Analyzing live SITREP & calculating trajectory..."
                        color: "#f0f6fc"
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✨ Gemini Reasoning Tokens Active • " + 
                              ((typeof aiAssistant !== "undefined") ? (aiAssistant.thinkingElapsedMs / 1000).toFixed(1) : "0.0") + "s elapsed"
                        color: "#79c0ff"
                        font.pixelSize: 9
                        font.family: "JetBrains Mono, monospace"
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 2.2 SAFETY INTERLOCK COUNTDOWN BADGE (Hazardous Action Interlock)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: hazardBanner
            Layout.fillWidth: true
            Layout.preferredHeight: (typeof aiAssistant !== "undefined" && aiAssistant.hasPendingHazardAction) ? 78 : 0
            visible: typeof aiAssistant !== "undefined" && aiAssistant.hasPendingHazardAction
            color: "#2d0f13"
            border.color: "#f85149"
            border.width: 2
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 180 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "⚠️ HAZARDOUS AI ACTION: " + ((typeof aiAssistant !== "undefined") ? aiAssistant.pendingHazardAction : "")
                        color: "#ff7b72"
                        font.pixelSize: 11
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    // Remaining countdown badge
                    Rectangle {
                        width: cdText.implicitWidth + 10; height: 20; radius: 4
                        color: "#f85149"
                        Text {
                            id: cdText
                            anchors.centerIn: parent
                            text: ((typeof aiAssistant !== "undefined") ? (aiAssistant.pendingHazardRemainingMs / 1000).toFixed(1) : "3.0") + "s"
                            color: "#ffffff"; font.pixelSize: 10; font.bold: true
                            font.family: "JetBrains Mono, monospace"
                        }
                    }
                }

                // Progress Bar counting down to zero
                ProgressBar {
                    Layout.fillWidth: true
                    from: 0.0; to: 1.0
                    value: (typeof aiAssistant !== "undefined") ? aiAssistant.pendingHazardProgress : 1.0
                    Material.accent: "#f85149"
                }

                // Action buttons: [ABORT (ESC)] and [CONFIRM NOW]
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        Material.background: "#da3633"
                        Material.foreground: "#ffffff"
                        text: "⛔ ABORT ACTION (ESC)"
                        font.pixelSize: 10
                        font.bold: true
                        onClicked: {
                            if (typeof aiAssistant !== "undefined") {
                                aiAssistant.abortHazardAction();
                            }
                        }
                    }

                    Button {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 26
                        Material.background: "#238636"
                        Material.foreground: "#ffffff"
                        text: "⚡ EXECUTE"
                        font.pixelSize: 10
                        font.bold: true
                        onClicked: {
                            if (typeof aiAssistant !== "undefined") {
                                aiAssistant.confirmHazardActionNow();
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 3. CHAT HISTORY STREAM
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d1117"
            clip: true

            ListView {
                id: chatList
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: (typeof aiAssistant !== "undefined") ? aiAssistant.conversationHistory : []

                MouseArea {
                    anchors.fill: parent
                    z: 1
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var delta = (wheel.pixelDelta.y !== 0) ? (wheel.pixelDelta.y * 3) : (wheel.angleDelta.y / 2);
                        chatList.contentY = Math.max(0, Math.min(Math.max(0, chatList.contentHeight - chatList.height), chatList.contentY - delta));
                        wheel.accepted = true;
                    }
                }

                onCountChanged: {
                    Qt.callLater(function() {
                        chatList.positionViewAtEnd();
                    });
                }

                delegate: Column {
                    width: chatList.width
                    spacing: 4

                    // Message Row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        // If AI message, align left; if user, align right
                        Item {
                            visible: modelData.role === "user"
                            Layout.fillWidth: true
                        }

                        // Message Bubble
                        Rectangle {
                            Layout.maximumWidth: chatList.width * 0.85
                            implicitWidth: bubbleCol.implicitWidth + 24
                            implicitHeight: bubbleCol.implicitHeight + 16
                            radius: 10
                            color: modelData.role === "user" ? "#21262d" : "#161b22"
                            border.color: {
                                if (modelData.role === "user") return "#30363d";
                                if (modelData.actionTag === "EMERGENCY_KILL") return "#f85149";
                                if (modelData.actionTag === "ARM" || modelData.actionTag === "TAKEOFF") return "#3fb950";
                                return "#58a6ff";
                            }
                            border.width: 1

                            Column {
                                id: bubbleCol
                                anchors.centerIn: parent
                                width: Math.min(parent.Layout.maximumWidth - 24, implicitWidth)
                                spacing: 4

                                // Action badge (for AI)
                                Row {
                                    spacing: 6
                                    visible: modelData.role === "ai" && modelData.actionTag !== ""
                                    Rectangle {
                                        height: 16; width: tagText.implicitWidth + 8; radius: 3
                                        color: modelData.actionTag === "EMERGENCY_KILL" ? "#3d1418" : "#0e331c"
                                        border.color: modelData.actionTag === "EMERGENCY_KILL" ? "#f85149" : "#3fb950"
                                        border.width: 1
                                        Text {
                                            id: tagText
                                            anchors.centerIn: parent
                                            text: "⚡ " + (modelData.actionTag || "EXECUTED")
                                            font.pixelSize: 8; font.bold: true
                                            color: modelData.actionTag === "EMERGENCY_KILL" ? "#ff7b72" : "#56d364"
                                        }
                                    }
                                    Text {
                                        text: modelData.time || ""
                                        font.pixelSize: 9; color: "#7d8590"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    text: modelData.text || ""
                                    color: "#e6edf3"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    width: Math.min(chatList.width * 0.8, 380)
                                    lineHeight: 1.3
                                }
                            }
                        }

                        Item {
                            visible: modelData.role === "ai"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // 4. COMMAND INPUT BAR (Text Only — Voice Recording Removed)
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            color: "#161b22"
            border.color: "#30363d"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { wheel.accepted = true; }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Clear history button
                Rectangle {
                    width: 36; height: 42; radius: 6
                    color: clearHover.containsMouse ? "#21262d" : "#0d1117"
                    border.color: "#30363d"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "🗑"
                        font.pixelSize: 13
                        opacity: clearHover.containsMouse ? 1.0 : 0.7
                    }

                    MouseArea {
                        id: clearHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof aiAssistant !== "undefined") {
                                aiAssistant.clearHistory();
                            }
                        }
                    }
                }

                // Text command input field
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 8
                    color: "#0d1117"
                    border.color: cmdField.activeFocus ? "#58a6ff" : "#30363d"
                    border.width: 1

                    TextInput {
                        id: cmdField
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: 12
                        color: "#e6edf3"
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Instruct AI Copilot to control drone, change modes, or check telemetry..."
                            color: "#7d8590"
                            font.pixelSize: 11
                            visible: !cmdField.text && !cmdField.activeFocus
                        }

                        onAccepted: {
                            if (text.trim() !== "" && typeof aiAssistant !== "undefined") {
                                aiAssistant.processCommand(text.trim());
                                text = "";
                            }
                        }
                    }
                }

                // Send Button
                Button {
                    implicitWidth: 46; implicitHeight: 42
                    Material.background: "#238636"
                    Material.foreground: "#ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "➤"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#ffffff"
                    }

                    onClicked: {
                        if (cmdField.text.trim() !== "" && typeof aiAssistant !== "undefined") {
                            aiAssistant.processCommand(cmdField.text.trim());
                            cmdField.text = "";
                        }
                    }
                }
            }
        }
    }
}
