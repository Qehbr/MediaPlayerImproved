/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: configGeneral

    property alias cfg_volumeStep: volumeStep.value
    property alias cfg_hideWhenIdle: hideWhenIdle.checked
    property alias cfg_noArtworkIcon: noArtworkIcon.text
    property alias cfg_compactMaxWidth: compactMaxWidth.value
    property alias cfg_enableScrollingText: enableScrollingText.checked
    property alias cfg_scrollingTextSpeed: scrollingTextSpeed.value
    property alias cfg_compactShowControls: compactShowControls.checked
    property alias cfg_compactShowPrevious: compactShowPrevious.checked
    property alias cfg_compactShowPlayPause: compactShowPlayPause.checked
    property alias cfg_compactShowNext: compactShowNext.checked
    property alias cfg_compactShowProgress: compactShowProgress.checked
    property alias cfg_compactControlsSize: compactControlsSize.value
    property alias cfg_compactProgressHeight: compactProgressHeight.value
    property string cfg_compactProgressColor
    property string cfg_compactExtrasPosition
    property string cfg_compactControlsOrientation
    property alias cfg_compactProgressFirst: compactProgressFirst.checked
    property alias cfg_enableVisualizer: enableVisualizer.checked
    property alias cfg_visualizerUseRealAudio: visualizerUseRealAudio.checked
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
            Kirigami.FormData.label: i18n("General")
        }

        QQC2.SpinBox {
            id: volumeStep
            Kirigami.FormData.label: i18n("Volume adjustment step (%):")
            from: 1
            to: 20
            stepSize: 1
        }

        QQC2.CheckBox {
            id: hideWhenIdle
            Kirigami.FormData.label: i18n("Visibility:")
            text: i18n("Hide the widget when no media player is running")
        }

        QQC2.TextField {
            id: noArtworkIcon
            Kirigami.FormData.label: i18n("No-artwork icon:")
            placeholderText: "applications-multimedia"
            QQC2.ToolTip.text: i18n("Icon name shown when a track has no album art")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

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

        QQC2.CheckBox {
            id: compactShowControls
            Kirigami.FormData.label: i18n("Playback controls:")
            text: i18n("Show playback buttons in compact view")
        }

        QQC2.CheckBox {
            id: compactShowPrevious
            enabled: compactShowControls.checked
            text: i18n("Previous track button")
        }

        QQC2.CheckBox {
            id: compactShowPlayPause
            enabled: compactShowControls.checked
            text: i18n("Play / pause button")
        }

        QQC2.CheckBox {
            id: compactShowNext
            enabled: compactShowControls.checked
            text: i18n("Next track button")
        }

        QQC2.SpinBox {
            id: compactControlsSize
            Kirigami.FormData.label: i18n("Button icon size (px):")
            enabled: compactShowControls.checked
            from: 12
            to: 64
            stepSize: 2
        }

        QQC2.CheckBox {
            id: compactShowProgress
            Kirigami.FormData.label: i18n("Progress bar:")
            text: i18n("Show track progress in compact view")
        }

        QQC2.SpinBox {
            id: compactProgressHeight
            Kirigami.FormData.label: i18n("Progress bar height (px):")
            enabled: compactShowProgress.checked
            from: 2
            to: 24
            stepSize: 1
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Progress bar color:")
            enabled: compactShowProgress.checked

            KQuickControls.ColorButton {
                id: progressColorButton
                enabled: !progressThemeColor.checked
                showAlphaChannel: false
                dialogTitle: i18n("Select Progress Bar Color")
                color: configGeneral.cfg_compactProgressColor ? configGeneral.cfg_compactProgressColor : Kirigami.Theme.highlightColor
                onAccepted: {
                    progressThemeColor.checked = false;
                    configGeneral.cfg_compactProgressColor = color;
                }
            }
            QQC2.CheckBox {
                id: progressThemeColor
                text: i18n("Use theme default")
                checked: !configGeneral.cfg_compactProgressColor
                onToggled: configGeneral.cfg_compactProgressColor = checked ? "" : progressColorButton.color
            }
        }

        QQC2.ComboBox {
            id: compactExtrasPosition
            Kirigami.FormData.label: i18n("Controls position:")
            enabled: compactShowControls.checked || compactShowProgress.checked
            model: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Left of track"), value: "left" },
                { text: i18n("Right of track"), value: "right" },
                { text: i18n("Above track"), value: "top" },
                { text: i18n("Below track"), value: "bottom" }
            ]
            textRole: "text"
            currentIndex: {
                const pos = configGeneral.cfg_compactExtrasPosition
                const idx = model.findIndex(item => item.value === pos)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configGeneral.cfg_compactExtrasPosition = model[currentIndex].value
            }
        }

        QQC2.ComboBox {
            id: compactControlsOrientation
            Kirigami.FormData.label: i18n("Button layout:")
            enabled: compactShowControls.checked
            model: [
                { text: i18n("Horizontal"), value: "horizontal" },
                { text: i18n("Vertical"), value: "vertical" }
            ]
            textRole: "text"
            currentIndex: {
                const v = configGeneral.cfg_compactControlsOrientation
                const idx = model.findIndex(item => item.value === v)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configGeneral.cfg_compactControlsOrientation = model[currentIndex].value
            }
        }

        QQC2.CheckBox {
            id: compactProgressFirst
            Kirigami.FormData.label: i18n("Block order:")
            text: i18n("Progress bar above controls")
            enabled: compactShowProgress.checked && compactShowControls.checked
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
            id: visualizerUseRealAudio
            Kirigami.FormData.label: i18n("Audio source:")
            enabled: enableVisualizer.checked
            text: i18n("React to real audio (requires cava)")
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

        RowLayout {
            Kirigami.FormData.label: i18n("Bar color:")
            enabled: enableVisualizer.checked

            KQuickControls.ColorButton {
                id: visualizerColorButton
                enabled: !visualizerThemeColor.checked
                showAlphaChannel: false
                dialogTitle: i18n("Select Bar Color")
                color: configGeneral.cfg_visualizerColor ? configGeneral.cfg_visualizerColor : Kirigami.Theme.highlightColor
                onAccepted: {
                    visualizerThemeColor.checked = false;
                    configGeneral.cfg_visualizerColor = color;
                }
            }
            QQC2.CheckBox {
                id: visualizerThemeColor
                text: i18n("Use theme default")
                checked: !configGeneral.cfg_visualizerColor
                onToggled: configGeneral.cfg_visualizerColor = checked ? "" : visualizerColorButton.color
            }
        }
    }
}
