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
    title: "DRONE GCS — Tactical Ground Control Station"

    // ── Global dark material theme ──────────────────────────────────────────
    Material.theme: Material.Dark
    Material.accent: "#00d4ff"
    Material.primary: "#0d1117"

    // ── Design tokens — Color ────────────────────────────────────────────────
    readonly property color bgPrimary:    "#0d1117"   // page background
    readonly property color bgSurface:    "#161b22"   // cards, panels
    readonly property color bgPanel:      "#21262d"   // elevated elements, inputs
    readonly property color bgHover:      "#2d333b"   // hover backgrounds
    readonly property color borderStrong: "#30363d"   // primary borders
    readonly property color borderLight:  "#21262d"   // subtle dividers

    readonly property color accentCyan:   "#00d4ff"   // primary accent
    readonly property color accentGreen:  "#3fb950"   // success, GPS OK, disarmed
    readonly property color accentAmber:  "#d29922"   // warnings, land
    readonly property color accentRed:    "#f85149"   // armed-danger, error
    readonly property color accentOrange: "#e05a1d"   // ArduPilot
    readonly property color accentPurple: "#a070f0"   // PX4

    readonly property color textPrimary:  "#e6edf3"   // main text
    readonly property color textSecond:   "#8b949e"   // secondary text
    readonly property color textMuted:    "#7d8590"   // labels, muted
    readonly property color textDisabled: "#484f58"   // disabled

    readonly property color dangerText:   "#ff6b6b"   // kill/emergency text
    readonly property color dangerBg:     "#3d1010"   // kill/emergency bg

    // ── Design tokens — Typography scale (5 levels) ─────────────────────────
    readonly property int szXL: 15   // section/page titles
    readonly property int szLG: 13   // subsection headers, drone name
    readonly property int szMD: 12   // body, buttons, telemetry values
    readonly property int szSM: 11   // labels, captions, badge text
    readonly property int szXS: 10   // metadata, secondary badges

    // ── Design tokens — Spacing scale ───────────────────────────────────────
    readonly property int sp2:  2
    readonly property int sp4:  4
    readonly property int sp6:  6
    readonly property int sp8:  8
    readonly property int sp12: 12
    readonly property int sp16: 16
    readonly property int sp20: 20

    // ── Design tokens — Component heights ───────────────────────────────────
    readonly property int btnH:      32   // standard button height
    readonly property int headerH:   44   // primary toolbar/header rows
    readonly property int toolbarH:  36   // secondary toolbar rows
    readonly property int statusH:   34   // bottom status bar
    readonly property int badgeH:    22   // status badges
    readonly property int inputH:    32   // text inputs

    // ── Design tokens — Border radii ────────────────────────────────────────
    readonly property int rSmall:  4    // tight elements
    readonly property int rMed:    5    // buttons, badges, inputs
    readonly property int rLarge:  6    // cards, panels
    readonly property int rXL:     8    // dialogs

    property int currentPage: (typeof initialPage !== "undefined") ? initialPage : 0  // 0=Map 1=Mission 2=Params 3=Video

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
            Layout.preferredWidth: 100
            Layout.fillHeight: true
            currentPage: root.currentPage
            onPageSelected: function(page) { root.currentPage = page; }
            onSettingsClicked: settingsDialog.open()
            onAiCopilotClicked: root.aiCopilotOpen = !root.aiCopilotOpen
            onAboutClicked: aboutDialog.open()
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
                Layout.preferredHeight: 44
                onConnectClicked: connectionDialog.open()
            }

            // Page stack
            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                MapPage {
                    id: mapPage
                    onRequestCloseAiDrawer: root.aiCopilotOpen = false
                }
                MissionPage   { id: missionPage }
                ParametersPage{ id: paramsPage }
                VideoPage     { id: videoPage }
            }

            // Status bar
            StatusBar {
                id: statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                onConnectClicked: connectionDialog.open()
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

    // ── About dialog (shown via sidebar ⓘ button) ─────────────────────────────
    AboutDialog {
        id: aboutDialog
    }

    // ── AI Copilot Drawer (Slide-out from Right) ─────────────────────────────
    property bool aiCopilotOpen: (typeof initialOpenAi !== "undefined") ? initialOpenAi : false
    onAiCopilotOpenChanged: {
        if (typeof mapPage !== "undefined" && mapPage && typeof mapPage.setAiDrawerOpen === "function") {
            mapPage.setAiDrawerOpen(root.aiCopilotOpen);
        }
    }

    AiCopilotDrawer {
        id: aiDrawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: root.aiCopilotOpen ? 0 : -width
        z: 100
        visible: root.aiCopilotOpen || anchors.rightMargin > -width

        Behavior on anchors.rightMargin { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        onCloseRequested: root.aiCopilotOpen = false
        onPageNavigationRequested: function(page) {
            root.currentPage = page;
        }
        onOpenSettingsRequested: settingsDialog.open()
        onOpenLogsRequested: {
            root.currentPage = 0; // go to map
            if (mapPage && typeof mapPage.openFlightLogs === "function") {
                mapPage.openFlightLogs();
            }
        }
    }

    // ── Global keyboard shortcuts ────────────────────────────────────────────
    Shortcut { sequence: "F1"; onActivated: root.currentPage = 0 } // Map
    Shortcut { sequence: "F2"; onActivated: root.currentPage = 1 } // Mission
    Shortcut { sequence: "F3"; onActivated: root.currentPage = 2 } // Params
    Shortcut { sequence: "F4"; onActivated: root.currentPage = 3 } // Video
    Shortcut { sequence: "F5"; onActivated: root.aiCopilotOpen = !root.aiCopilotOpen } // AI Copilot
    Shortcut { sequence: "Ctrl+Space"; onActivated: root.aiCopilotOpen = !root.aiCopilotOpen } // AI Copilot
    Shortcut { sequence: "Ctrl+N"; onActivated: connectionDialog.open() }
    Shortcut { sequence: "Ctrl+,"; onActivated: settingsDialog.open() }
}
