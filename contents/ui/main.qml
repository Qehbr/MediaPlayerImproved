/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2020 Ismael Asensio <isma.af@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 10

    readonly property int volumePercentStep: plasmoid.configuration.volumeStep

    // BEGIN model properties
    readonly property string track: root.player?.track ?? ""
    readonly property string artist: root.player?.artist ?? ""
    readonly property string album: root.player?.album ?? ""
    readonly property string albumArt: root.player?.artUrl ?? ""
    readonly property string identity: root.player?.identity ?? ""
    readonly property bool canControl: root.player?.canControl ?? false
    readonly property bool canGoPrevious: root.player?.canGoPrevious ?? false
    readonly property bool canGoNext: root.player?.canGoNext ?? false
    readonly property bool canPlay: root.player?.canPlay ?? false
    readonly property bool canPause: root.player?.canPause ?? false
    readonly property bool canStop: root.player?.canStop ?? false
    readonly property int playbackStatus: root.player?.playbackStatus ?? 0
    readonly property bool isPlaying: root.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canRaise: root.player?.canRaise ?? false
    readonly property bool canQuit: root.player?.canQuit ?? false
    readonly property int shuffle: root.player?.shuffle ?? 0
    readonly property int loopStatus: root.player?.loopStatus ?? 0
    readonly property real playbackRate: root.player?.rate ?? 1.0
    readonly property real minimumPlaybackRate: root.player?.minimumRate ?? 1.0
    readonly property real maximumPlaybackRate: root.player?.maximumRate ?? 1.0
    // END model properties

    Plasmoid.icon: switch (root.playbackStatus) {
    case Mpris.PlaybackStatus.Playing:
        return "media-playback-playing-symbolic";
    case Mpris.PlaybackStatus.Paused:
        return "media-playback-paused-symbolic";
    default:
        return "media-playback-stopped-symbolic";
    }
    // With "hide when idle" on, hide entirely only when no media player is
    // running, not counting ignored ones; otherwise behave normally (passive
    // when stopped, active when playing) so an open player stays available in
    // the panel.
    readonly property bool hasActivePlayer: root.player !== null
    readonly property int idleStatus: (plasmoid.configuration.hideWhenIdle && !root.hasActivePlayer)
        ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.status: root.idleStatus
    // Re-apply when the player appears/disappears or the setting is toggled while idle.
    onIdleStatusChanged: if (root.playbackStatus <= Mpris.PlaybackStatus.Stopped) {
        Plasmoid.status = root.idleStatus;
    }
    toolTipMainText: root.playbackStatus > Mpris.PlaybackStatus.Stopped ? root.track : i18n("No media playing")
    toolTipSubText: switch (root.playbackStatus) {
    case Mpris.PlaybackStatus.Playing:
        return root.artist ? i18nc("@info:tooltip %1 is a musical artist and %2 is an app name", "by %1 (%2)\nMiddle-click to pause\nScroll to adjust volume", root.artist, root.identity)
            : i18nc("@info:tooltip %1 is an app name", "%1\nMiddle-click to pause\nScroll to adjust volume", root.identity)
    case Mpris.PlaybackStatus.Paused:
        return root.artist ? i18nc("@info:tooltip %1 is a musical artist and %2 is an app name", "by %1 (paused, %2)\nMiddle-click to play\nScroll to adjust volume", root.artist, root.identity)
            : i18nc("@info:tooltip %1 is an app name", "Paused (%1)\nMiddle-click to play\nScroll to adjust volume", root.identity)
    default:
        return "";
    }
    toolTipTextFormat: Text.PlainText

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: ExpandedRepresentation {}

    // HACK Some players like Amarok take quite a while to load the next track
    // this avoids having the plasmoid jump between popup and panel
    onPlaybackStatusChanged: {
        if (root.playbackStatus > Mpris.PlaybackStatus.Stopped) {
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
        } else {
            updatePlasmoidStatusTimer.restart()
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.player?.updatePosition();
        }
    }

    Timer {
        id: updatePlasmoidStatusTimer
        interval: Kirigami.Units.humanMoment
        onTriggered: {
            if (root.playbackStatus > Mpris.PlaybackStatus.Stopped) {
                Plasmoid.status = PlasmaCore.Types.ActiveStatus
            } else {
                Plasmoid.status = root.idleStatus
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("Open player window or bring it to the front if already open", "Open")
            icon.name: "go-up-symbolic"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canRaise
            onTriggered: root.raise()
        },
        PlasmaCore.Action {
            text: i18nc("Play previous track", "Previous Track")
            icon.name: Application.layoutDirection === Qt.RightToLeft ? "media-skip-forward" : "media-skip-backward"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canControl
            enabled: root.canGoPrevious
            onTriggered: root.previous()
        },
        PlasmaCore.Action {
            text: i18nc("Pause playback", "Pause")
            icon.name: "media-playback-pause"
            priority: PlasmaCore.Action.LowPriority
            visible: root.isPlaying && root.canPause
            enabled: visible
            onTriggered: root.pause()
        },
        PlasmaCore.Action {
            text: i18nc("Start playback", "Play")
            icon.name: "media-playback-start"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canControl && !root.isPlaying
            enabled: root.canPlay
            onTriggered: root.play()
        },
        PlasmaCore.Action {
            text: i18nc("Play next track", "Next Track")
            icon.name: Application.layoutDirection === Qt.RightToLeft ? "media-skip-backward" : "media-skip-forward"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canControl
            enabled: root.canGoNext
            onTriggered: root.next()
        },
        PlasmaCore.Action {
            text: i18nc("Stop playback", "Stop")
            icon.name: "media-playback-stop"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canControl
            enabled: root.canStop
            onTriggered: root.stop()
        },
        PlasmaCore.Action {
            isSeparator: true
            priority: PlasmaCore.Action.LowPriority
            visible: root.canQuit
        },
        PlasmaCore.Action {
            text: i18nc("Quit player", "Quit")
            icon.name: "application-exit"
            priority: PlasmaCore.Action.LowPriority
            visible: root.canQuit
            onTriggered: root.quit()
        }
    ]

    function previous() {
        root.player.Previous();
    }
    function next() {
        root.player.Next();
    }
    function play() {
        root.player.Play();
    }
    function pause() {
        root.player.Pause();
    }
    function togglePlaying() {
        if (root.isPlaying) {
            root.player.Pause();
        } else {
            root.player.Play();
        }
    }
    function stop() {
        root.player.Stop();
    }
    function quit() {
        root.player.Quit();
    }
    function raise() {
        root.player.Raise();
    }

    Mpris.Mpris2Model {
        id: mpris2Model
    }

    // BEGIN ignored players
    //
    // Players picked under General > Ignored players are treated as if they
    // were not running: the widget never shows them, the popup has no tab for
    // them, and they do not keep a widget that hides when idle visible (#23).
    // Each entry is a player's desktop entry, or its name if it has none.

    readonly property var ignoredPlayers: (plasmoid.configuration.ignoredPlayers || [])
        .map(key => key.toLowerCase())

    function isIgnored(desktopEntry, identity) {
        return root.ignoredPlayers.length > 0
            && (root.ignoredPlayers.includes((desktopEntry || "").toLowerCase())
                || root.ignoredPlayers.includes((identity || "").toLowerCase()));
    }

    // The player the widget shows and controls. Usually the model's own pick,
    // but when that is an ignored player, the best of the others instead: one
    // that is playing, then one that is paused, then any. Null when only
    // ignored players are running.
    readonly property var player: {
        const current = mpris2Model.currentPlayer;
        if (!current || !root.isIgnored(current.desktopEntry, current.identity)) {
            return current;
        }
        let best = null;
        let bestRank = -1;
        for (const row of root.playerRowList) {
            if (row.isMultiplexer || row.ignored || !row.container) {
                continue;
            }
            const status = row.container.playbackStatus;
            const rank = status === Mpris.PlaybackStatus.Playing ? 2
                : status === Mpris.PlaybackStatus.Paused ? 1 : 0;
            if (rank > bestRank) {
                best = row.container;
                bestRank = rank;
            }
        }
        return best;
    }

    // How many players the popup offers a tab for.
    readonly property int shownPlayerCount: root.playerRowList
        .filter(row => !row.isMultiplexer && !row.ignored).length

    // The model's rows as objects, to look through the players from a binding.
    property var playerRowList: []
    Instantiator {
        id: playerRows
        model: mpris2Model
        delegate: QtObject {
            required property var container
            required property bool isMultiplexer
            required property string desktopEntry
            required property string identity
            readonly property bool ignored: root.isIgnored(desktopEntry, identity)
        }
        onObjectAdded: root.refreshPlayerRows()
        onObjectRemoved: root.refreshPlayerRows()
    }
    function refreshPlayerRows() {
        const rows = [];
        for (let i = 0; i < playerRows.count; ++i) {
            const row = playerRows.objectAt(i);
            if (row) {
                rows.push(row);
            }
        }
        root.playerRowList = rows;
    }

    // A tab picked in the popup whose player is then ignored would leave the
    // widget on a player with no tab to switch away from; go back to choosing
    // automatically instead.
    readonly property bool pickedPlayerIgnored: mpris2Model.currentIndex > 0
        && mpris2Model.currentPlayer !== null
        && root.isIgnored(mpris2Model.currentPlayer.desktopEntry, mpris2Model.currentPlayer.identity)
    onPickedPlayerIgnoredChanged: if (root.pickedPlayerIgnored) {
        mpris2Model.currentIndex = 0;
    }
    // END ignored players

    // BEGIN shared cava
    //
    // One cava for the whole widget, read by every visualizer in it. Each
    // visualizer used to run its own, and fitted as many bars as its width
    // allowed -- the panel and the popup wanted different counts, and cava's
    // bar count is fixed per process, so they could not share. Now cava runs at
    // the configured bar count, the most any visualizer will show, and each one
    // averages that down to what fits. Opening the popup no longer starts a
    // second cava that takes a moment to get going, and resizing the panel no
    // longer restarts anything.
    //
    // It belongs to the widget rather than to the visualizers, so a visualizer
    // being torn down and rebuilt -- every song change in a browser, whose title
    // goes briefly empty and rebuilds the compact view -- never touches it.

    readonly property bool cavaRealAudio: plasmoid.configuration.visualizerUseRealAudio === true
    readonly property string cavaSource: plasmoid.configuration.visualizerCavaSource || ""
    // cava needs an even number of bars for stereo input.
    readonly property int cavaBars: {
        const wanted = plasmoid.configuration.visualizerBars || 20;
        return Math.max(4, wanted - (wanted % 2));
    }
    // Some visualizer is actually being drawn: the panel's whenever it is
    // enabled, the popup's only while the popup is open.
    readonly property bool cavaWanted: root.cavaRealAudio
        && root.isPlaying
        && plasmoid.configuration.enableVisualizer !== false
        && (plasmoid.configuration.visualizerInCompact !== false
            || (plasmoid.configuration.visualizerInExpanded !== false && root.expanded))

    // The latest frame, cavaBars levels from 0 to 1, and whether frames are
    // still arriving. Visualizers fall back to their animation when they stop.
    property var cavaLevels: []
    property bool cavaLive: false

    property string cavaTag: ""
    property string cavaOut: ""
    readonly property string cavaHelper: Qt.resolvedUrl("../code/cava.sh").toString().replace("file://", "")
    // Names this widget to the helper, so a start can clean up its own
    // predecessor without touching another instance of the widget.
    readonly property string cavaVizId: (plasmoid.id !== undefined ? plasmoid.id : 0) + "xshared"

    function cavaStart() {
        root.cavaStop();
        // Zero-padded to a fixed width: equal-length tags can never be a
        // substring of one another, so the stop pkill cannot confuse two.
        root.cavaTag = "mpi" + ("00000000" + Math.floor(Math.random() * 1e9)).slice(-9);
        root.cavaOut = "/tmp/mpi-cava-" + root.cavaTag + ".dat";
        cavaCtl.connectSource("sh \"" + root.cavaHelper + "\" " + root.cavaBars + " " + root.cavaTag
            + " \"" + root.cavaSource + "\" " + root.cavaVizId);
    }

    function cavaStop() {
        cavaStopTimer.stop();
        if (root.cavaTag !== "") {
            cavaCtl.connectSource("pkill -f mpi-cava-" + root.cavaTag);
            root.cavaTag = "";
            root.cavaOut = "";
        }
        root.cavaLive = false;
    }

    // Start straight away, but stop only once nothing has wanted cava for a
    // moment, the same allowance this file already gives players that take a
    // while to load the next track. A brief pause between songs then never
    // restarts it.
    onCavaWantedChanged: {
        if (root.cavaWanted) {
            cavaStopTimer.stop();
            if (root.cavaTag === "") {
                root.cavaStart();
            }
        } else {
            cavaStopTimer.restart();
        }
    }
    onCavaBarsChanged: if (root.cavaTag !== "") root.cavaStart()
    onCavaSourceChanged: if (root.cavaTag !== "") root.cavaStart()
    Component.onCompleted: if (root.cavaWanted) root.cavaStart()
    Component.onDestruction: root.cavaStop()

    Timer {
        id: cavaStopTimer
        interval: Kirigami.Units.humanMoment
        onTriggered: if (!root.cavaWanted) root.cavaStop()
    }

    // Long-running start and one-shot stop. The executable engine does not
    // reliably kill child processes, so stopping is an explicit pkill on the tag.
    Plasma5Support.DataSource {
        id: cavaCtl
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => cavaCtl.disconnectSource(source)
    }

    // Reads the latest frame. XMLHttpRequest cannot read local files in Plasma,
    // so it is cat'd through the executable engine; once for the whole widget
    // now, rather than once per visualizer.
    Plasma5Support.DataSource {
        id: cavaReader
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            cavaReader.disconnectSource(source);
            const txt = data.stdout;
            if (!txt) {
                return;
            }
            const parts = txt.split(";");
            let levels = [];
            for (let i = 0; i < parts.length; ++i) {
                if (parts[i] === "") {
                    continue;
                }
                const v = parseInt(parts[i], 10);
                if (!isNaN(v)) {
                    levels.push(Math.max(0.03, Math.min(1, v / 100)));
                }
            }
            if (levels.length > 0) {
                root.cavaLevels = levels;
                root.cavaLive = true;
                cavaStaleTimer.restart();
            }
        }
    }

    Timer {
        interval: 40 // ~25 fps
        repeat: true
        running: root.cavaTag !== ""
        onTriggered: if (root.cavaOut !== "") {
            cavaReader.connectSource("cat \"" + root.cavaOut + "\"");
        }
    }

    // Frames stopped arriving -- cava missing, failed or restarting. A timer
    // rather than comparing against the clock in a binding: a binding is only
    // re-evaluated when something it reads changes, and the clock is not one of
    // those things, so the old check never noticed and left the bars frozen on
    // the last frame instead of falling back to the animation.
    Timer {
        id: cavaStaleTimer
        interval: 600
        onTriggered: root.cavaLive = false
    }
    // END shared cava
}
