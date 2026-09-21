import QtQuick 2.15

// Battery status widget
Canvas {
    id: root
    width: 80; height: 30
    property int percent: -1    // -1 = unknown
    property real voltage: 0

    onPercentChanged: requestPaint()
    onVoltageChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var pct = Math.max(0, Math.min(100, percent));
        var color = pct > 50 ? "#3fb950" : (pct > 20 ? "#d29922" : "#f85149");

        // Outer shell
        ctx.strokeStyle = "#7d8590";
        ctx.lineWidth = 1.5;
        ctx.roundRect(2, 6, 60, 18, 3);
        ctx.stroke();

        // Terminal nub
        ctx.fillStyle = "#7d8590";
        ctx.fillRect(62, 11, 5, 8);

        // Fill bar
        if (percent >= 0) {
            ctx.fillStyle = color;
            ctx.fillRect(4, 8, Math.floor(56 * pct / 100), 14);
        }

        // Label
        ctx.fillStyle = "#e6edf3";
        ctx.font      = "bold 9px 'JetBrains Mono', monospace";
        ctx.textAlign = "center";
        ctx.fillText(percent >= 0 ? pct + "%" : "—", 31, 19);
    }
}
