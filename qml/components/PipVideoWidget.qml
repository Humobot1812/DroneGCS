import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.2

// PipVideoWidget — Floating Picture-in-Picture Video Stream on Tactical Map
Rectangle {
    id: root
    width: minimized ? 130 : 320
    height: minimized ? 36 : 210
    radius: 8
    color: "#161b22"
    border.color: "#30363d"
    border.width: 1
    clip: true
    z: 40

    property bool minimized: false
    signal expandToFullVideoRequested()
    signal closeRequested()

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root
        drag.minimumX: 10
        drag.minimumY: 50
        drag.maximumX: (root.parent ? root.parent.width - root.width - 10 : 800)
        drag.maximumY: (root.parent ? root.parent.height - root.height - 10 : 600)
        cursorShape: Qt.SizeAllCursor

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#0d1117"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 6

                    Text { text: "📷"; font.pixelSize: 12 }
                    Text {
                        text: "FPV Video"
                        font.pixelSize: 11; font.bold: true; color: "#e6edf3"
                        visible: !root.minimized
                    }

                    // Live badge
                    Rectangle {
                        width: 44; height: 18; radius: 3
                        color: videoManager.isPlaying ? "#f8514920" : "#21262d"
                        border.color: videoManager.isPlaying ? "#f85149" : "#30363d"
                        border.width: 1
                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Rectangle {
                                width: 5; height: 5; radius: 2.5
                                color: videoManager.isPlaying ? "#f85149" : "#7d8590"
                                SequentialAnimation on opacity {
                                    running: videoManager.isPlaying; loops: Animation.Infinite
                                    NumberAnimation { from: 0.2; to: 1.0; duration: 600 }
                                    NumberAnimation { from: 1.0; to: 0.2; duration: 600 }
                                }
                            }
                            Text {
                                text: videoManager.isPlaying ? "LIVE" : "OFF"
                                font.pixelSize: 8; font.bold: true
                                color: videoManager.isPlaying ? "#f85149" : "#7d8590"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Minimize / Restore
                    Rectangle {
                        width: 20; height: 20; radius: 3; color: "#21262d"
                        Text { text: root.minimized ? "▢" : "—"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.minimized = !root.minimized
                        }
                    }

                    // Fullscreen / Page switch
                    Rectangle {
                        width: 20; height: 20; radius: 3; color: "#21262d"
                        visible: !root.minimized
                        Text { text: "⛶"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.expandToFullVideoRequested()
                        }
                    }

                    // Close
                    Rectangle {
                        width: 20; height: 20; radius: 3; color: "#21262d"
                        Text { text: "✕"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }

            // Video Viewport (hidden when minimized)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#000000"
                visible: !root.minimized
                clip: true

                VideoOutput {
                    id: pipVideoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }

                // Fallback / No signal overlay
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !videoManager.isPlaying
                    Text { text: "📷"; font.pixelSize: 28; color: "#21262d"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "No Stream Active"; font.pixelSize: 11; color: "#7d8590"; anchors.horizontalCenter: parent.horizontalCenter }
                    Button {
                        text: "Start Stream"
                        Layout.preferredHeight: 24
                        font.pixelSize: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: videoManager.start()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        videoManager.setVideoSink(pipVideoOutput.videoSink);
    }
}
