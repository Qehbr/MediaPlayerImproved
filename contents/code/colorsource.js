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

/**
 * Blends between two colours, 0 giving the first and 1 the second.
 *
 * Lets a colour taken from artwork be dialled back towards the theme's own
 * colour: full strength follows the cover exactly, lower settings mute it,
 * which reads more calmly at small text sizes.
 */
function mix(from, to, amount) {
    var t = Math.max(0, Math.min(1, amount));
    return Qt.rgba(from.r + (to.r - from.r) * t,
                   from.g + (to.g - from.g) * t,
                   from.b + (to.b - from.b) * t,
                   from.a + (to.a - from.a) * t);
}

function relativeLuminance(color) {
    function channel(value) {
        return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

function contrastRatio(a, b) {
    var la = relativeLuminance(a);
    var lb = relativeLuminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/**
 * Keeps a colour taken from artwork usable as text on a given background.
 *
 * Album art is under no obligation to contrast with the panel, and a dark
 * cover on a dark panel reads as nothing at all. Rather than refuse the
 * colour, which would leave the setting looking broken on half the covers,
 * walk its lightness away from the background until it is legible: the hue
 * carries over, which is the point of following the artwork, and the text
 * stays readable either way.
 */
function readableOn(color, background, minimumRatio) {
    var minimum = minimumRatio || 4.5;
    if (contrastRatio(color, background) >= minimum) {
        return color;
    }
    var lighten = relativeLuminance(background) < 0.5;
    var candidate = color;
    for (var step = 0; step < 12; ++step) {
        candidate = lighten ? Qt.lighter(candidate, 1.25) : Qt.darker(candidate, 1.25);
        if (contrastRatio(candidate, background) >= minimum) {
            return candidate;
        }
    }
    return lighten ? "#ffffff" : "#000000";
}
