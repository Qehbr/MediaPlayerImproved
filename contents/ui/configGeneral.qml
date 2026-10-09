/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

KCM.SimpleKCM {
    id: configGeneral

    property alias cfg_volumeStep: volumeStep.value
    property alias cfg_hideWhenIdle: hideWhenIdle.checked
    property alias cfg_noArtworkIcon: noArtworkIcon.text
    property var cfg_ignoredPlayers: []

    // A player is stored by its desktop entry, which stays the same between
    // runs, or by its name if it has none; the widget matches either.
    function isIgnored(key) {
        const id = key.toLowerCase();
        return configGeneral.cfg_ignoredPlayers.some(entry => entry.toLowerCase() === id);
    }
    function setIgnored(key, ignored) {
        const id = key.toLowerCase();
        const others = configGeneral.cfg_ignoredPlayers.filter(entry => entry.toLowerCase() !== id);
        configGeneral.cfg_ignoredPlayers = ignored ? others.concat([key]) : others;
    }

    // Players to offer: the ones already ignored, and any that are running.
    // Entries are only ever added while the page is open, never removed, so an
    // unticked player stays listed to be ticked again, and the list does not
    // rebuild, and lose keyboard focus, on every tick.
    ListModel {
        id: playerChoices
    }
    function offerPlayer(key, name) {
        if (!key) {
            return;
        }
        const id = key.toLowerCase();
        for (let i = 0; i < playerChoices.count; ++i) {
            if (playerChoices.get(i).key.toLowerCase() === id) {
                if (name) {
                    playerChoices.setProperty(i, "name", name);
                }
                return;
            }
        }
        playerChoices.append({ key: key, name: name || key });
    }
    function offerIgnoredPlayers() {
        for (const key of configGeneral.cfg_ignoredPlayers) {
            configGeneral.offerPlayer(key, "");
        }
    }
    Component.onCompleted: offerIgnoredPlayers()
    onCfg_ignoredPlayersChanged: offerIgnoredPlayers()

    Instantiator {
        model: Mpris.Mpris2Model {}
        delegate: QtObject {
            required property bool isMultiplexer
            required property string desktopEntry
            required property string identity
        }
        onObjectAdded: (index, row) => {
            if (!row.isMultiplexer) {
                configGeneral.offerPlayer(row.desktopEntry || row.identity, row.identity);
            }
        }
    }

    Kirigami.FormLayout {

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

        ColumnLayout {
            id: ignoredPlayersColumn
            // Line the label up with the first player rather than the middle
            // of the list.
            property Item firstChoice: null
            Kirigami.FormData.label: i18n("Ignored players:")
            Kirigami.FormData.buddyFor: firstChoice ?? noPlayersLabel
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: ignoredPlayerList
                model: playerChoices
                onItemAdded: (index, item) => {
                    if (index === 0) {
                        ignoredPlayersColumn.firstChoice = item;
                    }
                }
                delegate: QQC2.CheckBox {
                    required property string key
                    required property string name
                    text: name
                    checked: configGeneral.isIgnored(key)
                    onToggled: configGeneral.setIgnored(key, checked)
                }
            }
            QQC2.Label {
                id: noPlayersLabel
                visible: playerChoices.count === 0
                text: i18n("Start a media player to choose it here")
                opacity: 0.7
            }
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                text: i18n("Ignored players are left out as if they weren't running, and don't keep the widget visible when it hides while idle")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        QQC2.TextField {
            id: noArtworkIcon
            Kirigami.FormData.label: i18n("No-artwork icon:")
            placeholderText: "applications-multimedia"
            QQC2.ToolTip.text: i18n("Icon name shown when a track has no album art")
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        }
    }
}
