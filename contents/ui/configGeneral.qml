/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configGeneral

    property alias cfg_compactMaxWidth: compactMaxWidth.value
    property alias cfg_enableScrollingText: enableScrollingText.checked
    property alias cfg_scrollingTextSpeed: scrollingTextSpeed.value
    property alias cfg_enableVisualizer: enableVisualizer.checked
    property alias cfg_visualizerInCompact: visualizerInCompact.checked
    property string cfg_visualizerPositionCompact
    property alias cfg_visualizerInExpanded: visualizerInExpanded.checked
    property alias cfg_visualizerHeight: visualizerHeight.value
    property alias cfg_visualizerBars: visualizerBars.value
    property string cfg_visualizerColor
    property alias cfg_visualizerBehindOpacity: visualizerBehindOpacity.value

    Kirigami.FormLayout {

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Compact Representation")
        }

        QQC2.SpinBox {
            id: compactMaxWidth
            Kirigami.FormData.label: i18n("Maximum width (grid units):")
            from: 5
            to: 100
            stepSize: 1
        }

        QQC2.CheckBox {
            id: enableScrollingText
            Kirigami.FormData.label: i18n("Scrolling text:")
            text: i18n("Enable marquee scrolling for long text")
        }

        QQC2.SpinBox {
            id: scrollingTextSpeed
            Kirigami.FormData.label: i18n("Scroll speed (px/s):")
            enabled: enableScrollingText.checked
            from: 10
            to: 200
            stepSize: 10
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Audio Visualizer")
        }

        QQC2.CheckBox {
            id: enableVisualizer
            Kirigami.FormData.label: i18n("Enable visualizer:")
            text: i18n("Show audio frequency bars")
        }

        QQC2.CheckBox {
            id: visualizerInCompact
            Kirigami.FormData.label: i18n("Show in compact view:")
            enabled: enableVisualizer.checked
        }

        QQC2.ComboBox {
            id: visualizerPosition
            Kirigami.FormData.label: i18n("Compact position:")
            enabled: enableVisualizer.checked && visualizerInCompact.checked
            model: [
                { text: i18n("Bottom"), value: "bottom" },
                { text: i18n("Left"), value: "left" },
                { text: i18n("Right"), value: "right" },
                { text: i18n("Behind text"), value: "behind" }
            ]
            textRole: "text"
            currentIndex: {
                const pos = configGeneral.cfg_visualizerPositionCompact
                const idx = model.findIndex(item => item.value === pos)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configGeneral.cfg_visualizerPositionCompact = model[currentIndex].value
            }
        }

        QQC2.Slider {
            id: visualizerBehindOpacity
            Kirigami.FormData.label: i18n("Behind opacity:")
            enabled: enableVisualizer.checked && visualizerInCompact.checked && configGeneral.cfg_visualizerPositionCompact === "behind"
            from: 0.1
            to: 1.0
            stepSize: 0.05
            live: true

            QQC2.ToolTip {
                parent: visualizerBehindOpacity.handle
                visible: visualizerBehindOpacity.pressed
                text: (visualizerBehindOpacity.value * 100).toFixed(0) + "%"
            }
        }

        QQC2.CheckBox {
            id: visualizerInExpanded
            Kirigami.FormData.label: i18n("Show in expanded view:")
            enabled: enableVisualizer.checked
        }

        QQC2.SpinBox {
            id: visualizerHeight
            Kirigami.FormData.label: i18n("Visualizer height (pixels):")
            enabled: enableVisualizer.checked
            from: 10
            to: 100
            stepSize: 5
        }

        QQC2.SpinBox {
            id: visualizerBars
            Kirigami.FormData.label: i18n("Number of bars:")
            enabled: enableVisualizer.checked
            from: 5
            to: 50
            stepSize: 5
        }

        QQC2.Button {
            id: colorButton
            Kirigami.FormData.label: i18n("Bar color:")
            enabled: enableVisualizer.checked

            readonly property color currentColor: configGeneral.cfg_visualizerColor ? configGeneral.cfg_visualizerColor : Kirigami.Theme.highlightColor

            contentItem: Rectangle {
                implicitWidth: Kirigami.Units.gridUnit * 4
                implicitHeight: Kirigami.Units.gridUnit * 1.5
                color: colorButton.currentColor
                border.color: Kirigami.Theme.textColor
                border.width: 1
                radius: 3

                QQC2.Label {
                    anchors.centerIn: parent
                    text: configGeneral.cfg_visualizerColor ? configGeneral.cfg_visualizerColor : i18n("Theme default")
                    color: {
                        // Contrast check for text visibility
                        var c = colorButton.currentColor
                        var brightness = (c.r * 299 + c.g * 587 + c.b * 114) / 1000
                        return brightness > 0.5 ? "black" : "white"
                    }
                }
            }

            onClicked: colorDialog.open()

            QQC2.Menu {
                id: colorDialog
                QQC2.MenuItem {
                    text: i18n("Use theme color")
                    onClicked: configGeneral.cfg_visualizerColor = ""
                }
                QQC2.MenuItem {
                    text: i18n("Red")
                    onClicked: configGeneral.cfg_visualizerColor = "#e74c3c"
                }
                QQC2.MenuItem {
                    text: i18n("Green")
                    onClicked: configGeneral.cfg_visualizerColor = "#2ecc71"
                }
                QQC2.MenuItem {
                    text: i18n("Blue")
                    onClicked: configGeneral.cfg_visualizerColor = "#3498db"
                }
                QQC2.MenuItem {
                    text: i18n("Purple")
                    onClicked: configGeneral.cfg_visualizerColor = "#9b59b6"
                }
                QQC2.MenuItem {
                    text: i18n("Orange")
                    onClicked: configGeneral.cfg_visualizerColor = "#e67e22"
                }
                QQC2.MenuItem {
                    text: i18n("Yellow")
                    onClicked: configGeneral.cfg_visualizerColor = "#f1c40f"
                }
            }
        }
    }
}
