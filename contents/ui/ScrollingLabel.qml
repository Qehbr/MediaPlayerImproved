/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: scrollingLabel

    property alias text: staticLabel.text
    property alias color: staticLabel.color
    property alias font: staticLabel.font
    // The requested elide mode, applied only when scrolling is disabled. While
    // scrolling is enabled the static label is shown solely in the "fits"
    // case, so it must never elide (a sub-pixel spillover would otherwise turn
    // into a full "…"); clip silently hides any residual fraction instead.
    property int elide: Text.ElideRight
    property alias horizontalAlignment: staticLabel.horizontalAlignment
    property alias verticalAlignment: staticLabel.verticalAlignment
    property alias textFormat: staticLabel.textFormat
    property alias wrapMode: staticLabel.wrapMode
    property alias maximumLineCount: staticLabel.maximumLineCount
    property real labelOpacity: 1.0

    property bool enableScrolling: plasmoid.configuration.enableScrollingText !== false
    property int scrollSpeed: plasmoid.configuration.scrollingTextSpeed || 50

    // Text reports a fractional natural width (e.g. 63.20) but the surrounding
    // panel layout rounds/quantises when distributing space, so the box ends up
    // ~2px narrower than the text and it spills over, scrolling (or eliding)
    // when it actually fits. Reserve a couple of extra whole pixels so the box
    // is never under-sized, and keep a 1px tolerance on the scroll check to
    // absorb any residual rounding.
    readonly property bool needsScrolling: width > 0 && staticLabel.implicitWidth - width > 1

    implicitHeight: staticLabel.implicitHeight
    implicitWidth: Math.ceil(staticLabel.implicitWidth) + 2

    clip: true

    PC3.Label {
        id: staticLabel
        anchors.fill: parent
        visible: !scrollingLabel.enableScrolling || !scrollingLabel.needsScrolling
        opacity: scrollingLabel.labelOpacity
        elide: scrollingLabel.enableScrolling ? Text.ElideNone : scrollingLabel.elide
    }

    Item {
        id: scrollingContainer
        anchors.fill: parent
        visible: scrollingLabel.enableScrolling && scrollingLabel.needsScrolling
        clip: true

        Row {
            id: scrollRow
            spacing: Kirigami.Units.gridUnit * 2
            height: parent.height

            PC3.Label {
                id: firstLabel
                text: scrollingLabel.text
                color: staticLabel.color
                font: staticLabel.font
                textFormat: staticLabel.textFormat
                opacity: scrollingLabel.labelOpacity
                verticalAlignment: staticLabel.verticalAlignment
            }

            PC3.Label {
                text: scrollingLabel.text
                color: staticLabel.color
                font: staticLabel.font
                textFormat: staticLabel.textFormat
                opacity: scrollingLabel.labelOpacity
                verticalAlignment: staticLabel.verticalAlignment
                visible: scrollAnimation.running
            }

            SequentialAnimation {
                id: scrollAnimation
                loops: Animation.Infinite
                running: scrollingContainer.visible && scrollingLabel.visible

                PropertyAnimation {
                    target: scrollRow
                    property: "x"
                    from: 0
                    to: -(firstLabel.implicitWidth + scrollRow.spacing)
                    duration: (firstLabel.implicitWidth + scrollRow.spacing) / scrollingLabel.scrollSpeed * 1000
                    easing.type: Easing.Linear
                }

                PauseAnimation {
                    duration: 2000
                }

                ScriptAction {
                    script: scrollRow.x = 0
                }
            }
        }
    }
}
