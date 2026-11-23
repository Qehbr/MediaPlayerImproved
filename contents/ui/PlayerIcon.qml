// SPDX-License-Identifier: LGPL-2.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../code/playericons.js" as PlayerIcons

// Own the artwork and badge instead of depending on TabButton's private content.
Item {
    id: root

    property string modelIconName: ""
    property string desktopEntry: ""
    property string identity: ""
    property bool isMultiplexer: false
    property bool active: false
    property bool refreshEnabled: false
    property int refreshInterval: 5000
    property int iconSize: Kirigami.Units.iconSizes.smallMedium

    readonly property bool remotePlayer: PlayerIcons.isRemotePlayer(desktopEntry, isMultiplexer)
    readonly property var candidates: PlayerIcons.iconCandidates(modelIconName, desktopEntry, identity, isMultiplexer)
    readonly property string resolvedIconName: candidates[Math.min(candidateIndex, candidates.length - 1)] || ""
    readonly property alias status: artwork.status
    readonly property alias badge: deviceBadge
    readonly property alias artwork: artwork

    property int candidateIndex: 0
    property bool reloading: false

    implicitWidth: iconSize
    implicitHeight: iconSize

    signal lookupRetried()

    onCandidatesChanged: candidateIndex = 0

    Kirigami.Icon {
        id: artwork
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        active: root.active
        source: root.reloading ? "" : root.resolvedIconName

        onStatusChanged: {
            if (status === Kirigami.Icon.Error && root.candidateIndex + 1 < root.candidates.length) {
                advanceCandidate.restart();
            }
        }

        Kirigami.Icon {
            id: deviceBadge
            visible: root.remotePlayer
            source: "kdeconnect"
            width: Math.round(root.iconSize * 0.65)
            height: width
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2
            anchors.bottomMargin: -2
        }
    }

    Timer {
        id: advanceCandidate
        interval: 0
        onTriggered: {
            if (artwork.status === Kirigami.Icon.Error && root.candidateIndex + 1 < root.candidates.length) {
                root.candidateIndex++;
            }
        }
    }

    Timer {
        id: reloadIcon
        interval: 0
        onTriggered: root.reloading = false
    }

    // An icon may be installed while the popup is open. A fresh source lookup
    // makes that icon visible; resolved, hidden, and automatic tabs never poll.
    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.refreshEnabled && root.visible && root.remotePlayer
            && artwork.status === Kirigami.Icon.Error
            && root.candidateIndex + 1 >= root.candidates.length
        onTriggered: {
            root.reloading = true;
            root.candidateIndex = 0;
            root.lookupRetried();
            reloadIcon.restart();
        }
    }
}
