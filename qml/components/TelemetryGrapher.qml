import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// TelemetryGrapher — Real-time telemetry oscilloscope
Rectangle {
    id: root
    width: 480
    height: 240
    color: "#0d1117"
    border.color: "#30363d"
    border.width: 1
    radius: 8
    clip: true

    property var drone: droneManager.activeDrone
    property int maxSamples: 60

    // Data series
    property var altData: []
    property var climbData: []
    property var voltData: []
    property var speedData: []

    // Channel toggles
    property bool showAlt: true
    property bool showClimb: true
    property bool showVolt: true
    property bool showSpeed: true

    signal closeRequested()

    // 1 Hz sample collection timer
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!drone) return;

            var newAlt = drone.relAltitude || 0;
            var newClimb = drone.climbRate || 0;
            var newVolt = drone.batteryVoltage || 0;
            var newSpeed = drone.groundSpeed || 0;

            var a = altData.slice();
            var c = climbData.slice();
            var v = voltData.slice();
            var s = speedData.slice();

            a.push(newAlt);
            c.push(newClimb);
            v.push(newVolt);
            s.push(newSpeed);

            if (a.length > maxSamples) a.shift();
            if (c.length > maxSamples) c.shift();
            if (v.length > maxSamples) v.shift();
            if (s.length > maxSamples) s.shift();

            altData = a;
            climbData = c;
            voltData = v;
            speedData = s;

            scopeCanvas.requestPaint();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header and channel toggles
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "📈 Telemetry Oscilloscope"
                color: "#e6edf3"; font.pixelSize: 12; font.bold: true
            }

            Item { Layout.fillWidth: true }

            // Channels toggles
            Row {
                spacing: 6
                Rectangle {
                    width: 76; height: 22; radius: 3
                    color: root.showAlt ? "#00d4ff20" : "#21262d"
                    border.color: root.showAlt ? "#00d4ff" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Alt: " + (drone ? drone.relAltitude.toFixed(1) : "0") + "m"
                        color: root.showAlt ? "#00d4ff" : "#7d8590"; font.pixelSize: 9; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: { root.showAlt = !root.showAlt; scopeCanvas.requestPaint(); } }
                }

                Rectangle {
                    width: 82; height: 22; radius: 3
                    color: root.showClimb ? "#3fb95020" : "#21262d"
                    border.color: root.showClimb ? "#3fb950" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Climb: " + (drone ? drone.climbRate.toFixed(1) : "0") + "m/s"
                        color: root.showClimb ? "#3fb950" : "#7d8590"; font.pixelSize: 9; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: { root.showClimb = !root.showClimb; scopeCanvas.requestPaint(); } }
                }

                Rectangle {
                    width: 76; height: 22; radius: 3
                    color: root.showVolt ? "#f59e0b20" : "#21262d"
                    border.color: root.showVolt ? "#f59e0b" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Volt: " + (drone ? drone.batteryVoltage.toFixed(1) : "0") + "V"
                        color: root.showVolt ? "#f59e0b" : "#7d8590"; font.pixelSize: 9; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: { root.showVolt = !root.showVolt; scopeCanvas.requestPaint(); } }
                }

                Rectangle {
                    width: 82; height: 22; radius: 3
                    color: root.showSpeed ? "#c084fc20" : "#21262d"
                    border.color: root.showSpeed ? "#c084fc" : "#30363d"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Spd: " + (drone ? drone.groundSpeed.toFixed(1) : "0") + "m/s"
                        color: root.showSpeed ? "#c084fc" : "#7d8590"; font.pixelSize: 9; font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: { root.showSpeed = !root.showSpeed; scopeCanvas.requestPaint(); } }
                }
            }

            Rectangle {
                width: 20; height: 20; radius: 10; color: "#21262d"
                Text { text: "✕"; color: "#8b949e"; font.pixelSize: 10; anchors.centerIn: parent }
                MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
            }
        }

        // Oscilloscope Canvas
        Canvas {
            id: scopeCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true

            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;

                ctx.fillStyle = "#161b22";
                ctx.fillRect(0, 0, w, h);

                // Grid lines
                ctx.strokeStyle = "#21262d";
                ctx.lineWidth = 1;
                for (var y = 20; y < h; y += 30) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(w, y);
                    ctx.stroke();
                }
                for (var x = 40; x < w; x += 50) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, h);
                    ctx.stroke();
                }

                if (root.altData.length < 2) {
                    ctx.fillStyle = "#7d8590";
                    ctx.font = "11px sans-serif";
                    ctx.fillText("Gathering live telemetry data...", 15, h / 2);
                    return;
                }

                // Helper to draw trace
                function drawTrace(data, minVal, maxVal, color) {
                    if (data.length < 2) return;
                    var range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1;
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 2;
                    ctx.beginPath();

                    for (var i = 0; i < data.length; i++) {
                        var px = (i / (root.maxSamples - 1)) * w;
                        var norm = (data[i] - minVal) / range;
                        var py = h - (norm * (h - 20) + 10);
                        if (i === 0) ctx.moveTo(px, py);
                        else ctx.lineTo(px, py);
                    }
                    ctx.stroke();
                }

                if (root.showAlt) drawTrace(root.altData, 0, 100, "#00d4ff");
                if (root.showClimb) drawTrace(root.climbData, -5, 5, "#3fb950");
                if (root.showVolt) drawTrace(root.voltData, 10, 26, "#f59e0b");
                if (root.showSpeed) drawTrace(root.speedData, 0, 25, "#c084fc");
            }
        }
    }
}
