import QtQuick 2.15

// Simple LED indicator with label
Item {
    id: root
    width: row.width; height: 38
    implicitWidth: row.width; implicitHeight: 38
    property bool active: false
    property color color: "#00d4ff"
    property string label: ""

    Row {
        id: row
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            color: root.active ? root.color : "#30363d"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            text: root.label
            font.pixelSize: 16
            font.bold: true
            color: root.active ? "#e6edf3" : "#8b949e"
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
