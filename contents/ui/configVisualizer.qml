/*
    SPDX-FileCopyrightText: 2026 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: configVisualizer

    property alias cfg_enableVisualizer: enableVisualizer.checked
    property alias cfg_visualizerUseRealAudio: visualizerUseRealAudio.checked
    property string cfg_visualizerCavaSource
    property alias cfg_visualizerInCompact: visualizerInCompact.checked
    property string cfg_visualizerPositionCompact
    property alias cfg_visualizerBehindOpacity: visualizerBehindOpacity.value
    property alias cfg_visualizerInExpanded: visualizerInExpanded.checked
    property alias cfg_visualizerHeight: visualizerHeight.value
    property alias cfg_visualizerBars: visualizerBars.value

    Kirigami.FormLayout {

        QQC2.CheckBox {
            id: enableVisualizer
            Kirigami.FormData.label: i18n("Enable visualizer:")
            text: i18n("Show audio frequency bars")
        }

        QQC2.CheckBox {
            id: visualizerUseRealAudio
            Kirigami.FormData.label: i18n("Real audio:")
            enabled: enableVisualizer.checked
            text: i18n("React to real audio (requires cava)")
        }

        // Enumerate PulseAudio/PipeWire sources for the dropdown below.
        Plasma5Support.DataSource {
            id: sourcesProbe
            engine: "executable"
            connectedSources: []
            onNewData: (src, data) => {
                sourcesProbe.disconnectSource(src);
                let list = [{ text: i18n("Automatic (default output)"), value: "" }];
                const txt = data.stdout || "";
                const blocks = txt.split(/(?:^|\n)Source #[0-9]+/);
                for (let i = 0; i < blocks.length; ++i) {
                    const n = blocks[i].match(/\n\s*Name:\s*([^\n]+)/);
                    if (!n) {
                        continue;
                    }
                    const d = blocks[i].match(/\n\s*Description:\s*([^\n]+)/);
                    list.push({ text: d ? d[1] : n[1], value: n[1] });
                }
                cavaSource.sourceModel = list;
            }
            Component.onCompleted: connectSource("pactl list sources")
        }

        QQC2.ComboBox {
            id: cavaSource
            Kirigami.FormData.label: i18n("cava source:")
            enabled: enableVisualizer.checked && visualizerUseRealAudio.checked
            property var sourceModel: [{ text: i18n("Automatic (default output)"), value: "" }]
            model: sourceModel
            textRole: "text"
            currentIndex: {
                const v = configVisualizer.cfg_visualizerCavaSource;
                const idx = sourceModel.findIndex(item => item.value === v);
                return idx >= 0 ? idx : 0;
            }
            onActivated: configVisualizer.cfg_visualizerCavaSource = sourceModel[currentIndex].value
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Placement")
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
                const pos = configVisualizer.cfg_visualizerPositionCompact
                const idx = model.findIndex(item => item.value === pos)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                configVisualizer.cfg_visualizerPositionCompact = model[currentIndex].value
            }
        }

        QQC2.Slider {
            id: visualizerBehindOpacity
            Kirigami.FormData.label: i18n("Behind opacity:")
            enabled: enableVisualizer.checked && visualizerInCompact.checked && configVisualizer.cfg_visualizerPositionCompact === "behind"
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

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Bars")
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

        QQC2.Label {
            Kirigami.FormData.label: i18n("Bar color:")
            text: i18n("Set under Colors")
            opacity: 0.7
        }
    }
}
