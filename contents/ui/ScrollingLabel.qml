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
    property alias elide: staticLabel.elide
    property alias horizontalAlignment: staticLabel.horizontalAlignment
    property alias verticalAlignment: staticLabel.verticalAlignment
    property alias textFormat: staticLabel.textFormat
    property alias wrapMode: staticLabel.wrapMode
    property alias maximumLineCount: staticLabel.maximumLineCount
    property real labelOpacity: 1.0

    property bool enableScrolling: plasmoid.configuration.enableScrollingText !== false
    property int scrollSpeed: plasmoid.configuration.scrollingTextSpeed || 50

    // Use implicitWidth for more reliable detection (QML best practice)
    readonly property bool needsScrolling: staticLabel.implicitWidth > width && width > 0

    implicitHeight: staticLabel.implicitHeight
    implicitWidth: staticLabel.implicitWidth

    clip: true

    // Debug output
    onNeedsScrollingChanged: {
        console.log("ScrollingLabel: needsScrolling =", needsScrolling, "implicitWidth =", staticLabel.implicitWidth, "width =", width, "text =", text)
    }

    PC3.Label {
        id: staticLabel
        anchors.fill: parent
        visible: !scrollingLabel.enableScrolling || !scrollingLabel.needsScrolling
        opacity: scrollingLabel.labelOpacity
        elide: Text.ElideRight  // Ensure text is elided when not scrolling
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
