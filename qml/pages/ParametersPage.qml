import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// ParametersPage — Unified Vehicle Parameter Subsystem & Quick Flight Tuning (PX4 & ArduPilot)
Rectangle {
    id: root
    color: "#0d1117"

    property var drone: droneManager.activeDrone

    // Param model (filled from MAVLink PARAM_VALUE messages)
    ListModel { id: paramModel }

    Connections {
        target: drone ? drone : null
        function onParametersChanged() {
            syncParametersFromDrone();
        }
        function onVehicleParamsChanged() {
            // updates quick-tuning bindings automatically
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // Header & Quick Action Bar
        RowLayout {
            Layout.fillWidth: true

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter
                Text {
                    text: "Vehicle Parameters & Tuning"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#e6edf3"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    height: 22
                    width: countTxt.implicitWidth + 14
                    radius: 4
                    color: "#21262d"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: countTxt
                        text: (drone ? drone.parameterCount : paramModel.count) + " PARAMS"
                        font.pixelSize: 9
                        font.bold: true
                        color: "#58a6ff"
                        anchors.centerIn: parent
                    }
                }
                Rectangle {
                    height: 22
                    width: apBadgeTxt.implicitWidth + 14
                    radius: 4
                    color: drone && drone.autopilotType === "PX4" ? "#1f3b58" : "#23452c"
                    border.color: drone && drone.autopilotType === "PX4" ? "#58a6ff" : "#3fb950"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: drone && drone.autopilotType.length > 0
                    Text {
                        id: apBadgeTxt
                        text: drone ? (drone.autopilotType + " ACTIVE") : ""
                        font.pixelSize: 9
                        font.bold: true
                        color: drone && drone.autopilotType === "PX4" ? "#58a6ff" : "#3fb950"
                        anchors.centerIn: parent
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Refresh Parameters Button
            Button {
                text: "🔄 Sync From Drone"
                Layout.preferredHeight: 32
                font.pixelSize: 11
                font.bold: true
                Material.background: "#21262d"
                contentItem: Text {
                    text: parent.text
                    color: "#00d4ff"
                    font: parent.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (drone) {
                        statusLabel.text = "Requesting complete parameter tree from drone SYS:" + drone.sysId + "...";
                        drone.requestAllParameters();
                    } else {
                        statusLabel.text = "No vehicle connected.";
                    }
                }
            }

            // Search Box
            Rectangle {
                width: 240
                height: 32
                radius: 5
                color: "#161b22"
                border.color: searchField.activeFocus ? "#00d4ff" : "#30363d"
                border.width: 1

                Row {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text {
                        text: "⌕"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#7d8590"
                    }
                    TextInput {
                        id: searchField
                        width: parent.parent.width - 40
                        height: parent.parent.height
                        color: "#e6edf3"
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        Keys.onReturnPressed: filterParams()
                        onTextChanged: filterParams()
                    }
                }
            }
        }

        // ── Quick Flight Tuning Panel (PX4 + ArduPilot Unified) ────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 94
            radius: 8
            color: "#161b22"
            border.color: "#30363d"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "⚡ Quick Flight Dynamics Tuning (Unified Autopilot Controls)"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#e6edf3"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: drone ? ("Autopilot: " + drone.autopilotType) : "Vehicle Disconnected"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#7d8590"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // 1. RTL Speed
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: "#0d1117"
                        border.color: "#21262d"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Column {
                                Layout.fillWidth: true
                                Text { text: "Return-to-Launch Speed"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                                Text {
                                    text: (drone && drone.autopilotType === "PX4") ? "Sets MPC_XY_CRUISE" : "Sets RTL_SPEED / WPNAV"
                                    font.pixelSize: 9
                                    color: "#58a6ff"
                                }
                            }
                            SpinBox {
                                id: rtlSpeedSpin
                                from: 1; to: 25; stepSize: 1
                                value: drone ? Math.round(drone.rtlSpeed) : 5
                                editable: true
                                Layout.preferredWidth: 105
                                Layout.preferredHeight: 32
                                onValueModified: {
                                    if (drone) drone.setRtlSpeed(value);
                                }
                            }
                            Text { text: "m/s"; font.pixelSize: 11; color: "#8b949e" }
                        }
                    }

                    // 2. Yaw Turn Speed
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: "#0d1117"
                        border.color: "#21262d"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Column {
                                Layout.fillWidth: true
                                Text { text: "Yaw Turn Rate"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                                Text {
                                    text: (drone && drone.autopilotType === "PX4") ? "Sets MPC_YAWRAUTO_MAX" : "Sets WPNAV_YAW_RATE"
                                    font.pixelSize: 9
                                    color: "#58a6ff"
                                }
                            }
                            SpinBox {
                                id: yawRateSpin
                                from: 10; to: 180; stepSize: 5
                                value: drone ? Math.round(drone.yawRate) : 45
                                editable: true
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 32
                                onValueModified: {
                                    if (drone) drone.setYawRate(value);
                                }
                            }
                            Text { text: "deg/s"; font.pixelSize: 11; color: "#8b949e" }
                        }
                    }

                    // 3. Auto-Yaw On/Off Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: "#0d1117"
                        border.color: "#21262d"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Column {
                                Layout.fillWidth: true
                                Text { text: "Auto-Yaw (Face Waypoint)"; font.pixelSize: 11; font.bold: true; color: "#e6edf3" }
                                Text {
                                    text: (drone && drone.autopilotType === "PX4") ? "MPC_YAW_MODE (0 vs 4)" : "WP_YAW_BEHAVIOR (1 vs 0)"
                                    font.pixelSize: 9
                                    color: autoYawSwitch.checked ? "#3fb950" : "#d29922"
                                }
                            }
                            Switch {
                                id: autoYawSwitch
                                checked: drone ? drone.autoYawEnabled : true
                                onToggled: {
                                    if (drone) drone.setAutoYawEnabled(checked);
                                }
                            }
                            Text {
                                text: autoYawSwitch.checked ? "ON" : "OFF"
                                font.pixelSize: 11
                                font.bold: true
                                color: autoYawSwitch.checked ? "#3fb950" : "#8b949e"
                            }
                        }
                    }
                }
            }
        }

        // Column headers
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#161b22"
            radius: 4
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text { text: "PARAMETER NAME"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 220 }
                Text { text: "VALUE"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 140 }
                Text { text: "TYPE"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 90 }
                Text { text: "DESCRIPTION / CONTEXT"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true }
            }
        }

        // Empty state
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            visible: paramModel.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "≡"
                    font.pixelSize: 36
                    color: "#30363d"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "No Parameters Loaded"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#8b949e"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Connect to a vehicle or click 'Sync From Drone' to fetch all onboard parameters"
                    font.pixelSize: 11
                    color: "#484f58"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Parameter list
        ListView {
            id: paramListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: paramModel
            visible: paramModel.count > 0

            delegate: Rectangle {
                width: paramListView.width
                height: 38
                color: index % 2 === 0 ? "#0d1117" : "#13171f"

                property bool editing: false

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    // Name
                    Text {
                        text: model.name
                        font.pixelSize: 12
                        font.family: "JetBrains Mono, monospace"
                        color: model.dirty ? "#d29922" : "#e6edf3"
                        Layout.preferredWidth: 220
                    }

                    // Value (click to edit)
                    Rectangle {
                        Layout.preferredWidth: 140
                        height: 26
                        radius: 4
                        color: editing ? "#21262d" : "transparent"
                        border.color: editing ? "#00d4ff" : "transparent"
                        border.width: 1

                        TextInput {
                            id: valueInput
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: model.value
                            color: "#00d4ff"
                            font.pixelSize: 12
                            font.family: "JetBrains Mono, monospace"
                            verticalAlignment: TextInput.AlignVCenter
                            readOnly: !editing
                            Keys.onReturnPressed: {
                                applyParam(model.name, text);
                                editing = false;
                            }
                            Keys.onEscapePressed: {
                                text = model.value;
                                editing = false;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onDoubleClicked: { editing = true; valueInput.forceActiveFocus(); valueInput.selectAll() }
                        }
                    }

                    // Type
                    Text {
                        text: model.type
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: "#7d8590"
                        Layout.preferredWidth: 90
                    }

                    // Description
                    Text {
                        text: model.description || ""
                        font.pixelSize: 11
                        color: "#7d8590"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Status bar
        Text {
            id: statusLabel
            text: drone ? (paramModel.count + " parameters active (" + drone.autopilotType + ").") : "No drone connected."
            color: "#7d8590"
            font.pixelSize: 11
            font.family: "JetBrains Mono, monospace"
        }
    }

    function syncParametersFromDrone() {
        if (!drone) return;
        var pMap = drone.parameters;
        var keys = Object.keys(pMap).sort();
        if (keys.length === 0) return;

        paramModel.clear();
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            var v = pMap[k];
            var desc = getParamDescription(k);
            paramModel.append({
                name: k,
                value: String(v),
                type: (typeof v === "number" && v % 1 !== 0) ? "REAL32" : "INT32",
                description: desc,
                dirty: false
            });
        }
        statusLabel.text = keys.length + " vehicle parameters synchronized from " + drone.name;
    }

    function filterParams() {
        if (!drone || drone.parameterCount === 0) return;
        var q = searchField.text.toUpperCase().trim();
        var pMap = drone.parameters;
        var keys = Object.keys(pMap).sort();

        paramModel.clear();
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (q.length === 0 || k.indexOf(q) !== -1) {
                var v = pMap[k];
                paramModel.append({
                    name: k,
                    value: String(v),
                    type: (typeof v === "number" && v % 1 !== 0) ? "REAL32" : "INT32",
                    description: getParamDescription(k),
                    dirty: false
                });
            }
        }
    }

    function applyParam(name, value) {
        if (!drone) return;
        var floatVal = parseFloat(value);
        if (isNaN(floatVal)) return;

        drone.setParam(name, floatVal);
        statusLabel.text = "Set " + name + " = " + floatVal;
    }

    function getParamDescription(name) {
        // High-value quick dictionary for ArduPilot & PX4
        var dict = {
            "MPC_XY_CRUISE": "PX4 Return & autonomous mission cruise speed (m/s)",
            "MPC_YAWRAUTO_MAX": "PX4 Max auto-flight yaw turning speed (deg/s)",
            "MC_YAWRATE_MAX": "PX4 Max manual/attitude yaw speed (deg/s)",
            "MPC_YAW_MODE": "PX4 Waypoint yaw heading mode (0=Towards WP, 4=Fixed)",
            "GF_ACTION": "PX4 Geofence breach action (1=Warn, 2=Hold, 3=RTL, 4=Land)",
            "GF_MAX_HOR_DIST": "PX4 Geofence maximum horizontal radius from Home (m)",
            "GF_MAX_VER_DIST": "PX4 Geofence maximum altitude ceiling (m)",
            "RTL_SPEED": "ArduPilot Return-to-Launch cruise speed (cm/s, 0=WPNAV)",
            "WPNAV_SPEED": "ArduPilot Waypoint navigation speed (cm/s)",
            "WPNAV_YAW_RATE": "ArduPilot Navigation yaw turning rate (deg/s)",
            "WP_YAW_BEHAVIOR": "ArduPilot Auto-yaw waypoint facing behavior (1=Face WP, 0=None)",
            "FENCE_ENABLE": "ArduPilot Master geofence safety switch (1=Enabled)",
            "FENCE_ACTION": "ArduPilot Breach action (0=Warn, 1=RTL, 2=Land, 3=Loiter)",
            "FENCE_RADIUS": "ArduPilot Circular boundary radius around Home (m)",
            "FENCE_ALT_MAX": "ArduPilot Altitude ceiling boundary (m)",
            "FENCE_ALT_MIN": "ArduPilot Altitude floor boundary (m)"
        };
        return dict[name] || "";
    }

    function loadDefaultParams() {
        if (drone && drone.parameterCount > 0) {
            syncParametersFromDrone();
            return;
        }

        paramModel.clear();
        var defaults = [
            { name: "MPC_XY_CRUISE",   value: "5.0",   type: "REAL32", description: "PX4 Return & cruise speed (m/s)", dirty: false },
            { name: "MPC_YAWRAUTO_MAX",value: "45.0",  type: "REAL32", description: "PX4 Max auto yaw rate (deg/s)",  dirty: false },
            { name: "MPC_YAW_MODE",    value: "0",     type: "INT32",  description: "PX4 Waypoint yaw mode (0=Towards WP)", dirty: false },
            { name: "GF_ACTION",       value: "3",     type: "INT32",  description: "PX4 Geofence breach action (3=RTL)", dirty: false },
            { name: "GF_MAX_HOR_DIST", value: "300",   type: "REAL32", description: "PX4 Geofence max horizontal distance (m)", dirty: false },
            { name: "RTL_SPEED",       value: "500",   type: "INT16",  description: "ArduPilot RTL speed (cm/s)",      dirty: false },
            { name: "WPNAV_SPEED",     value: "500",   type: "INT16",  description: "ArduPilot Waypoint speed (cm/s)",  dirty: false },
            { name: "WPNAV_YAW_RATE",  value: "45",    type: "REAL32", description: "ArduPilot Waypoint yaw rate (deg/s)", dirty: false },
            { name: "WP_YAW_BEHAVIOR", value: "1",     type: "INT8",   description: "ArduPilot Auto-yaw (1=Face WP)",  dirty: false },
            { name: "FENCE_ENABLE",    value: "1",     type: "INT8",   description: "ArduPilot Geofence enable",       dirty: false },
            { name: "FENCE_ACTION",    value: "1",     type: "INT8",   description: "ArduPilot Geofence action (1=RTL)", dirty: false },
            { name: "FENCE_RADIUS",    value: "300",   type: "REAL32", description: "ArduPilot Circular fence radius (m)", dirty: false }
        ];
        for (var i = 0; i < defaults.length; i++) paramModel.append(defaults[i]);
        statusLabel.text = defaults.length + " default tuning parameters loaded.";
    }

    Component.onCompleted: loadDefaultParams()

    onDroneChanged: {
        if (drone && drone.parameterCount > 0) {
            syncParametersFromDrone();
        } else {
            loadDefaultParams();
        }
    }
}
