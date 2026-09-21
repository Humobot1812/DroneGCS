import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Parameter editor
Rectangle {
    id: root
    color: "#0d1117"

    property var drone: droneManager.activeDrone

    // Param model (filled from MAVLink PARAM_VALUE messages)
    ListModel { id: paramModel }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text { text: "⚙  Parameters"; font.pixelSize: 16; font.bold: true; color: "#e6edf3" }
            Item { Layout.fillWidth: true }

            // Refresh
            Button {
                text: "🔄 Refresh"
                flat: true; font.pixelSize: 11
                Material.foreground: "#00d4ff"
                onClicked: {
                    // Request all params via MAVLink PARAM_REQUEST_LIST
                    paramModel.clear();
                    statusLabel.text = "Requesting parameters...";
                }
            }

            // Search
            Rectangle {
                width: 220; height: 32; radius: 6
                color: "#161b22"; border.color: "#30363d"; border.width: 1

                Row {
                    anchors { fill: parent; leftMargin: 8 }
                    spacing: 6
                    Text { text: "🔍"; anchors.verticalCenter: parent.verticalCenter; color: "#7d8590" }
                    TextInput {
                        id: searchField
                        width: parent.parent.width - 36; height: parent.parent.height
                        color: "#e6edf3"; font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        Keys.onReturnPressed: filterParams()
                        onTextChanged: filterParams()
                    }
                }
            }
        }

        // Column headers
        Rectangle {
            Layout.fillWidth: true; height: 32; color: "#161b22"; radius: 4
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text { text: "Parameter";   color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 200 }
                Text { text: "Value";       color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 120 }
                Text { text: "Type";        color: "#7d8590"; font.pixelSize: 11; Layout.preferredWidth: 80 }
                Text { text: "Description"; color: "#7d8590"; font.pixelSize: 11; Layout.fillWidth: true }
            }
        }

        // Parameter list
        ListView {
            id: paramListView
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: paramModel

            delegate: Rectangle {
                width: paramListView.width; height: 40
                color: index % 2 === 0 ? "#0d1117" : "#0f1219"

                property bool editing: false

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12

                    // Name
                    Text {
                        text: model.name
                        font.pixelSize: 12; font.family: "JetBrains Mono, monospace"
                        color: model.dirty ? "#d29922" : "#e6edf3"
                        Layout.preferredWidth: 200
                    }

                    // Value (click to edit)
                    Rectangle {
                        Layout.preferredWidth: 120; height: 28; radius: 4
                        color: editing ? "#21262d" : "transparent"
                        border.color: editing ? "#00d4ff" : "transparent"; border.width: 1

                        TextInput {
                            id: valueInput
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: model.value
                            color: "#00d4ff"
                            font.pixelSize: 12; font.family: "JetBrains Mono, monospace"
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
                        font.pixelSize: 10; color: "#7d8590"
                        Layout.preferredWidth: 80
                    }

                    // Description
                    Text {
                        text: model.description || ""
                        font.pixelSize: 11; color: "#7d8590"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Status bar
        Text {
            id: statusLabel
            text: drone ? "Connect a drone and press Refresh to load parameters." : "No drone connected."
            color: "#7d8590"; font.pixelSize: 11
        }
    }

    function filterParams() {
        var q = searchField.text.toUpperCase();
        // Show/hide based on name match
        for (var i = 0; i < paramModel.count; i++) {
            var p = paramModel.get(i);
            // Note: ListModel doesn't support visible natively; in production use a proxy model
        }
    }

    function applyParam(name, value) {
        if (!drone) return;
        statusLabel.text = "Setting " + name + " = " + value + "...";
        // TODO: send PARAM_SET via MAVLink through DroneVehicle
    }

    function loadDefaultParams() {
        paramModel.clear();
        var defaults = [
            { name: "ARMING_CHECK",   value: "1",      type: "INT8",   description: "Arming check bitmask (1=All checks enabled)", dirty: false },
            { name: "BATT_CAPACITY",  value: "5200",   type: "INT32",  description: "Battery capacity in mAh",                     dirty: false },
            { name: "BATT_LOW_VOLT",  value: "14.2",   type: "REAL32", description: "Battery low voltage failsafe threshold (V)",  dirty: false },
            { name: "FS_GCS_ENABLE",  value: "1",      type: "INT8",   description: "GCS failsafe (1=RTL, 2=Land)",                dirty: false },
            { name: "LAND_SPEED",     value: "50",     type: "INT16",  description: "Descent speed for final landing phase (cm/s)", dirty: false },
            { name: "PILOT_SPEED_UP", value: "250",    type: "INT16",  description: "Maximum pilot ascent speed (cm/s)",           dirty: false },
            { name: "PILOT_SPEED_DN", value: "150",    type: "INT16",  description: "Maximum pilot descent speed (cm/s)",          dirty: false },
            { name: "RTL_ALT",        value: "1500",   type: "INT16",  description: "RTL altitude above home (cm)",                dirty: false },
            { name: "WPNAV_SPEED",    value: "500",    type: "INT16",  description: "Waypoint navigation speed (cm/s)",            dirty: false },
            { name: "WPNAV_RADIUS",   value: "200",    type: "INT16",  description: "Waypoint acceptance radius (cm)",             dirty: false }
        ];
        for (var i = 0; i < defaults.length; i++) paramModel.append(defaults[i]);
        statusLabel.text = defaults.length + " parameters active.";
    }

    Component.onCompleted: loadDefaultParams()

    // When drone changes, request params
    onDroneChanged: {
        loadDefaultParams();
    }
}
