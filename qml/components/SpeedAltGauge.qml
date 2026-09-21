import QtQuick 2.15

// Modern Speed or Altitude vertical tape gauge
Item {
    id: root
    width: 66; height: 220

    property real value: 0       // current value (m/s or m)
    property real range: 50      // total range displayed (25 above/below center)
    property string unit: "m/s"
    property string label: "SPD"
    property color accentColor: "#00d4ff"

    Behavior on value { NumberAnimation { duration: 80 } }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#12171f"
        border.color: "#21262d"; border.width: 1

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                var cx = width / 2, cy = height / 2;
                ctx.clearRect(0, 0, width, height);

                // Tape area
                var tapeW = 44;
                var tapeX = cx - tapeW / 2;
                var pxPerUnit = height / range;

                // Draw tick marks and labels
                var valMin = root.value - range / 2;
                var valMax = root.value + range / 2;
                var step = range <= 25 ? 1 : (range <= 60 ? 5 : 10);

                ctx.fillStyle   = "#8b949e";
                ctx.strokeStyle = "#30363d";
                ctx.lineWidth   = 1;
                ctx.font        = "9px 'JetBrains Mono', monospace";
                ctx.textAlign   = "right";
                ctx.textBaseline = "middle";

                for (var v = Math.ceil(valMin / step) * step; v <= valMax; v += step) {
                    var y = cy - (v - root.value) * pxPerUnit;
                    if (y < 16 || y > height - 16) continue;

                    var isMajor = (v % (step * 2) === 0 || step <= 2);
                    ctx.strokeStyle = isMajor ? "#7d8590" : "#21262d";
                    ctx.beginPath();
                    ctx.moveTo(tapeX + 4, y);
                    ctx.lineTo(tapeX + (isMajor ? 16 : 8), y);
                    ctx.stroke();

                    if (isMajor && Math.abs(y - cy) > 14) {
                        ctx.fillText(Math.round(v), tapeX - 2, y);
                    }
                }

                // Center readout box
                var boxH = 26, boxW = tapeW + 6;
                ctx.save();
                ctx.fillStyle = "#161b22";
                ctx.strokeStyle = accentColor;
                ctx.lineWidth = 1.5;

                // Box with small pointer notch
                var bx = tapeX - 3, by = cy - boxH / 2;
                ctx.beginPath();
                ctx.moveTo(bx + 4, by);
                ctx.lineTo(bx + boxW - 6, by);
                ctx.lineTo(bx + boxW, cy);
                ctx.lineTo(bx + boxW - 6, by + boxH);
                ctx.lineTo(bx + 4, by + boxH);
                ctx.arcTo(bx, by + boxH, bx, by + boxH - 4, 4);
                ctx.lineTo(bx, by + 4);
                ctx.arcTo(bx, by, bx + 4, by, 4);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // Value Text
                ctx.fillStyle = accentColor;
                ctx.font      = "bold 12px 'JetBrains Mono', monospace";
                ctx.textAlign = "center";
                ctx.fillText(root.value.toFixed(1), bx + (boxW - 6) / 2, cy);
                ctx.restore();

                // Header Label
                ctx.fillStyle = "#8b949e";
                ctx.font      = "bold 9px 'Inter', sans-serif";
                ctx.textAlign = "center";
                ctx.fillText(label, cx, 10);

                // Footer Unit
                ctx.fillStyle = accentColor;
                ctx.font      = "8px 'JetBrains Mono', monospace";
                ctx.fillText(unit, cx, height - 8);
            }
        }
    }

    Connections {
        target: root
        function onValueChanged() { canvas.requestPaint() }
    }
}
