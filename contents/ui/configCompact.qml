/*
    SPDX-FileCopyrightText: 2026 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configCompact

    property alias cfg_compactMaxWidth: compactMaxWidth.value
    property alias cfg_compactMinWidth: compactMinWidth.value
    property string cfg_compactAlbumArt
    property alias cfg_compactAlbumArtSize: compactAlbumArtSize.value
    property alias cfg_enableScrollingText: enableScrollingText.checked
    property alias cfg_scrollingTextSpeed: scrollingTextSpeed.value
    property alias cfg_compactShowControls: compactShowControls.checked
    property alias cfg_compactShowPrevious: compactShowPrevious.checked
    property alias cfg_compactShowPlayPause: compactShowPlayPause.checked
    property alias cfg_compactShowNext: compactShowNext.checked
    property alias cfg_compactControlsSize: compactControlsSize.value
    property alias cfg_compactShowProgress: compactShowProgress.checked
    property alias cfg_compactProgressHeight: compactProgressHeight.value
    property string cfg_compactControlsPosition
    property string cfg_compactProgressPosition
    property string cfg_compactControlsOrientation
    property alias cfg_compactProgressFirst: compactProgressFirst.checked

    Kirigami.FormLayout {

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Size")
        }

        QQC2.SpinBox {
            id: compactMaxWidth
            Kirigami.FormData.label: i18n("Maximum width (grid units):")
            from: 5
            to: 100
            stepSize: 1
        }

        QQC2.SpinBox {
            id: compactMinWidth
            Kirigami.FormData.label: i18n("Minimum width (grid units):")
            from: 0
            to: 100
            stepSize: 1
            QQC2.ToolTip.text: i18n("0 = automatic. Set equal to the maximum for a fixed width.")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        QQC2.ComboBox {
            id: compactAlbumArt
            Kirigami.FormData.label: i18n("Album art:")
            model: [
                { text: i18n("Hide"), value: "hide" },
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Set size"), value: "manual" },
            ]
            textRole: "text"
            // Show what the widget is actually doing. An empty setting means
            // this was never chosen, in which case a size carried over from
            // before still decides, the same way the widget reads it.
            readonly property string effectiveValue: {
                const stored = configCompact.cfg_compactAlbumArt
                if (stored === "hide" || stored === "auto" || stored === "manual") {
                    return stored
                }
                return configCompact.cfg_compactAlbumArtSize > 0 ? "manual" : "auto"
            }
            currentIndex: model.findIndex(item => item.value === compactAlbumArt.effectiveValue)
            onActivated: {
                configCompact.cfg_compactAlbumArt = model[currentIndex].value
                // Coming from automatic there is no size to show yet, so give
                // "Set size" something usable instead of a zero-height sliver.
                if (model[currentIndex].value === "manual" && configCompact.cfg_compactAlbumArtSize < 1) {
                    configCompact.cfg_compactAlbumArtSize = 25
                }
            }
        }

        QQC2.SpinBox {
            id: compactAlbumArtSize
            enabled: compactAlbumArt.effectiveValue === "manual"
            Kirigami.FormData.label: i18n("Album art size (px):")
            // Starts at 0 rather than 1 so that merely opening this dialog
            // cannot round an unset 0 up to 1 and write it back, which would
            // read afterwards as a size the user had deliberately chosen.
            from: 0
            to: 256
            stepSize: 5
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Text")
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
            Kirigami.FormData.label: i18n("Playback Controls")
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

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Progress Bar")
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

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Placement")
        }

        QQC2.ComboBox {
            id: compactControlsPosition
            Kirigami.FormData.label: i18n("Controls position:")
            enabled: compactShowControls.checked
            model: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Left of track"), value: "left" },
                { text: i18n("Right of track"), value: "right" },
                { text: i18n("Above track"), value: "top" },
                { text: i18n("Below track"), value: "bottom" }
            ]
            textRole: "text"
            currentIndex: {
                const pos = configCompact.cfg_compactControlsPosition
                const idx = model.findIndex(item => item.value === pos)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configCompact.cfg_compactControlsPosition = model[currentIndex].value
            }
        }

        QQC2.ComboBox {
            id: compactProgressPosition
            Kirigami.FormData.label: i18n("Progress bar position:")
            enabled: compactShowProgress.checked
            model: [
                { text: i18n("Automatic"), value: "auto" },
                { text: i18n("Left of track"), value: "left" },
                { text: i18n("Right of track"), value: "right" },
                { text: i18n("Above track"), value: "top" },
                { text: i18n("Below track"), value: "bottom" }
            ]
            textRole: "text"
            currentIndex: {
                const pos = configCompact.cfg_compactProgressPosition
                const idx = model.findIndex(item => item.value === pos)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configCompact.cfg_compactProgressPosition = model[currentIndex].value
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
                const v = configCompact.cfg_compactControlsOrientation
                const idx = model.findIndex(item => item.value === v)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configCompact.cfg_compactControlsOrientation = model[currentIndex].value
            }
        }

        QQC2.CheckBox {
            id: compactProgressFirst
            Kirigami.FormData.label: i18n("Block order:")
            text: i18n("Progress bar above controls")
            // Only matters when both share the same position.
            enabled: compactShowProgress.checked && compactShowControls.checked
                && configCompact.cfg_compactControlsPosition === configCompact.cfg_compactProgressPosition
        }
    }
}
