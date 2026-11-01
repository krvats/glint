// Glint pill: a tiny icon in a screen corner. Hover it and quick settings slide out.
// Runs as its own little Quickshell instance next to Caelestia (`glint pill on`), wearing Caelestia's colours.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property string pos: Quickshell.env("GLINT_PILL_POS") || "top-right"
    property string cli: Quickshell.env("GLINT_CLI") || "glint"
    property color bg: "#1e1e2e"
    property color card: "#2a2a3c"
    property color fg: "#cdd6f4"
    property color accent: "#b4befe"
    property color accentFg: "#1e1e2e"
    property int brightness: 50
    property var looks: []
    property bool pinned: false                       // click the icon to keep it open (handy for screenshots)
    property bool hot: card.hovered || pinned
    property bool open: false
    onHotChanged: { if (hot) { closer.stop(); open = true } else closer.restart() }
    Timer { id: closer; interval: 900; onTriggered: root.open = false }   // small grace period, no flicker

    // ---- colours: whatever `glint theme` says right now
    Process {
        id: themeProc
        command: [root.cli, "theme", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text).palette
                    if (p) { root.bg = p.bg; root.card = p.card; root.fg = p.fg; root.accent = p.accent; root.accentFg = p.accentfg }
                } catch (e) {}
            }
        }
    }
    Process {
        id: getProc
        command: [root.cli, "get", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text).displays[0]
                    if (d && d.values.brightness) root.brightness = d.values.brightness.percent
                } catch (e) {}
            }
        }
    }
    Process {
        id: looksProc
        command: [root.cli, "profile", "list", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.looks = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: setProc }
    Process { id: lookProc }
    Process { id: guiProc }

    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: themeProc.running = true }
    Timer { id: refresh; interval: 400; onTriggered: { getProc.running = true; looksProc.running = true } }
    Timer {
        id: send; interval: 250
        onTriggered: { setProc.command = [root.cli, "set", "brightness", String(root.brightness)]; setProc.running = true }
    }
    onOpenChanged: if (open) refresh.restart()

    PanelWindow {
        id: win
        anchors {
            top: root.pos.indexOf("top") >= 0
            bottom: root.pos.indexOf("bottom") >= 0
            left: root.pos.indexOf("left") >= 0
            right: root.pos.indexOf("right") >= 0
        }
        margins { top: 10; bottom: 10; left: 10; right: 10 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "glint-pill"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        implicitWidth: 280
        implicitHeight: 420          // room to grow; only the card itself takes clicks (mask below)
        mask: Region { item: card }

        Rectangle {
            id: card
            property bool hovered: cardHover.hovered
            // sits in the same corner the window is anchored to
            anchors.top: root.pos.indexOf("bottom") < 0 ? parent.top : undefined
            anchors.bottom: root.pos.indexOf("bottom") >= 0 ? parent.bottom : undefined
            anchors.left: root.pos.indexOf("left") >= 0 ? parent.left : undefined
            anchors.right: root.pos.indexOf("left") < 0 ? parent.right : undefined
            width: root.open ? 260 : 36
            height: root.open ? col.implicitHeight + 54 : 36      // grows with its content, never cuts it off
            radius: root.open ? 20 : 18
            color: root.open ? root.bg : root.accent
            border.width: 1
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
            clip: true
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            HoverHandler { id: cardHover }

            // the icon (a spark)
            Text {
                id: spark
                anchors.top: parent.top; anchors.left: parent.left
                width: 36; height: 36
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: "✦"; font.pixelSize: 17
                color: root.open ? root.accent : root.accentFg
                MouseArea { anchors.fill: parent; onClicked: root.pinned = !root.pinned }
            }

            Column {
                id: col
                visible: root.open
                opacity: root.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 40 }
                spacing: 12

                Text { text: "Brightness  " + root.brightness + "%"; color: root.fg; font.pixelSize: 13; font.bold: true }
                Rectangle {   // slider
                    width: parent.width; height: 22; radius: 11; color: root.card
                    Rectangle { width: Math.max(22, parent.width * root.brightness / 100); height: parent.height; radius: 11; color: root.accent }
                    MouseArea {
                        anchors.fill: parent
                        function setFrom(x) { root.brightness = Math.round(Math.max(0, Math.min(1, x / width)) * 100); send.restart() }
                        onPressed: mouse => setFrom(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                    }
                }
                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: root.looks
                        Rectangle {
                            width: lt.implicitWidth + 20; height: 26; radius: 13; color: root.card
                            Text { id: lt; anchors.centerIn: parent; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); color: root.fg; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: { lookProc.command = [root.cli, "profile", "apply", modelData]; lookProc.running = true; refresh.restart() } }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 32; radius: 16; color: root.accent
                    Text { anchors.centerIn: parent; text: "All settings"; color: root.accentFg; font.pixelSize: 13; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: { guiProc.command = [root.cli, "open"]; guiProc.running = true } }
                }
            }
        }
    }
}
