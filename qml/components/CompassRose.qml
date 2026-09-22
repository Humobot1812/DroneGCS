import QtQuick 2.15

// Compass rose — rotating dial, fixed aircraft pointer
Canvas {
    id: root
    width: 160; height: 160

    property real heading: 0   // degrees 0-360

    Behavior on heading { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    onHeadingChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        var cx  = width / 2, cy = height / 2;
        var r   = Math.min(cx, cy) - 4;

        ctx.clearRect(0, 0, width, height);

        // Background circle with MIL-STD anti-glare bezel
        ctx.fillStyle = "#0d1117";
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fill();
        ctx.strokeStyle = "#30363d";
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(-heading * Math.PI / 180);

        // Tick marks and cardinal labels
        var cardinals = { 0: "N", 90: "E", 180: "S", 270: "W" };
        for (var deg = 0; deg < 360; deg += 5) {
            ctx.save();
            ctx.rotate(deg * Math.PI / 180);
            var isMajor = (deg % 30 === 0);
            var isCrd   = (deg % 90 === 0);
            var tickLen = isCrd ? 14 : (isMajor ? 10 : 6);

            ctx.strokeStyle = isCrd ? "#00d4ff" : "#7d8590";
            ctx.lineWidth   = isCrd ? 2 : 1;
            ctx.beginPath();
            ctx.moveTo(0, -(r - tickLen));
            ctx.lineTo(0, -(r));
            ctx.stroke();

            if (isCrd) {
                ctx.fillStyle = "#00d4ff";
                ctx.font      = "bold 13px 'JetBrains Mono', monospace";
                ctx.textAlign = "center";
                ctx.fillText(cardinals[deg], 0, -(r - 20));
            } else if (isMajor) {
                ctx.fillStyle = "#7d8590";
                ctx.font      = "9px monospace";
                ctx.textAlign = "center";
                ctx.fillText(String(deg), 0, -(r - 18));
            }
            ctx.restore();
        }

        ctx.restore();

        // Fixed top pointer (triangle)
        ctx.fillStyle = "#f85149";
        ctx.beginPath();
        ctx.moveTo(cx, cy - r + 2);
        ctx.lineTo(cx - 6, cy - r + 14);
        ctx.lineTo(cx + 6, cy - r + 14);
        ctx.closePath();
        ctx.fill();

        // Heading readout
        ctx.fillStyle   = "#e6edf3";
        ctx.font        = "bold 18px 'JetBrains Mono', monospace";
        ctx.textAlign   = "center";
        ctx.fillText(Math.round(heading).toString().padStart(3, "0") + "°", cx, cy + 7);

        // Outer ring
        ctx.strokeStyle = "#30363d";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.stroke();
    }
}
