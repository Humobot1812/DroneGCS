import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import GCS 1.0

ApplicationWindow {
    id: root
    width: 1440
    height: 900
    minimumWidth: 1024
    minimumHeight: 700
    visible: true
    title: "DRONE GCS — Ground Control Station"

    // ── Global dark material theme ──────────────────────────────────────────
    Material.theme: Material.Dark
    Material.accent: "#00d4ff"
    Material.primary: "#0d1117"

    // ── Design tokens ───────────────────────────────────────────────────────
    readonly property color bgPrimary:  "#0d1117"
    readonly property color bgSurface:  "#161b22"
    readonly property color bgPanel:    "#21262d"
    readonly property color accentCyan: "#00d4ff"
    readonly property color accentGreen:"#3fb950"
    readonly property color accentAmber:"#d29922"
    readonly property color accentRed:  "#f85149"
    readonly property color textPrimary:"#e6edf3"
    readonly property color textMuted:  "#7d8590"

    property int currentPage: (typeof initialPage !== "undefined") ? initialPage : 0  // 0=Map 1=Mission 2=Params 3=Video
    property bool autoTour: (typeof initialAutoTour !== "undefined") ? initialAutoTour : false
    property string screenshotDir: (typeof initialScreenshotDir !== "undefined") ? initialScreenshotDir : ""

    Timer {
        id: initialCaptureTimer
        interval: 3500
        running: root.autoTour && root.screenshotDir !== ""
        repeat: false
        onTriggered: {
            var names = ["map", "mission", "params", "video"];
            var path = root.screenshotDir + "/gcs_" + names[root.currentPage] + ".png";
            mainLayout.grabToImage(function(res) {
                res.saveToFile(path);
                console.log("Captured initial page image:", path);
            });
        }
    }

    Timer {
        id: tourTimer
        interval: 3200
        repeat: true
        running: root.autoTour
        property int step: 0
        onTriggered: {
            step = (step + 1) % 4;
            root.currentPage = step;
            if (root.screenshotDir !== "") {
                var names = ["map", "mission", "params", "video"];
                var path = root.screenshotDir + "/gcs_" + names[step] + ".png";
                captureTimer.targetPath = path;
                captureTimer.start();
            }
        }
    }

    Timer {
        id: captureTimer
        interval: 1200
        repeat: false
        property string targetPath: ""
        onTriggered: {
            if (targetPath !== "") {
                mainLayout.grabToImage(function(res) {
                    res.saveToFile(targetPath);
                    console.log("Captured page image:", targetPath);
                });
            }
        }
    }

    color: bgPrimary
    font.family: "Inter"

    // ── Layout ──────────────────────────────────────────────────────────────
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0

        // Left sidebar
        Sidebar {
            id: sidebar
            Layout.preferredWidth: 64
            Layout.fillHeight: true
            currentPage: root.currentPage
            onPageSelected: function(page) { root.currentPage = page; }
            onSettingsClicked: settingsDialog.open()
        }

        // Main content column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Drone selector tabs (top bar)
            DroneSelector {
                id: droneSelector
                Layout.fillWidth: true
                Layout.preferredHeight: 48
            }

            // Page stack
            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                MapPage       { id: mapPage }
                MissionPage   { id: missionPage }
                ParametersPage{ id: paramsPage }
                VideoPage     { id: videoPage }
            }

            // Status bar
            StatusBar {
                id: statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 38
            }
        }
    }

    // ── Connection dialog (shown via statusbar button) ───────────────────────
    ConnectionDialog {
        id: connectionDialog
    }

    // ── Settings dialog (shown via sidebar ⚙ button) ─────────────────────────
    SettingsDialog {
        id: settingsDialog
    }

    // ── Global keyboard shortcuts ────────────────────────────────────────────
    Shortcut { sequence: "F1"; onActivated: root.currentPage = 0 } // Map
    Shortcut { sequence: "F2"; onActivated: root.currentPage = 1 } // Mission
    Shortcut { sequence: "F3"; onActivated: root.currentPage = 2 } // Params
    Shortcut { sequence: "F4"; onActivated: root.currentPage = 3 } // Video
    Shortcut { sequence: "F5"; onActivated: root.autoTour = !root.autoTour }
    Shortcut { sequence: "Ctrl+N"; onActivated: connectionDialog.open() }
    Shortcut { sequence: "Ctrl+,"; onActivated: settingsDialog.open() }

    Component.onCompleted: {
        if (root.screenshotDir !== "") {
            captureTimer.targetPath = root.screenshotDir + "/gcs_map.png";
            captureTimer.start();
        }
    }
}
