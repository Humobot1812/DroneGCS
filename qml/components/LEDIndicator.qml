import QtQuick 2.15

// Simple LED indicator with label
Item {
    id: root
    width: row.width; height: 22
    implicitWidth: row.width; implicitHeight: 22
    property bool active: false
    property color color: "#00d4ff"
    property string label: ""

    Row {
        id: row
        spacing: 6

        Rectangle {
            width: 8; height: 8; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: root.active ? root.color : "#30363d"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            text: root.label
            font.pixelSize: 12
            font.bold: true
            color: root.active ? "#e6edf3" : "#8b949e"
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
