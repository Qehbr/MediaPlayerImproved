/*
    SPDX-FileCopyrightText: 2025 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nc("@title", "General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Compact View")
        icon: "view-media-track"
        source: "configCompact.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Visualizer")
        icon: "view-media-visualization"
        source: "configVisualizer.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Colors")
        icon: "color-management"
        source: "configColors.qml"
    }
}
