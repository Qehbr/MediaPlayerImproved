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

    sourceComponent: inTray || root.track.length === 0 ? icon : playerRow

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

            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: rowSpacing
            flow: {
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
                        wrapMode: Text.Wrap
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
