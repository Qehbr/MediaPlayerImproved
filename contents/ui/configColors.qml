/*
    SPDX-FileCopyrightText: 2026 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later

    Colour settings live together rather than with the thing they colour: most
    of them now cross both views -- the accent reaches the popup and the panel,
    and one progress colour drives the compact bar and the popup's seek slider
    -- so there is no single view they belong under any more.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: configColors

    property string cfg_accentColorSource
    property string cfg_accentColor
    property string cfg_compactTextColorSource
    property string cfg_compactTextColor
    property alias cfg_compactTextArtStrength: compactTextArtStrength.value
    property string cfg_compactProgressColorSource
    property string cfg_compactProgressColor
    property string cfg_visualizerColorSource
    property string cfg_visualizerColor
    property string cfg_expandedBackgroundSource
    property string cfg_expandedBackgroundColor

    Kirigami.FormLayout {

        QQC2.Label {
            Kirigami.FormData.label: i18n("Album art colors:")
            text: i18n("Read from the artwork on screen, so hidden artwork and the system tray fall back to the theme")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Controls")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Accent color:")

            QQC2.ComboBox {
                id: accentColorSource
                model: [
                    { text: i18n("Theme default"), value: "theme" },
                    { text: i18n("From album art"), value: "art" },
                    { text: i18n("Custom"), value: "custom" }
                ]
                textRole: "text"
                currentIndex: Math.max(0, model.findIndex(item => item.value === configColors.cfg_accentColorSource))
                onActivated: {
                    configColors.cfg_accentColorSource = model[currentIndex].value
                    if (model[currentIndex].value === "custom" && !configColors.cfg_accentColor) {
                        configColors.cfg_accentColor = accentColorButton.color
                    }
                }
            }
            KQuickControls.ColorButton {
                id: accentColorButton
                visible: configColors.cfg_accentColorSource === "custom"
                showAlphaChannel: false
                dialogTitle: i18n("Select Accent Color")
                color: configColors.cfg_accentColor ? configColors.cfg_accentColor : Kirigami.Theme.highlightColor
                onAccepted: configColors.cfg_accentColor = color
            }
            QQC2.Label {
                text: i18n("Playback buttons and the popup's player tabs")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Progress color:")
            // Not gated on the compact progress bar: this drives the popup's
            // seek slider as well, which is there either way.

            QQC2.ComboBox {
                id: progressColorSource
                model: [
                    { text: i18n("Theme default"), value: "theme" },
                    { text: i18n("From album art"), value: "art" },
                    { text: i18n("Custom"), value: "custom" }
                ]
                textRole: "text"
                // Empty means never chosen, in which case a colour already set
                // means it was custom -- the way it worked before this existed.
                readonly property string effectiveValue: {
                    const stored = configColors.cfg_compactProgressColorSource
                    if (stored === "theme" || stored === "art" || stored === "custom") {
                        return stored
                    }
                    return configColors.cfg_compactProgressColor ? "custom" : "theme"
                }
                currentIndex: model.findIndex(item => item.value === progressColorSource.effectiveValue)
                onActivated: {
                    configColors.cfg_compactProgressColorSource = model[currentIndex].value
                    if (model[currentIndex].value === "custom" && !configColors.cfg_compactProgressColor) {
                        configColors.cfg_compactProgressColor = progressColorButton.color
                    }
                }
            }
            KQuickControls.ColorButton {
                id: progressColorButton
                visible: progressColorSource.effectiveValue === "custom"
                showAlphaChannel: false
                dialogTitle: i18n("Select Progress Bar Color")
                color: configColors.cfg_compactProgressColor ? configColors.cfg_compactProgressColor : Kirigami.Theme.highlightColor
                onAccepted: configColors.cfg_compactProgressColor = color
            }
            QQC2.Label {
                text: i18n("Compact progress bar and the popup's seek slider")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Text")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Track text color:")

            QQC2.ComboBox {
                id: textColorSource
                model: [
                    { text: i18n("Theme default"), value: "theme" },
                    { text: i18n("From album art"), value: "art" },
                    { text: i18n("Custom"), value: "custom" }
                ]
                textRole: "text"
                currentIndex: Math.max(0, model.findIndex(item => item.value === configColors.cfg_compactTextColorSource))
                onActivated: {
                    configColors.cfg_compactTextColorSource = model[currentIndex].value
                    if (model[currentIndex].value === "custom" && !configColors.cfg_compactTextColor) {
                        configColors.cfg_compactTextColor = textColorButton.color
                    }
                }
            }
            KQuickControls.ColorButton {
                id: textColorButton
                visible: configColors.cfg_compactTextColorSource === "custom"
                showAlphaChannel: false
                dialogTitle: i18n("Select Track Text Color")
                color: configColors.cfg_compactTextColor ? configColors.cfg_compactTextColor : Kirigami.Theme.textColor
                onAccepted: configColors.cfg_compactTextColor = color
            }
            QQC2.Label {
                visible: configColors.cfg_compactTextColorSource === "art"
                text: i18n("Lightened or darkened as needed to stay readable")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        QQC2.SpinBox {
            id: compactTextArtStrength
            Kirigami.FormData.label: i18n("Text color strength (%):")
            enabled: configColors.cfg_compactTextColorSource === "art"
            from: 0
            to: 100
            stepSize: 10
            QQC2.ToolTip.text: i18n("How far the text is taken towards the album art's color. Lower values keep it closer to the theme's own text color, which reads more calmly at small sizes.")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Visualizer")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Bar color:")

            QQC2.ComboBox {
                id: visualizerColorSource
                model: [
                    { text: i18n("Theme default"), value: "theme" },
                    { text: i18n("From album art"), value: "art" },
                    { text: i18n("Custom"), value: "custom" }
                ]
                textRole: "text"
                readonly property string effectiveValue: {
                    const stored = configColors.cfg_visualizerColorSource
                    if (stored === "theme" || stored === "art" || stored === "custom") {
                        return stored
                    }
                    return configColors.cfg_visualizerColor ? "custom" : "theme"
                }
                currentIndex: model.findIndex(item => item.value === visualizerColorSource.effectiveValue)
                onActivated: {
                    configColors.cfg_visualizerColorSource = model[currentIndex].value
                    if (model[currentIndex].value === "custom" && !configColors.cfg_visualizerColor) {
                        configColors.cfg_visualizerColor = visualizerColorButton.color
                    }
                }
            }
            KQuickControls.ColorButton {
                id: visualizerColorButton
                visible: visualizerColorSource.effectiveValue === "custom"
                showAlphaChannel: false
                dialogTitle: i18n("Select Bar Color")
                color: configColors.cfg_visualizerColor ? configColors.cfg_visualizerColor : Kirigami.Theme.highlightColor
                onAccepted: configColors.cfg_visualizerColor = color
            }
            QQC2.Label {
                text: i18n("Theme default follows the accent color")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Expanded View")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Popup background:")

            QQC2.ComboBox {
                id: expandedBackgroundSource
                model: [
                    { text: i18n("Blurred album art"), value: "artwork" },
                    { text: i18n("From album art"), value: "art" },
                    { text: i18n("Theme default"), value: "theme" },
                    { text: i18n("Custom"), value: "custom" }
                ]
                textRole: "text"
                currentIndex: Math.max(0, model.findIndex(item => item.value === configColors.cfg_expandedBackgroundSource))
                onActivated: {
                    configColors.cfg_expandedBackgroundSource = model[currentIndex].value
                    if (model[currentIndex].value === "custom" && !configColors.cfg_expandedBackgroundColor) {
                        configColors.cfg_expandedBackgroundColor = expandedBackgroundButton.color
                    }
                }
            }
            KQuickControls.ColorButton {
                id: expandedBackgroundButton
                visible: configColors.cfg_expandedBackgroundSource === "custom"
                showAlphaChannel: false
                dialogTitle: i18n("Select Popup Background Color")
                color: configColors.cfg_expandedBackgroundColor ? configColors.cfg_expandedBackgroundColor : Kirigami.Theme.backgroundColor
                onAccepted: configColors.cfg_expandedBackgroundColor = color
            }
        }
    }
}
