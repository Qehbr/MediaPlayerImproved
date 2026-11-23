// SPDX-License-Identifier: LGPL-2.0-or-later
.pragma library

function isSafeIconName(name) {
    // A remote application label must never be interpreted as a URL or path.
    return typeof name === "string" && /^[a-zA-Z0-9_][a-zA-Z0-9_.+-]{0,119}$/.test(name);
}

function isRemotePlayer(desktopEntry, isMultiplexer) {
    return !isMultiplexer
        && /^(kdeconnect|org\.kde\.kdeconnect(?:\..*)?)$/i.test((desktopEntry || "").replace(/\.desktop$/i, ""));
}

function remoteAppName(identity) {
    // KDE Connect exposes "App - Device" without escaping either name. Prefer
    // the first segment; labels with this delimiter in the app name are ambiguous.
    const name = (identity || "").split(" - ")[0].trim().toLowerCase().replace(/\s+/g, "-");
    return isSafeIconName(name) ? name : "";
}

function iconCandidates(modelIconName, desktopEntry, identity, isMultiplexer) {
    if (isMultiplexer) {
        return [modelIconName];
    }
    if (isRemotePlayer(desktopEntry, false)) {
        const app = remoteAppName(identity);
        if (!app) {
            return ["kdeconnect"];
        }
        // Each candidate uses the desktop theme's complete inheritance chain.
        return app === "signal" ? ["signal", "signal-desktop"] : [app];
    }
    if (modelIconName && modelIconName !== "emblem-music-symbolic") {
        return [modelIconName];
    }
    const entry = (desktopEntry || "").replace(/\.desktop$/i, "");
    const freeTube = /^(freetube|io\.freetubeapp\.freetube)$/i.test(entry)
        || (identity || "").toLowerCase() === "freetube";
    const candidates = isSafeIconName(entry) ? [entry] : [];
    if (freeTube) {
        for (const alias of ["freetube", "io.freetubeapp.FreeTube"]) {
            if (!candidates.includes(alias)) {
                candidates.push(alias);
            }
        }
    }
    return candidates.length ? candidates : [modelIconName || "emblem-music-symbolic"];
}
