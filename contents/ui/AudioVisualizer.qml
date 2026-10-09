/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../code/colorsource.js" as ColorSource

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
    // Kept even so cava's stereo output, the left channel's bars then the
    // right's, still splits down the middle once averaged down.
    readonly property int barCount: Math.max(4, rawBarCount - (rawBarCount % 2))

    property bool isPlaying: root.isPlaying

    // Supplied by whoever places the visualizer, since only they can see the
    // album art item the colour has to be read from.
    property color artColor: Kirigami.Theme.highlightColor

    property color barColor: ColorSource.resolve(plasmoid.configuration.visualizerColorSource,
                                                 plasmoid.configuration.visualizerColor,
                                                 visualizer.artColor,
                                                 Kirigami.Theme.highlightColor)

    implicitHeight: plasmoid.configuration.visualizerHeight || 30

    // Only do work while actually playing and on screen.
    readonly property bool active: visualizer.isPlaying && visualizer.visible

    // Real audio comes from the widget's one shared cava (see main.qml). This
    // visualizer only reads it, and falls back to the animation whenever no
    // fresh frames are arriving: cava missing, disabled, paused or starting up.
    readonly property bool useRealAudio: plasmoid.configuration.visualizerUseRealAudio === true
    readonly property bool realActive: visualizer.useRealAudio && root.cavaLive

    // Only a visualizer that is being drawn reads the shared frames, so the
    // compact view's hidden alternatives cost nothing at 25 frames a second.
    readonly property var realLevels: (visualizer.active && visualizer.realActive)
        ? visualizer.fitLevels(root.cavaLevels, visualizer.barCount) : []
    property var simulatedLevels: []

    // Per-bar heights, 0 to 1.
    readonly property var levels: visualizer.realActive ? visualizer.realLevels : visualizer.simulatedLevels

    // Fits the shared frame to this visualizer's bar count by averaging
    // neighbouring bars, or repeating them in the unlikely case it has more.
    function fitLevels(source, count) {
        const n = source.length;
        if (n === 0 || count <= 0) {
            return [];
        }
        if (n === count) {
            return source;
        }
        let fitted = [];
        for (let i = 0; i < count; ++i) {
            const from = Math.floor(i * n / count);
            const to = Math.max(from + 1, Math.floor((i + 1) * n / count));
            let sum = 0;
            for (let j = from; j < to; ++j) {
                sum += source[j];
            }
            fitted.push(sum / (to - from));
        }
        return fitted;
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
            visualizer.simulatedLevels = arr;
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
