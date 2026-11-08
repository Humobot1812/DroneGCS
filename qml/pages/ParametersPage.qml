import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// ParametersPage — Unified Vehicle Parameter Subsystem & Quick Flight Tuning (PX4 & ArduPilot)
Rectangle {
    id: root
    color: "#0d1117"

    property var drone: droneManager.activeDrone
    property int dirtyCount: 0
    property bool bannerVisible: false
    property bool bannerSuccess: true

    // Param model (filled from MAVLink PARAM_VALUE messages)
    ListModel { id: paramModel }

    Connections {
        target: drone ? drone : null
        function onParametersChanged() {
            if (!drone || !drone.paramUploadActive) {
                syncParametersFromDrone();
            }
        }
        function onVehicleParamsChanged() {
            // updates quick-tuning bindings automatically
        }
        function onParamUploadComplete(count, success) {
            if (success) {
                for (var i = 0; i < paramModel.count; i++) {
                    paramModel.setProperty(i, "dirty", false);
                }
                dirtyCount = 0;
                showNotification("✓ Parameter uploaded", true);
                if (typeof audioAnnunciator !== "undefined" && audioAnnunciator) {
                    audioAnnunciator.say("Parameter uploaded");
                }
            } else {
                showNotification("Parameter upload completed or encountered empty list.", false);
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // Header & Quick Action Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

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

            // ── PRIMARY ACTION: UPLOAD ALL PARAMETERS AT ONCE TO DRONE ──
            Button {
                id: uploadAllBtn
                Layout.preferredHeight: 34
                font.pixelSize: 11
                font.bold: true
                Material.background: (drone && drone.paramUploadActive) ? "#1f6feb" : (dirtyCount > 0 ? "#2ea043" : "#238636")
                enabled: !(drone && drone.paramUploadActive)
                contentItem: Row {
                    spacing: 6
                    anchors.centerIn: parent
                    Text {
                        text: (drone && drone.paramUploadActive) ? "⏳" : "⬆"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (drone && drone.paramUploadActive)
                              ? ("Uploading (" + drone.paramUploadCurrent + "/" + drone.paramUploadTotal + ")...")
                              : ("Upload All to Drone (" + paramModel.count + ")")
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: "Update all parameters at once in the drone autopilot memory"
                onClicked: {
                    uploadAllParametersToDrone();
                }
            }

            // ── Add / Edit Parameter Button ──
            Button {
                id: addParamBtn
                Layout.preferredHeight: 34
                font.pixelSize: 11
                font.bold: true
                Material.background: "#21262d"
                contentItem: Row {
                    spacing: 6
                    anchors.centerIn: parent
                    Text {
                        text: "＋"
                        color: "#00d4ff"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Add Parameter"
                        color: "#e6edf3"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: "Add a new parameter to the list before uploading to vehicle"
                onClicked: {
                    uploadParamDialog.openDialog();
                }
            }

            // ── Refresh / Sync Parameters Button ──
            Button {
                text: "🔄 Sync From Drone"
                Layout.preferredHeight: 34
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
                ToolTip.visible: hovered
                ToolTip.text: "Request complete onboard parameter tree via MAVLink PARAM_REQUEST_LIST"
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
                width: 190
                height: 34
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

        // ── Active Batch Upload Progress Bar ───────────────────────────────────
        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            visible: drone && drone.paramUploadActive
            from: 0
            to: 1
            value: drone ? drone.paramUploadProgress : 0
            Material.accent: "#2ea043"
        }

        // ── Direct Notification Banner ────────────────────────────────────────
        Rectangle {
            id: notificationBanner
            Layout.fillWidth: true
            Layout.preferredHeight: bannerVisible ? 40 : 0
            visible: bannerVisible
            clip: true
            color: bannerSuccess ? "#132d1d" : "#3d1a1a"
            border.color: bannerSuccess ? "#3fb950" : "#f85149"
            border.width: 1
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: bannerSuccess ? "✓" : "⚠"
                    font.pixelSize: 14
                    font.bold: true
                    color: bannerSuccess ? "#3fb950" : "#f85149"
                }
                Text {
                    id: bannerText
                    text: ""
                    font.pixelSize: 12
                    font.bold: true
                    color: "#e6edf3"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: bannerSuccess ? "#1f3b28" : "#4c2020"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 11
                        font.bold: true
                        color: bannerSuccess ? "#56d364" : "#ff7b72"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bannerVisible = false
                    }
                }
            }
        }

        Timer {
            id: bannerTimer
            interval: 5000
            repeat: false
            onTriggered: bannerVisible = false
        }

        // ── Quick Flight Tuning Panel (PX4 + ArduPilot Unified) ────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 94
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
            Layout.preferredHeight: 30
            height: 30
            color: "#161b22"
            radius: 4
            border.color: "#21262d"
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                Text { text: "PARAMETER NAME"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 200 }
                Text { text: "VALUE"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 130 }
                Text { text: "TYPE"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 80 }
                Text { text: "DESCRIPTION / CONTEXT"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.fillWidth: true }
                Text { text: "ACTION"; color: "#7d8590"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignHCenter }
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
                    text: "Click '+ Add Parameter' or 'Sync From Drone' to populate and upload"
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
                id: rowDelegate
                width: paramListView.width
                height: 38
                color: model.dirty ? "#1e1b10" : (index % 2 === 0 ? "#0d1117" : "#13171f")
                border.color: model.dirty ? "#d29922" : "transparent"
                border.width: model.dirty ? 1 : 0

                property bool editing: false

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    // Name
                    Row {
                        Layout.preferredWidth: 200
                        spacing: 6
                        Text {
                            text: model.name
                            font.pixelSize: 12
                            font.bold: model.dirty
                            font.family: "JetBrains Mono, monospace"
                            color: model.dirty ? "#d29922" : "#e6edf3"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            height: 16
                            width: 52
                            radius: 3
                            color: "#3e2e12"
                            border.color: "#d29922"
                            border.width: 1
                            visible: model.dirty
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "MODIFIED"
                                font.pixelSize: 8
                                font.bold: true
                                color: "#d29922"
                                anchors.centerIn: parent
                            }
                        }
                    }

                    // Value (click to edit)
                    Rectangle {
                        Layout.preferredWidth: 130
                        height: 26
                        radius: 4
                        color: editing ? "#21262d" : (model.dirty ? "#2a2412" : "transparent")
                        border.color: editing ? "#00d4ff" : (model.dirty ? "#d29922" : "transparent")
                        border.width: 1

                        TextInput {
                            id: valueInput
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: model.value
                            color: model.dirty ? "#f0883e" : "#00d4ff"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrains Mono, monospace"
                            verticalAlignment: TextInput.AlignVCenter
                            readOnly: !editing
                            selectByMouse: true
                            Keys.onReturnPressed: {
                                var val = text.trim();
                                var floatVal = parseFloat(val);
                                if (!isNaN(floatVal)) {
                                    paramModel.setProperty(index, "value", val);
                                    paramModel.setProperty(index, "dirty", true);
                                    updateDirtyCount();
                                    editing = false;
                                }
                            }
                            Keys.onEscapePressed: {
                                text = model.value;
                                editing = false;
                            }
                            onEditingFinished: {
                                if (editing) {
                                    var val = text.trim();
                                    if (val !== model.value) {
                                        paramModel.setProperty(index, "value", val);
                                        paramModel.setProperty(index, "dirty", true);
                                        updateDirtyCount();
                                    }
                                    editing = false;
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            visible: !editing
                            onDoubleClicked: {
                                editing = true;
                                valueInput.forceActiveFocus();
                                valueInput.selectAll();
                            }
                        }
                    }

                    // Type
                    Text {
                        text: model.type
                        font.pixelSize: 10
                        font.family: "JetBrains Mono, monospace"
                        color: "#7d8590"
                        Layout.preferredWidth: 80
                    }

                    // Description
                    Text {
                        text: model.description || ""
                        font.pixelSize: 11
                        color: "#7d8590"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Direct Upload Action Button per Row
                    Item {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 26

                        Button {
                            anchors.centerIn: parent
                            width: 82
                            height: 24
                            font.pixelSize: 10
                            font.bold: true
                            Material.background: model.dirty ? "#238636" : "#21262d"
                            contentItem: Row {
                                spacing: 4
                                anchors.centerIn: parent
                                Text {
                                    text: "⬆"
                                    color: model.dirty ? "#ffffff" : "#00d4ff"
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: model.dirty ? "Upload" : "Write"
                                    color: model.dirty ? "#ffffff" : "#00d4ff"
                                    font.pixelSize: 10
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Upload " + model.name + " (" + model.value + ") directly to drone memory"
                            onClicked: {
                                uploadSingleParam(index);
                            }
                        }
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

    // ── Add / Edit Parameter Modal Dialog ─────────────────────────────────────
    Dialog {
        id: uploadParamDialog
        width: 490
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

        function openDialog(initialName, initialVal) {
            paramNameInput.text = initialName ? initialName.toUpperCase() : "";
            paramValInput.text = initialVal !== undefined ? String(initialVal) : "";
            validationWarning.text = "";
            open();
            paramNameInput.forceActiveFocus();
        }

        contentItem: ColumnLayout {
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: "#0d1117"
                radius: 8
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 8
                    color: "#0d1117"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "Add Vehicle Parameter"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#e6edf3"
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 22
                        width: targetBadgeTxt.implicitWidth + 14
                        radius: 4
                        color: drone ? "#1f3b58" : "#3e2424"
                        border.color: drone ? "#58a6ff" : "#f85149"
                        border.width: 1
                        Text {
                            id: targetBadgeTxt
                            text: drone ? (drone.name + " • SYS " + drone.sysId) : "NO VEHICLE"
                            font.pixelSize: 10
                            font.bold: true
                            color: drone ? "#58a6ff" : "#f85149"
                            anchors.centerIn: parent
                        }
                    }

                    Text {
                        text: "✕"
                        font.pixelSize: 14
                        color: "#7d8590"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: uploadParamDialog.close()
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

            // Body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12

                Text {
                    text: "Add or modify a vehicle parameter. You can save to the list and update all at once."
                    font.pixelSize: 11
                    color: "#8b949e"
                }

                // Parameter Name Input
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "PARAMETER NAME / ID (max 16 chars)"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#7d8590"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: paramNameInput.text.length + " / 16"
                            font.pixelSize: 9
                            color: paramNameInput.text.length > 16 ? "#f85149" : "#7d8590"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 5
                        color: "#0d1117"
                        border.color: paramNameInput.activeFocus ? "#00d4ff" : "#30363d"
                        border.width: 1

                        TextInput {
                            id: paramNameInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6edf3"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "JetBrains Mono, monospace"
                            font.capitalization: Font.AllUppercase
                            maximumLength: 16
                            selectByMouse: true
                            Keys.onReturnPressed: paramValInput.forceActiveFocus()
                        }
                    }

                    // Autocomplete Quick Presets
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: (drone && drone.autopilotType === "PX4") ?
                                ["MPC_XY_CRUISE", "MPC_LAND_SPEED", "MPC_YAWRAUTO_MAX", "GF_ACTION", "MIS_TAKEOFF_ALT"] :
                                ["WPNAV_SPEED", "RTL_ALT", "RTL_SPEED", "WPNAV_YAW_RATE", "BATT_ARM_VOLT", "FENCE_ACTION"]
                            delegate: Rectangle {
                                height: 22
                                width: chipText.implicitWidth + 12
                                radius: 4
                                color: "#21262d"
                                border.color: "#30363d"
                                border.width: 1
                                Text {
                                    id: chipText
                                    text: modelData
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "JetBrains Mono, monospace"
                                    color: "#58a6ff"
                                    anchors.centerIn: parent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: parent.color = "#30363d"
                                    onExited: parent.color = "#21262d"
                                    onClicked: {
                                        paramNameInput.text = modelData;
                                        paramValInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // Value & Type Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Value
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "VALUE (NUMERIC)"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#7d8590"
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 5
                            color: "#0d1117"
                            border.color: paramValInput.activeFocus ? "#00d4ff" : "#30363d"
                            border.width: 1

                            TextInput {
                                id: paramValInput
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#00d4ff"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "JetBrains Mono, monospace"
                                selectByMouse: true
                                Keys.onReturnPressed: doSave(true)
                            }
                        }
                    }

                    // Type
                    ColumnLayout {
                        Layout.preferredWidth: 140
                        spacing: 4
                        Text {
                            text: "PARAM TYPE"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#7d8590"
                        }
                        ComboBox {
                            id: paramTypeCombo
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 36
                            model: ["REAL32 (Float)", "INT32", "INT16", "INT8"]
                            Material.background: "#0d1117"
                            Material.accent: "#00d4ff"
                        }
                    }
                }

                // Description Box
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 4
                    color: "#0d1117"
                    border.color: "#21262d"
                    border.width: 1
                    visible: getParamDescription(paramNameInput.text.trim().toUpperCase()).length > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        Text {
                            text: "ℹ " + getParamDescription(paramNameInput.text.trim().toUpperCase())
                            color: "#58a6ff"
                            font.pixelSize: 10
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                // Validation Warning
                Text {
                    id: validationWarning
                    text: ""
                    color: "#f85149"
                    font.pixelSize: 11
                    font.bold: true
                    visible: text.length > 0
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#21262d" }

            // Footer
            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: "#0d1117"
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Cancel"
                        Layout.preferredHeight: 32
                        font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text
                            color: "#8b949e"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: uploadParamDialog.close()
                    }

                    Button {
                        text: "Add to List"
                        Layout.preferredHeight: 32
                        font.pixelSize: 11
                        Material.background: "#21262d"
                        contentItem: Text {
                            text: parent.text
                            color: "#00d4ff"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: doSave(false)
                    }

                    Button {
                        text: "⬆ Add & Upload All"
                        Layout.preferredHeight: 32
                        font.pixelSize: 11
                        font.bold: true
                        Material.background: "#238636"
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: doSave(true)
                    }
                }
            }
        }

        function doSave(andUploadAll) {
            var name = paramNameInput.text.trim().toUpperCase();
            var valStr = paramValInput.text.trim();
            if (name.length === 0) {
                validationWarning.text = "Error: Please enter a parameter name.";
                return;
            }
            var floatVal = parseFloat(valStr);
            if (isNaN(floatVal)) {
                validationWarning.text = "Error: Value must be a valid numeric value.";
                return;
            }

            // Update or insert into paramModel
            var found = false;
            for (var i = 0; i < paramModel.count; i++) {
                var item = paramModel.get(i);
                if (item.name === name) {
                    paramModel.setProperty(i, "value", String(floatVal));
                    paramModel.setProperty(i, "dirty", true);
                    found = true;
                    break;
                }
            }
            if (!found) {
                paramModel.insert(0, {
                    name: name,
                    value: String(floatVal),
                    type: paramTypeCombo.currentText.split(" ")[0],
                    description: getParamDescription(name),
                    dirty: true
                });
            }

            updateDirtyCount();
            uploadParamDialog.close();

            if (andUploadAll) {
                uploadAllParametersToDrone();
            } else {
                showNotification("Parameter added to list", true);
            }
        }
    }

    // ── Helper Functions ──────────────────────────────────────────────────────
    function showNotification(msg, success) {
        bannerText.text = msg;
        bannerSuccess = (success !== undefined) ? success : true;
        bannerVisible = true;
        bannerTimer.restart();
    }

    function updateDirtyCount() {
        var cnt = 0;
        for (var i = 0; i < paramModel.count; i++) {
            if (paramModel.get(i).dirty) cnt++;
        }
        dirtyCount = cnt;
    }

    // Main function: Uploads all parameters at once to the drone
    function uploadAllParametersToDrone() {
        if (!drone) {
            showNotification("Error: No vehicle connected to receive parameters.", false);
            return;
        }
        if (paramModel.count === 0) {
            showNotification("Error: No parameters available to upload.", false);
            return;
        }

        var list = [];
        for (var i = 0; i < paramModel.count; i++) {
            var item = paramModel.get(i);
            var typeCode = 9; // REAL32 default
            if (item.type === "INT32") typeCode = 6;
            else if (item.type === "INT16") typeCode = 4;
            else if (item.type === "INT8") typeCode = 2;

            var fVal = parseFloat(item.value);
            if (isNaN(fVal)) fVal = 0.0;

            list.push({
                name: item.name,
                value: fVal,
                typeCode: typeCode
            });
        }

        showNotification("Uploading parameters to vehicle...", true);
        drone.uploadAllParameters(list);
    }

    function uploadSingleParam(idx) {
        if (!drone) {
            showNotification("Error: No vehicle connected.", false);
            return;
        }
        if (idx < 0 || idx >= paramModel.count) return;
        var item = paramModel.get(idx);
        var floatVal = parseFloat(item.value);
        if (isNaN(floatVal)) {
            showNotification("Error: Invalid numeric value for " + item.name, false);
            return;
        }
        drone.setParam(item.name, floatVal);
        paramModel.setProperty(idx, "dirty", false);
        updateDirtyCount();

        showNotification("✓ Parameter uploaded", true);

        if (typeof audioAnnunciator !== "undefined" && audioAnnunciator) {
            audioAnnunciator.say("Parameter uploaded");
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
        dirtyCount = 0;
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
        dirtyCount = 0;
    }

    function getParamDescription(name) {
        // High-value quick dictionary for ArduPilot & PX4
        var dict = {
            "MPC_XY_CRUISE": "PX4 Return & autonomous mission cruise speed (m/s)",
            "MPC_LAND_SPEED": "PX4 Descend and touchdown landing velocity (m/s)",
            "MPC_YAWRAUTO_MAX": "PX4 Max auto-flight yaw turning speed (deg/s)",
            "MC_YAWRATE_MAX": "PX4 Max manual/attitude yaw speed (deg/s)",
            "MPC_YAW_MODE": "PX4 Waypoint yaw heading mode (0=Towards WP, 4=Fixed)",
            "MIS_TAKEOFF_ALT": "PX4 Automatic mission takeoff altitude target (m)",
            "GF_ACTION": "PX4 Geofence breach action (1=Warn, 2=Hold, 3=RTL, 4=Land)",
            "GF_MAX_HOR_DIST": "PX4 Geofence maximum horizontal radius from Home (m)",
            "GF_MAX_VER_DIST": "PX4 Geofence maximum altitude ceiling (m)",
            "RTL_ALT": "ArduPilot Return-to-Launch return altitude (cm or m)",
            "RTL_SPEED": "ArduPilot Return-to-Launch cruise speed (cm/s, 0=WPNAV)",
            "WPNAV_SPEED": "ArduPilot Waypoint navigation speed (cm/s)",
            "WPNAV_RADIUS": "ArduPilot Waypoint arrival acceptance radius (cm)",
            "WPNAV_YAW_RATE": "ArduPilot Navigation yaw turning rate (deg/s)",
            "WP_YAW_BEHAVIOR": "ArduPilot Auto-yaw waypoint facing behavior (1=Face WP, 0=None)",
            "BATT_ARM_VOLT": "ArduPilot Minimum battery voltage to allow arming (V)",
            "BATT_CAPACITY": "ArduPilot Battery capacity (mAh)",
            "BATT_LOW_VOLT": "ArduPilot Low battery warning failsafe voltage (V)",
            "BATT_CRT_VOLT": "ArduPilot Critical battery failsafe return voltage (V)",
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
        dirtyCount = 0;
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
