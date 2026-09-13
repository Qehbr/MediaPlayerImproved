/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: configGeneral

    property alias cfg_volumeStep: volumeStep.value
    property alias cfg_hideWhenIdle: hideWhenIdle.checked
    property alias cfg_noArtworkIcon: noArtworkIcon.text

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
