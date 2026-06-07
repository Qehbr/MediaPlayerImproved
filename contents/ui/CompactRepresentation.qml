/*
    SPDX-FileCopyrightText: 2022 Fushan Wen <qydwhotmail@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/**
 * [Album Art][Now Playing]
 */
Loader {
    id: compactRepresentation

    Layout.fillWidth: layoutForm !== CompactRepresentation.LayoutType.HorizontalPanel && layoutForm !== CompactRepresentation.LayoutType.HorizontalDesktop
    Layout.fillHeight: layoutForm !== CompactRepresentation.LayoutType.VerticalPanel && layoutForm !== CompactRepresentation.LayoutType.VerticalDesktop

    Layout.preferredWidth: {
        switch (compactRepresentation.layoutForm) {
        case CompactRepresentation.LayoutType.HorizontalPanel:
        case CompactRepresentation.LayoutType.HorizontalDesktop:
            return implicitWidth;
        default:
            return -1;
        }
    }
    Layout.preferredHeight: {
        switch (compactRepresentation.layoutForm) {
        case CompactRepresentation.LayoutType.VerticalPanel:
        case CompactRepresentation.LayoutType.VerticalDesktop:
            return implicitHeight;
        default:
            return -1;
        }
    }

    Layout.maximumWidth: layoutForm === CompactRepresentation.LayoutType.HorizontalPanel ? (Kirigami.Units.gridUnit * (plasmoid.configuration.compactMaxWidth || 15) + compactRepresentation.height + Kirigami.Units.smallSpacing) : -1

    enum LayoutType {
        Tray,
        HorizontalPanel,
        VerticalPanel,
        HorizontalDesktop,
        VerticalDesktop,
        IconOnly
    }

    readonly property int layoutForm: {
        if (compactRepresentation.inTray) {
            return CompactRepresentation.LayoutType.Tray;
        } else if (compactRepresentation.inPanel) {
            return compactRepresentation.isVertical ? CompactRepresentation.LayoutType.VerticalPanel : CompactRepresentation.LayoutType.HorizontalPanel;
        } else if (compactRepresentation.item instanceof GridLayout) {
            if (compactRepresentation.parent.width > compactRepresentation.parent.height + (compactRepresentation.item as GridLayout).columnSpacing) {
                return CompactRepresentation.LayoutType.HorizontalDesktop;
            } else if (compactRepresentation.parent.height - compactRepresentation.parent.width >= compactRepresentation.item.labelHeight + (compactRepresentation.item as GridLayout).rowSpacing) {
                return CompactRepresentation.LayoutType.VerticalDesktop;
            }
        }
        return CompactRepresentation.LayoutType.IconOnly;
    }
    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge].includes(Plasmoid.location)
    readonly property bool inTray: parent.objectName === "org.kde.desktop-CompactApplet"

    sourceComponent: {
        if (root.track.length === 0) {
            // No player running at all: optionally show nothing instead of an icon.
            // If a player is open but idle, keep the icon so it can be controlled.
            return (plasmoid.configuration.hideWhenIdle && mpris2Model.currentPlayer === null) ? null : icon;
        }
        return inTray ? icon : playerRow;
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        hoverEnabled: compactRepresentation.item instanceof Kirigami.Icon
        property int wheelDelta: 0
        onWheel: wheel => {
            if (mpris2Model.currentPlayer === null) {
                return;
            }
            wheelDelta += (wheel.inverted ? -1 : 1) * (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x)
            while (wheelDelta >= 120) {
                wheelDelta -= 120;
                mpris2Model.currentPlayer.changeVolume(root.volumePercentStep / 100, true);
            }
            while (wheelDelta <= -120) {
                wheelDelta += 120;
                mpris2Model.currentPlayer.changeVolume(-root.volumePercentStep / 100, true);
            }
        }
        onClicked: (mouse) => {
            switch (mouse.button) {
            case Qt.MiddleButton:
                root.togglePlaying()
                break
            case Qt.BackButton:
                if (root.canGoPrevious) {
                    root.previous();
                }
                break
            case Qt.ForwardButton:
                if (root.canGoNext) {
                    root.next();
                }
                break
            default:
                root.expanded = !root.expanded
            }
        }
    }

    Component {
        id: icon
        Kirigami.Icon {
            active: mouseArea.containsMouse
            source: Plasmoid.icon
        }
    }

    Component {
        id: playerRow
        GridLayout {
            id: grid
            readonly property real labelHeight: songTitle.implicitHeight

            // Sit above the click-to-expand/scroll MouseArea so the optional
            // playback buttons can receive clicks; non-interactive parts (art,
            // text) don't consume events, so they still fall through to it.
            z: 1

            // Extra controls show everywhere except the system tray and
            // icon-only mode; placement is driven by the position setting below.
            readonly property bool extrasAllowed:
                compactRepresentation.layoutForm !== CompactRepresentation.LayoutType.Tray
                && compactRepresentation.layoutForm !== CompactRepresentation.LayoutType.IconOnly
            readonly property bool showControls: extrasAllowed && plasmoid.configuration.compactShowControls === true
            readonly property bool showProgress: extrasAllowed && plasmoid.configuration.compactShowProgress === true && trackLength > 0
            readonly property bool extrasVisible: showControls || showProgress

            // Appearance / placement settings
            readonly property int controlsSize: plasmoid.configuration.compactControlsSize || Kirigami.Units.iconSizes.smallMedium
            readonly property int progressBarHeight: plasmoid.configuration.compactProgressHeight || 6
            readonly property color progressColor: plasmoid.configuration.compactProgressColor ? plasmoid.configuration.compactProgressColor : Kirigami.Theme.highlightColor
            readonly property bool controlsVertical: plasmoid.configuration.compactControlsOrientation === "vertical"
            readonly property bool progressFirst: plasmoid.configuration.compactProgressFirst !== false
            readonly property string extrasPosition: plasmoid.configuration.compactExtrasPosition || "auto"
            // "left"/"top" place the extras before the track, the rest after it
            readonly property bool extrasBeforeTrack: extrasVisible && (extrasPosition === "left" || extrasPosition === "top")
            readonly property bool extrasAfterTrack: extrasVisible && !extrasBeforeTrack

            // Read-only position for the progress bar. MPRIS doesn't push
            // Position updates, so seed from the player and tick locally,
            // resyncing every few seconds to correct any drift.
            readonly property double trackLength: mpris2Model.currentPlayer?.length ?? 0
            readonly property double modelPosition: mpris2Model.currentPlayer?.position ?? 0
            property double displayPosition: 0
            onModelPositionChanged: displayPosition = modelPosition
            onShowProgressChanged: if (showProgress) {
                mpris2Model.currentPlayer?.updatePosition();
            }

            Connections {
                target: root
                function onTrackChanged() {
                    grid.displayPosition = 0;
                    mpris2Model.currentPlayer?.updatePosition();
                }
            }

            Timer {
                interval: 1000
                repeat: true
                running: root.isPlaying && grid.showProgress
                property int ticks: 0
                onTriggered: {
                    if (++ticks >= 5) {
                        ticks = 0;
                        mpris2Model.currentPlayer?.updatePosition();
                    } else if (grid.displayPosition < grid.trackLength) {
                        grid.displayPosition += 1000000;
                    }
                }
            }

            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: rowSpacing
            flow: {
                // An explicit extras position overrides the orientation default:
                // left/right force a row, top/bottom force a column.
                if (grid.extrasVisible) {
                    if (grid.extrasPosition === "top" || grid.extrasPosition === "bottom")
                        return GridLayout.TopToBottom;
                    if (grid.extrasPosition === "left" || grid.extrasPosition === "right")
                        return GridLayout.LeftToRight;
                }
                switch (compactRepresentation.layoutForm) {
                case CompactRepresentation.LayoutType.VerticalPanel:
                case CompactRepresentation.LayoutType.VerticalDesktop:
                    return GridLayout.TopToBottom;
                default:
                    return GridLayout.LeftToRight;
                }
            }

            Item {
                id: spacerItem
                visible: compactRepresentation.layoutForm === CompactRepresentation.LayoutType.VerticalDesktop
                Layout.fillHeight: true
            }

            // Progress bar + playback controls, defined once and placed either
            // before or after the track depending on the position setting.
            Component {
                id: extrasComponent
                GridLayout {
                    columns: 1
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignCenter

                    // Custom-drawn progress bar (lets us control height and color)
                    Item {
                        Layout.row: grid.progressFirst ? 0 : 1
                        Layout.column: 0
                        Layout.fillWidth: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: grid.progressBarHeight
                        visible: grid.showProgress

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Kirigami.Theme.textColor
                            opacity: 0.25
                        }
                        Rectangle {
                            height: parent.height
                            width: parent.width * (grid.trackLength > 0 ? Math.max(0, Math.min(1, grid.displayPosition / grid.trackLength)) : 0)
                            radius: height / 2
                            color: grid.progressColor
                        }
                    }

                    // Buttons: a single row, or a vertical stack (columns: 1)
                    GridLayout {
                        Layout.row: grid.progressFirst ? 1 : 0
                        Layout.column: 0
                        Layout.alignment: Qt.AlignHCenter
                        visible: grid.showControls
                        columns: grid.controlsVertical ? 1 : 3
                        rowSpacing: Kirigami.Units.smallSpacing
                        columnSpacing: Kirigami.Units.smallSpacing

                        PC3.ToolButton {
                            visible: plasmoid.configuration.compactShowPrevious !== false
                            icon.name: LayoutMirroring.enabled ? "media-skip-forward" : "media-skip-backward"
                            icon.width: grid.controlsSize
                            icon.height: grid.controlsSize
                            display: PC3.AbstractButton.IconOnly
                            text: i18nc("Play previous track", "Previous Track")
                            enabled: root.canGoPrevious
                            onClicked: root.previous()
                            PC3.ToolTip { text: parent.text }
                        }
                        PC3.ToolButton {
                            visible: plasmoid.configuration.compactShowPlayPause !== false
                            icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
                            icon.width: grid.controlsSize
                            icon.height: grid.controlsSize
                            display: PC3.AbstractButton.IconOnly
                            text: root.isPlaying ? i18nc("Pause playback", "Pause") : i18nc("Start playback", "Play")
                            enabled: root.isPlaying ? root.canPause : root.canPlay
                            onClicked: root.togglePlaying()
                            PC3.ToolTip { text: parent.text }
                        }
                        PC3.ToolButton {
                            visible: plasmoid.configuration.compactShowNext !== false
                            icon.name: LayoutMirroring.enabled ? "media-skip-backward" : "media-skip-forward"
                            icon.width: grid.controlsSize
                            icon.height: grid.controlsSize
                            display: PC3.AbstractButton.IconOnly
                            text: i18nc("Play next track", "Next Track")
                            enabled: root.canGoNext
                            onClicked: root.next()
                            PC3.ToolTip { text: parent.text }
                        }
                    }
                }
            }

            // "Before track" slot (left / top)
            Loader {
                Layout.alignment: Qt.AlignCenter
                active: grid.extrasBeforeTrack
                visible: active
                sourceComponent: active ? extrasComponent : null
            }

            AlbumArtStackView {
                id: albumArt

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: compactRepresentation.Layout.fillWidth
                Layout.fillHeight: compactRepresentation.Layout.fillHeight
                Layout.preferredWidth: compactRepresentation.Layout.fillWidth ? -1 : compactRepresentation.height
                Layout.preferredHeight: compactRepresentation.Layout.fillHeight ? -1 : compactRepresentation.width

                inCompactRepresentation: true

                Connections {
                    target: root

                    function onAlbumArtChanged() {
                        albumArt.loadAlbumArt();
                    }
                }

                Component.onCompleted: albumArt.loadAlbumArt()
            }

            // Visualizer on left
            AudioVisualizer {
                id: leftVisualizer
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                visible: (plasmoid.configuration.enableVisualizer !== false) && (plasmoid.configuration.visualizerInCompact !== false) && (plasmoid.configuration.visualizerPositionCompact === "left")
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.maximumWidth: compactRepresentation.layoutForm === CompactRepresentation.LayoutType.HorizontalPanel ? Kirigami.Units.gridUnit * (plasmoid.configuration.compactMaxWidth || 15) : -1
                visible: compactRepresentation.layoutForm !== CompactRepresentation.LayoutType.VerticalPanel && compactRepresentation.layoutForm !== CompactRepresentation.LayoutType.IconOnly
                    || (compactRepresentation.layoutForm === CompactRepresentation.LayoutType.VerticalPanel && compactRepresentation.parent.width >= Kirigami.Units.gridUnit * 5)

                implicitHeight: textColumn.implicitHeight
                implicitWidth: textColumn.implicitWidth

                // Behind visualizer (rendered first, so it appears behind)
                AudioVisualizer {
                    id: behindVisualizer
                    anchors.fill: parent
                    visible: (plasmoid.configuration.enableVisualizer !== false) && (plasmoid.configuration.visualizerInCompact !== false) && plasmoid.configuration.visualizerPositionCompact === "behind"
                    opacity: plasmoid.configuration.visualizerBehindOpacity || 0.3
                }

                ColumnLayout {
                    id: textColumn
                    anchors.fill: parent
                    spacing: 0

                    // Song Title
                    ScrollingLabel {
                        id: songTitle

                        Layout.fillWidth: true

                        elide: Text.ElideRight
                        horizontalAlignment: grid.flow === GridLayout.TopToBottom ? Text.AlignHCenter : Text.AlignJustify
                        maximumLineCount: 1

                        labelOpacity: root.isPlaying ? 1 : 0.75
                        Behavior on labelOpacity {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }

                        text: root.track
                        textFormat: Text.PlainText
                        wrapMode: Text.NoWrap  // BUG 491946
                    }

                    // Song Artist
                    ScrollingLabel {
                        id: songArtist

                        Layout.fillWidth: true
                        visible: root.artist.length > 0 && compactRepresentation.height >= songTitle.implicitHeight + implicitHeight * 0.8 /* For CJK */ + (compactRepresentation.layoutForm === CompactRepresentation.LayoutType.VerticalDesktop ? albumArt.height + grid.rowSpacing : 0)

                        elide: Text.ElideRight
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        horizontalAlignment: songTitle.horizontalAlignment
                        maximumLineCount: 1
                        labelOpacity: 0.75
                        text: root.artist
                        textFormat: Text.PlainText
                        wrapMode: Text.NoWrap  // match title; a wrapping single-line label
                                               // under-reports implicitWidth so the column
                                               // squeezes it and it scrolls needlessly
                    }

                    // Audio Visualizer at bottom
                    AudioVisualizer {
                        id: bottomVisualizer
                        Layout.fillWidth: true
                        Layout.preferredHeight: (plasmoid.configuration.visualizerHeight || 30) / 2
                        visible: (plasmoid.configuration.enableVisualizer !== false) && (plasmoid.configuration.visualizerInCompact !== false) && plasmoid.configuration.visualizerPositionCompact === "bottom"
                    }
                }
            }

            // "After track" slot (right / bottom / automatic)
            Loader {
                Layout.alignment: Qt.AlignCenter
                active: grid.extrasAfterTrack
                visible: active
                sourceComponent: active ? extrasComponent : null
            }

            // Visualizer on right
            AudioVisualizer {
                id: rightVisualizer
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                visible: (plasmoid.configuration.enableVisualizer !== false) && (plasmoid.configuration.visualizerInCompact !== false) && (plasmoid.configuration.visualizerPositionCompact === "right")
            }

            Item {
                visible: spacerItem.visible
                Layout.fillHeight: true
            }
        }
    }
}
