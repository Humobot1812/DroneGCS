import QtQuick 2.15
import QtQuick.Controls 2.15

// SlideToConfirm — Two-stage safety confirmation slider with Spacebar hold-to-confirm
Item {
    id: root
    implicitWidth: 320
    implicitHeight: 46
    focus: true

    property string label: "SLIDE TO CONFIRM"
    property string iconText: "➔"
    property color accentColor: "#3fb950" // Green default
    property color trackColor: "#161b22"
    property bool dangerMode: false

    property bool spaceHolding: false
    property real holdProgress: 0.0

    signal confirmed()

    function reset() {
        cancelSpaceCharge();
        thumbAnim.to = 2;
        thumbAnim.restart();
    }

    function startSpaceCharge() {
        spaceHolding = true;
        holdProgress = 0.0;
        spaceChargeTimer.start();
    }

    function cancelSpaceCharge() {
        spaceChargeTimer.stop();
        if (spaceHolding) {
            spaceHolding = false;
            holdProgress = 0.0;
            thumbAnim.to = 2;
            thumbAnim.restart();
        }
    }

    Component.onCompleted: root.forceActiveFocus()

    Keys.onSpacePressed: function(event) {
        if (!event.isAutoRepeat) {
            startSpaceCharge();
            event.accepted = true;
        }
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat) {
            cancelSpaceCharge();
            event.accepted = true;
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        border.color: root.spaceHolding ? "#ffffff" : root.accentColor
        border.width: root.spaceHolding ? 2 : 1
        clip: true

        // Focus outline when active
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: root.accentColor
            border.width: root.activeFocus ? 2 : 0
            opacity: 0.6
        }

        // Progress fill
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, thumb.x + thumb.width / 2)
            radius: parent.radius
            color: root.accentColor
            opacity: root.spaceHolding ? 0.45 : 0.22

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Animated label & hold status in track
        Row {
            anchors.centerIn: parent
            spacing: 8
            opacity: Math.max(0.2, 1.0 - (thumb.x / Math.max(1, (track.width - thumb.width))) * 1.5)

            Text {
                text: root.spaceHolding 
                      ? ("CHARGING: " + Math.min(100, Math.round(root.holdProgress * 100)) + "%")
                      : (root.label + "  [HOLD SPACE]")
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
                color: root.spaceHolding ? "#ffffff" : root.accentColor
            }
            Text {
                text: root.spaceHolding ? "⚡⚡⚡" : "» » »"
                font.pixelSize: 11
                font.bold: true
                color: root.spaceHolding ? "#ffffff" : root.accentColor
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                }
            }
        }

        // Draggable / chargable thumb
        Rectangle {
            id: thumb
            width: track.height - 4
            height: track.height - 4
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: 2

            color: root.spaceHolding ? "#ffffff" : root.accentColor
            border.color: root.spaceHolding ? root.accentColor : "#ffffff"
            border.width: 2

            Text {
                anchors.centerIn: parent
                text: root.spaceHolding ? "⚡" : root.iconText
                font.pixelSize: 15
                font.bold: true
                color: root.spaceHolding ? "#0d1117" : (root.dangerMode ? "#ffffff" : "#0d1117")
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: thumb
                drag.axis: Drag.XAxis
                drag.minimumX: 2
                drag.maximumX: track.width - thumb.width - 2
                cursorShape: Qt.PointingHandCursor

                onPressed: root.forceActiveFocus()

                onReleased: {
                    var max = track.width - thumb.width - 2;
                    var ratio = (thumb.x - 2) / (max > 0 ? max : 1);
                    if (ratio >= 0.88) {
                        thumb.x = max;
                        root.confirmed();
                        resetTimer.start();
                    } else {
                        thumbAnim.to = 2;
                        thumbAnim.restart();
                    }
                }
            }

            NumberAnimation {
                id: thumbAnim
                target: thumb
                property: "x"
                duration: 220
                easing.type: Easing.OutQuad
            }

            Timer {
                id: resetTimer
                interval: 650
                repeat: false
                onTriggered: {
                    root.holdProgress = 0.0;
                    thumbAnim.to = 2;
                    thumbAnim.restart();
                }
            }

            Timer {
                id: spaceChargeTimer
                interval: 16
                repeat: true
                onTriggered: {
                    var max = track.width - thumb.width - 2;
                    if (max <= 0) return;
                    root.holdProgress += 16.0 / 1200.0; // Fills in 1.2 seconds
                    thumb.x = 2 + Math.min(max, max * root.holdProgress);
                    if (root.holdProgress >= 1.0) {
                        spaceChargeTimer.stop();
                        root.spaceHolding = false;
                        thumb.x = max;
                        root.confirmed();
                        resetTimer.start();
                    }
                }
            }
        }
    }
}
