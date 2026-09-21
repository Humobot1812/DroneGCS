import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.2

Rectangle {
    id: root
    color: "#0d1117"

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 16

        // Header row
        RowLayout {
            Layout.fillWidth: true
            Text { text: "📷  Video Feed"; font.pixelSize: 16; font.bold: true; color: "#e6edf3" }
            Item { Layout.fillWidth: true }

            // Stream URL input
            Rectangle {
                width: 320; height: 34; radius: 6
                color: "#161b22"; border.color: "#30363d"; border.width: 1
                Row {
                    anchors { fill: parent; leftMargin: 10 }
                    spacing: 8
                    Text { text: "🔗"; anchors.verticalCenter: parent.verticalCenter; color: "#7d8590" }
                    TextInput {
                        id: urlField
                        width: parent.parent.width - 50; height: parent.parent.height
                        text: "rtsp://192.168.1.100:8554/stream"
                        color: "#e6edf3"; font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                    }
                }
            }

            Button {
                text: videoManager.isPlaying ? "⏹ Stop" : "▶ Play"
                Material.background: videoManager.isPlaying ? "#f85149" : "#3fb950"
                Material.foreground: "#0d1117"
                font.bold: true
                onClicked: {
                    if (videoManager.isPlaying) {
                        videoManager.stop();
                    } else {
                        videoManager.setStreamUrl(urlField.text);
                        videoManager.start();
                    }
                }
            }
        }

        // Video output area
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: "#000000"; radius: 8
            border.color: "#21262d"; border.width: 1
            clip: true

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }

            // No-signal overlay
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !videoManager.isPlaying
                Text { text: "📷"; font.pixelSize: 64; color: "#21262d"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "No Video Signal"; font.pixelSize: 20; color: "#30363d"; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Enter an RTSP URL and press Play"; font.pixelSize: 13; color: "#21262d"; anchors.horizontalCenter: parent.horizontalCenter }
            }

            // Recording indicator
            Rectangle {
                anchors { top: parent.top; right: parent.right; topMargin: 12; rightMargin: 12 }
                width: 80; height: 24; radius: 4; color: "#1a0000"
                visible: videoManager.isPlaying
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 8; height: 8; radius: 4; color: "#f85149"; anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity { loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text { text: "LIVE"; color: "#f85149"; font.pixelSize: 11; font.bold: true }
                }
            }
        }

        // YOLO control
        RowLayout {
            Layout.fillWidth: true
            Text { text: "YOLO Detection"; color: "#7d8590"; font.pixelSize: 12; Layout.fillWidth: true }

            Button {
                text: pythonBridge.isRunning("yolo") ? "⏹ Stop YOLO" : "🤖 Start YOLO"
                flat: true
                Material.foreground: pythonBridge.isRunning("yolo") ? "#f85149" : "#00d4ff"
                onClicked: {
                    if (pythonBridge.isRunning("yolo")) {
                        pythonBridge.stop("yolo");
                    } else {
                        pythonBridge.launch("yolo", appDirPath + "/python_scripts/yolo_detection.py");
                    }
                }
            }
        }
    }

    // Wire VideoManager sink to VideoOutput
    Component.onCompleted: {
        // Qt6 Multimedia: set the video sink from VideoOutput
        videoManager.videoSink = videoOutput.videoSink
    }
}
