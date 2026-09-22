import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: root
    title: "⚙ Ground Control Station Settings"
    modal: true
    width: 540
    height: 520
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
            appSettings.rtlAlt = rtlAltSpin.value;
            appSettings.sweepSpacing = sweepSpacingSpin.value;
            appSettings.autoDetectAutopilot = autoDetectSwitch.checked;
            appSettings.voiceEnabled = voiceSwitch.checked;
            var selectedVoice = voiceProfileCombo.model.get(voiceProfileCombo.currentIndex).value;
            appSettings.maleVoiceProfile = selectedVoice;
            if (typeof audioAnnunciator !== "undefined") {
                audioAnnunciator.enabled = voiceSwitch.checked;
                audioAnnunciator.maleVoiceProfile = selectedVoice;
            }
            if (geminiKeyField.text.trim() !== "") {
                appSettings.geminiApiKey = geminiKeyField.text.trim();
            }
            if (geminiModelCombo.currentIndex === 1) appSettings.geminiModel = "gemini-flash-latest";
            else if (geminiModelCombo.currentIndex === 2) appSettings.geminiModel = "gemini-3.7-flash";
            else appSettings.geminiModel = "gemini-3.6-flash";
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
                text: "Audio & Voice"
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
            TabButton {
                text: "AI & Gemini"
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
                        from: 10; to: 150; value: (typeof appSettings !== "undefined") ? Math.round(appSettings.rtlAlt) : 25
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
                        id: autoDetectSwitch
                        checked: (typeof appSettings !== "undefined") ? appSettings.autoDetectAutopilot : true
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Tab 2: Audio & Voice
            ColumnLayout {
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Real-Time Spoken Voice Annunciator"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Announce flight modes, connection changes, low battery, and geofence alarms"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    Switch {
                        id: voiceSwitch
                        checked: (typeof appSettings !== "undefined") ? appSettings.voiceEnabled : true
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Male Voice Profile"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Select masculine voice timbre for cockpit audio annunciations"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    ComboBox {
                        id: voiceProfileCombo
                        implicitWidth: 230
                        textRole: "name"
                        model: ListModel {
                            ListElement { name: "Tactical Commander (Clear Male)"; value: "male1" }
                            ListElement { name: "Deep Cockpit Annunciator"; value: "male2" }
                            ListElement { name: "Aviation Radio Pilot"; value: "male3" }
                            ListElement { name: "Military Synth (Klatt)"; value: "military" }
                        }
                        Component.onCompleted: {
                            var current = (typeof appSettings !== "undefined" && appSettings.maleVoiceProfile) 
                                          ? appSettings.maleVoiceProfile 
                                          : ((typeof audioAnnunciator !== "undefined") ? audioAnnunciator.maleVoiceProfile : "male1");
                            for (var i = 0; i < count; ++i) {
                                if (model.get(i).value === current) {
                                    currentIndex = i;
                                    break;
                                }
                            }
                        }
                        onActivated: {
                            var val = model.get(index).value;
                            if (typeof audioAnnunciator !== "undefined") {
                                audioAnnunciator.maleVoiceProfile = val;
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Audio Synthesizer Audition"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Preview selected male voice profile or trigger a full annunciator check"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    RowLayout {
                        spacing: 8
                        Button {
                            text: "▶ Play Selected Voice"
                            Material.background: "#238636"
                            Material.foreground: "#ffffff"
                            font.bold: true
                            onClicked: {
                                if (typeof audioAnnunciator !== "undefined") {
                                    var sel = voiceProfileCombo.model.get(voiceProfileCombo.currentIndex).value;
                                    audioAnnunciator.testVoiceProfile(sel);
                                }
                            }
                        }
                        Button {
                            text: "🔊 Full Voice Check"
                            Material.background: "#00d4ff"
                            Material.foreground: "#0d1117"
                            font.bold: true
                            onClicked: {
                                if (typeof audioAnnunciator !== "undefined") {
                                    audioAnnunciator.testVoice();
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Tab 3: Telemetry / Link
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

            // Tab 4: Map & Survey
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

            // Tab 5: AI & Gemini
            ColumnLayout {
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Google Gemini AI Engine"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Autonomous Copilot with live UAV telemetry context & full GCS access"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    Rectangle {
                        width: 84; height: 24; radius: 12
                        color: (typeof appSettings !== "undefined" && appSettings.hasGeminiKey) ? "#0e331c" : "#21262d"
                        border.color: (typeof appSettings !== "undefined" && appSettings.hasGeminiKey) ? "#3fb950" : "#d29922"
                        Text {
                            anchors.centerIn: parent
                            text: (typeof appSettings !== "undefined" && appSettings.hasGeminiKey) ? "● Active" : "● Offline"
                            color: (typeof appSettings !== "undefined" && appSettings.hasGeminiKey) ? "#56d364" : "#d29922"
                            font.pixelSize: 10; font.bold: true
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Gemini API Key"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "API key from Google AI Studio (aistudio.google.com)"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 6
                    color: "#0d1117"
                    border.color: geminiKeyField.activeFocus ? "#58a6ff" : "#30363d"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 8

                        TextInput {
                            id: geminiKeyField
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 12
                            color: "#e6edf3"
                            echoMode: showKeyCheck.checked ? TextInput.Normal : TextInput.Password
                            clip: true
                            text: (typeof appSettings !== "undefined") ? appSettings.geminiApiKey : ""

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Enter AI Studio Gemini API Key..."
                                color: "#6e7681"
                                font.pixelSize: 12
                                visible: !geminiKeyField.text && !geminiKeyField.activeFocus
                            }
                        }

                        CheckBox {
                            id: showKeyCheck
                            text: "Show"
                            font.pixelSize: 10
                            Material.foreground: "#8b949e"
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "AI Model"; color: "#e6edf3"; font.pixelSize: 12; font.bold: true }
                        Text { text: "Large language model used for autonomous copilot decisions"; color: "#7d8590"; font.pixelSize: 10 }
                    }
                    ComboBox {
                        id: geminiModelCombo
                        model: ["gemini-3.6-flash (Recommended)", "gemini-flash-latest", "gemini-3.7-flash"]
                        currentIndex: {
                            if (typeof appSettings === "undefined") return 0;
                            if (appSettings.geminiModel.indexOf("latest") !== -1) return 1;
                            if (appSettings.geminiModel.indexOf("3.7") !== -1) return 2;
                            return 0;
                        }
                        font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 6
                    color: "#0d1117"
                    border.color: "#30363d"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Text { text: "🛡️"; font.pixelSize: 18 }
                        Column {
                            Layout.fillWidth: true
                            Text { text: "Full GCS & UAV Autonomous Access Granted"; color: "#e6edf3"; font.pixelSize: 11; font.bold: true }
                            Text { text: "Copilot can command Arm, Disarm, Takeoff, Land, Modes, Geofence, and Missions."; color: "#7d8590"; font.pixelSize: 9 }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
