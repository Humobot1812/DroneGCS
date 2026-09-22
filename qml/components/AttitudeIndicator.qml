import QtQuick 2.15

/**
 * AttitudeIndicator — Modern Aerospace Glass Cockpit Artificial Horizon.
 * roll  : degrees (-180..180)
 * pitch : degrees (-90..90)
 */
Item {
    id: root
    width: 280; height: 280

    property real roll:  0
    property real pitch: 0

    // Smooth physics smoothing
    Behavior on roll  { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
    Behavior on pitch { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }

    // ── MIL-STD-1472H Anti-Glare High-Contrast Backing Plate ────────────────
    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: "#0d1117"
        opacity: 0.92
        border.color: "#30363d"
        border.width: 2
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx   = getContext("2d");
            var cx    = width  / 2;
            var cy    = height / 2;
            var r     = Math.min(cx, cy) - 6;
            var pxPerDeg = r / 28;

            ctx.clearRect(0, 0, width, height);

            // ── Outer Bezel Shadow & Glow ──
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, r + 4, 0, 2 * Math.PI);
            ctx.fillStyle = "#12171f";
            ctx.fill();
            ctx.strokeStyle = "#30363d";
            ctx.lineWidth = 2;
            ctx.stroke();
            ctx.restore();

            // ── Clip Circular Horizon Area ──
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.clip();

            // ── Roll & Pitch World Matrix ──
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-root.roll * Math.PI / 180);
            ctx.translate(-cx, -cy);

            var pitchOffset = root.pitch * pxPerDeg;

            // Sky Gradient (deep aerospace cobalt to horizon cyan-blue)
            var skyGrad = ctx.createLinearGradient(0, cy + pitchOffset - r * 1.5, 0, cy + pitchOffset);
            skyGrad.addColorStop(0, "#092444");
            skyGrad.addColorStop(0.7, "#114577");
            skyGrad.addColorStop(1, "#1c6db0");
            ctx.fillStyle = skyGrad;
            ctx.fillRect(0, cy + pitchOffset - r * 2, width, r * 2);

            // Ground Gradient (warm earth tones)
            var gndGrad = ctx.createLinearGradient(0, cy + pitchOffset, 0, cy + pitchOffset + r * 1.5);
            gndGrad.addColorStop(0, "#543717");
            gndGrad.addColorStop(0.4, "#3b240c");
            gndGrad.addColorStop(1, "#211405");
            ctx.fillStyle = gndGrad;
            ctx.fillRect(0, cy + pitchOffset, width, r * 2);

            // Horizon Line with subtle neon glow
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(0, cy + pitchOffset);
            ctx.lineTo(width, cy + pitchOffset);
            ctx.stroke();

            // Pitch ladder rungs (every 5 degrees)
            ctx.fillStyle   = "#ffffff";
            ctx.font        = "bold 9px 'JetBrains Mono', monospace";
            ctx.textAlign   = "center";
            ctx.textBaseline = "middle";
            ctx.strokeStyle = "#ffffffdd";
            ctx.lineWidth   = 1.5;

            for (var deg = -30; deg <= 30; deg += 5) {
                if (deg === 0) continue;
                var y = cy + pitchOffset - deg * pxPerDeg;
                var isMajor = (deg % 10 === 0);
                var halfW = isMajor ? 36 : 18;
                var pipH = (deg > 0) ? -4 : 4;

                ctx.beginPath();
                // Left rung
                ctx.moveTo(cx - halfW, y + pipH);
                ctx.lineTo(cx - halfW, y);
                ctx.lineTo(cx - 10, y);
                // Right rung
                ctx.moveTo(cx + 10, y);
                ctx.lineTo(cx + halfW, y);
                ctx.lineTo(cx + halfW, y + pipH);
                ctx.stroke();

                if (isMajor) {
                    ctx.fillText(Math.abs(deg), cx - halfW - 12, y);
                    ctx.fillText(Math.abs(deg), cx + halfW + 12, y);
                }
            }

            ctx.restore(); // end world matrix

            // ── Roll Scale Arc & Ticks (Glass Cockpit Standard) ──
            ctx.save();
            ctx.translate(cx, cy);
            ctx.strokeStyle = "#ffffffaa";
            ctx.lineWidth = 1.2;

            var rollAngles = [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60];
            for (var i = 0; i < rollAngles.length; ++i) {
                var a = rollAngles[i];
                ctx.save();
                ctx.rotate(a * Math.PI / 180);
                var isThirty = (Math.abs(a) === 30 || Math.abs(a) === 60 || a === 0);
                ctx.beginPath();
                ctx.moveTo(0, -(r - 2));
                ctx.lineTo(0, -(r - (isThirty ? 12 : 7)));
                ctx.stroke();
                ctx.restore();
            }

            // Sky pointer triangle at roll angle
            ctx.save();
            ctx.rotate(-root.roll * Math.PI / 180);
            ctx.fillStyle = "#00d4ff";
            ctx.beginPath();
            ctx.moveTo(0, -(r - 16));
            ctx.lineTo(-6, -(r - 5));
            ctx.lineTo(6, -(r - 5));
            ctx.closePath();
            ctx.fill();
            ctx.restore();

            ctx.restore(); // end roll scale

            // ── Fixed Aircraft Reference Reticle (Boresight) ──
            ctx.save();
            ctx.translate(cx, cy);

            ctx.strokeStyle = "#ffcc00";
            ctx.lineWidth   = 3;
            ctx.lineCap     = "round";

            // Left wing bar with down-pip
            ctx.beginPath();
            ctx.moveTo(-64, 0);
            ctx.lineTo(-22, 0);
            ctx.lineTo(-22, 9);
            ctx.stroke();

            // Right wing bar with down-pip
            ctx.beginPath();
            ctx.moveTo(64, 0);
            ctx.lineTo(22, 0);
            ctx.lineTo(22, 9);
            ctx.stroke();

            // Center pip & circle
            ctx.fillStyle = "#ffcc00";
            ctx.beginPath();
            ctx.arc(0, 0, 3.5, 0, 2 * Math.PI);
            ctx.fill();

            ctx.restore(); // end aircraft symbol

            // ── Metallic Bezel Ring ──
            ctx.strokeStyle = "#00d4ff40";
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();

            ctx.restore(); // end clip
        }
    }

    Connections {
        target: root
        function onRollChanged()  { canvas.requestPaint() }
        function onPitchChanged() { canvas.requestPaint() }
    }

    // Top Digital Angle Readouts
    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
        spacing: 12

        Rectangle {
            height: 18; width: 62; radius: 4
            color: "#161b22e0"; border.color: "#30363d"; border.width: 1
            Text {
                text: "P: " + (root.pitch >= 0 ? "+" : "") + root.pitch.toFixed(1) + "°"
                color: "#e6edf3"; font.pixelSize: 9; font.bold: true; font.family: "JetBrains Mono, monospace"
                anchors.centerIn: parent
            }
        }

        Rectangle {
            height: 18; width: 62; radius: 4
            color: "#161b22e0"; border.color: "#30363d"; border.width: 1
            Text {
                text: "R: " + (root.roll >= 0 ? "+" : "") + root.roll.toFixed(1) + "°"
                color: "#00d4ff"; font.pixelSize: 9; font.bold: true; font.family: "JetBrains Mono, monospace"
                anchors.centerIn: parent
            }
        }
    }
}
