/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: visualizer

    property int maxBarCount: plasmoid.configuration.visualizerBars || 20
    property int barCount: {
        // Calculate how many bars can actually fit in the available width
        var minBarWidth = 3  // Minimum width for each bar
        var minSpacing = 2   // Minimum spacing between bars
        var maxBars = Math.floor(width / (minBarWidth + minSpacing))
        return Math.min(maxBarCount, Math.max(5, maxBars))
    }
    property bool isPlaying: root.isPlaying
    property color barColor: plasmoid.configuration.visualizerColor ? plasmoid.configuration.visualizerColor : Kirigami.Theme.highlightColor

    implicitHeight: plasmoid.configuration.visualizerHeight || 30

    Row {
        anchors.fill: parent
        spacing: Math.max(2, Math.min(parent.width / (visualizer.barCount * 3), 5))

        Repeater {
            id: barsRepeater
            model: barCount

            Rectangle {
                id: bar
                width: Math.max(2, (visualizer.width - (barCount - 1) * parent.spacing) / barCount)
                height: visualizer.height
                color: "transparent"

                property real targetHeight: 0.1
                property real currentHeight: 0.1

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * bar.currentHeight
                    radius: width / 3

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(visualizer.barColor, 1.3) }
                        GradientStop { position: 1.0; color: visualizer.barColor }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Timer {
                    interval: 50 + (index * 10)
                    running: visualizer.isPlaying && visualizer.visible
                    repeat: true
                    onTriggered: {
                        // Simulate frequency data with pseudo-random but smooth values
                        // In a real implementation, this would connect to PulseAudio
                        var baseIntensity = 0.3;
                        var variation = Math.sin(Date.now() / 1000 + index * 0.5) * 0.4;
                        var randomFactor = Math.random() * 0.3;

                        // Lower frequencies (first bars) typically have more energy
                        var frequencyFactor = 1.0 - (index / barCount) * 0.3;

                        bar.targetHeight = Math.max(0.1, Math.min(1.0,
                            (baseIntensity + variation + randomFactor) * frequencyFactor
                        ));

                        bar.currentHeight = bar.targetHeight;
                    }
                }

                Component.onCompleted: {
                    // Stagger initial animation
                    currentHeight = Math.random() * 0.3 + 0.1;
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
