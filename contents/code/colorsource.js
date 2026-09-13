.pragma library

/*
    SPDX-FileCopyrightText: 2026 Yuriy Rusanov
    SPDX-License-Identifier: GPL-2.0-or-later

    Resolves "where should this colour come from" for the parts of the widget
    that can follow the theme, the album art, or a colour picked by hand.
*/

/**
 * source       one of "theme", "art", "custom", or empty for never chosen
 * customColor  the colour the user picked, empty when they never picked one
 * artColor     colour pulled from the artwork; already falls back to a theme
 *              colour when there is no artwork on screen to read
 * themeColor   what to use when following the theme
 */
function resolve(source, customColor, artColor, themeColor) {
    var effective = source;
    if (effective !== "theme" && effective !== "art" && effective !== "custom") {
        // Never chosen. Before this setting existed a colour being set was
        // itself the switch, so read it that way and leave the user's
        // appearance untouched across the upgrade.
        effective = customColor ? "custom" : "theme";
    }
    if (effective === "art") {
        return artColor;
    }
    if (effective === "custom" && customColor) {
        return customColor;
    }
    return themeColor;
}
