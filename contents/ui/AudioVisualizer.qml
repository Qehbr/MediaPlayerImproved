/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: visualizer

    property int maxBarCount: plasmoid.configuration.visualizerBars || 20
    property int rawBarCount: {
        // Calculate how many bars can actually fit in the available width
        var minBarWidth = 3  // Minimum width for each bar
        var minSpacing = 2   // Minimum spacing between bars
        var maxBars = Math.floor(width / (minBarWidth + minSpacing))
        return Math.min(maxBarCount, Math.max(5, maxBars))
    }
    // cava requires an even number of bars for stereo input, so always use one.
    readonly property int barCount: Math.max(4, rawBarCount - (rawBarCount % 2))

    property bool isPlaying: root.isPlaying
    property color barColor: plasmoid.configuration.visualizerColor ? plasmoid.configuration.visualizerColor : Kirigami.Theme.highlightColor

    implicitHeight: plasmoid.configuration.visualizerHeight || 30

    // Per-bar heights (0..1), filled by real audio (cava) or, as a fallback,
    // by a simple simulated animation.
    property var levels: []

    // Only do work while actually playing and on screen.
    readonly property bool active: visualizer.isPlaying && visualizer.visible

    // Opt-in real audio via cava. Falls back to the simulation whenever no
    // fresh data is arriving (cava missing, disabled, paused, or starting up).
    readonly property bool useRealAudio: plasmoid.configuration.visualizerUseRealAudio === true
    readonly property bool wantCava: useRealAudio && active
    property double lastRealMs: 0
    readonly property bool realActive: useRealAudio && (Date.now() - lastRealMs < 600)

    readonly property string helperPath: Qt.resolvedUrl("../code/cava.sh").toString().replace("file://", "")
    property string cavaTag: ""
    property string cavaOut: ""

    // Long-running cava control (start) and one-shot stop (pkill). cava is
    // started via the executable engine, but the engine doesn't reliably kill
    // child processes, so we stop it explicitly with pkill on a unique tag.
    Plasma5Support.DataSource {
        id: cavaCtl
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => cavaCtl.disconnectSource(source)
    }

    // Reads the latest frame from cava's output file. (XMLHttpRequest can't read
    // local files in Plasma, so we cat it through the executable engine.)
    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            reader.disconnectSource(source);
            const txt = data.stdout;
            if (!txt) {
                return;
            }
            const parts = txt.split(";");
            let arr = [];
            for (let i = 0; i < parts.length; ++i) {
                if (parts[i] === "") {
                    continue;
                }
                const v = parseInt(parts[i], 10);
                if (!isNaN(v)) {
                    arr.push(Math.max(0.03, Math.min(1, v / 100)));
                }
            }
            if (arr.length > 0) {
                visualizer.levels = arr;
                visualizer.lastRealMs = Date.now();
            }
        }
    }

    function stopCava() {
        if (cavaTag !== "") {
            cavaCtl.connectSource("pkill -f mpi-cava-" + cavaTag);
            cavaTag = "";
            cavaOut = "";
        }
    }
    function startCava() {
        stopCava();
        cavaTag = "mpi" + Math.floor(Math.random() * 1e9);
        cavaOut = "/tmp/mpi-cava-" + cavaTag + ".dat";
        cavaCtl.connectSource("sh \"" + helperPath + "\" " + barCount + " " + cavaTag);
    }

    onWantCavaChanged: wantCava ? startCava() : stopCava()
    onBarCountChanged: if (wantCava) { startCava(); }
    Component.onCompleted: if (wantCava) { startCava(); }
    Component.onDestruction: stopCava()

    // Poll cava's latest frame.
    Timer {
        interval: 40 // ~25 fps
        repeat: true
        running: visualizer.wantCava
        onTriggered: if (visualizer.cavaOut !== "") {
            reader.connectSource("cat \"" + visualizer.cavaOut + "\"");
        }
    }

    // Simulated animation — used when real audio isn't active.
    Timer {
        interval: 60
        repeat: true
        running: visualizer.active && !visualizer.realActive
        onTriggered: {
            let arr = [];
            const now = Date.now() / 1000;
            for (let i = 0; i < visualizer.barCount; ++i) {
                const base = 0.3;
                const variation = Math.sin(now + i * 0.5) * 0.4;
                const randomFactor = Math.random() * 0.3;
                const frequencyFactor = 1.0 - (i / visualizer.barCount) * 0.3;
                arr.push(Math.max(0.1, Math.min(1.0, (base + variation + randomFactor) * frequencyFactor)));
            }
            visualizer.levels = arr;
        }
    }

    Row {
        anchors.fill: parent
        spacing: Math.max(2, Math.min(parent.width / (visualizer.barCount * 3), 5))

        Repeater {
            model: visualizer.barCount

            Rectangle {
                id: bar
                width: Math.max(2, (visualizer.width - (visualizer.barCount - 1) * parent.spacing) / visualizer.barCount)
                height: visualizer.height
                color: "transparent"

                readonly property real level: visualizer.levels[index] !== undefined ? visualizer.levels[index] : 0.1

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * bar.level
                    radius: width / 3

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(visualizer.barColor, 1.3) }
                        GradientStop { position: 1.0; color: visualizer.barColor }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    // Fade out when not playing
    // Note: When used in "behind" mode, parent sets a custom opacity which multiplies with this
    opacity: visualizer.isPlaying ? 1.0 : 0.3

    Behavior on opacity {
        NumberAnimation {
            duration: 500
            easing.type: Easing.InOutQuad
        }
    }
}
