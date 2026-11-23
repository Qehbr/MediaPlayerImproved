// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtTest
import MediaPlayerIconTestConfig 1.0
import org.kde.kirigami as Kirigami
import "../contents/ui" as Widget
import "../contents/code/playericons.js" as PlayerIcons

Item {
    id: scene
    width: 300
    height: 120

    Component {
        id: playerComponent
        Widget.PlayerIcon {
            width: 80
            height: 40
            refreshInterval: 30
        }
    }

    TestCase {
        id: tests
        name: "PlayerIcons"
        when: windowShown

        function test_candidates_data() {
            return [
                {tag: "automatic", model: "emblem-favorite", entry: "org.kde.kdeconnect.app", name: "Signal - Phone", automatic: true, expected: ["emblem-favorite"]},
                {tag: "valid-freetube-flatpak", model: "io.freetubeapp.FreeTube", entry: "io.freetubeapp.FreeTube", name: "FreeTube", automatic: false, expected: ["io.freetubeapp.FreeTube"]},
                {tag: "valid-freetube-custom", model: "mpi-custom", entry: "freetube", name: "FreeTube", automatic: false, expected: ["mpi-custom"]},
                {tag: "missing-freetube", model: "emblem-music-symbolic", entry: "", name: "FreeTube", automatic: false, expected: ["freetube", "io.freetubeapp.FreeTube"]},
                {tag: "flatpak-generic", model: "emblem-music-symbolic", entry: "io.freetubeapp.FreeTube.desktop", name: "FreeTube", automatic: false, expected: ["io.freetubeapp.FreeTube", "freetube"]},
                {tag: "signal-native-first", model: "kdeconnect", entry: "org.kde.kdeconnect.app", name: "Signal - Phone", automatic: false, expected: ["signal", "signal-desktop"]},
                {tag: "generic-phone-app", model: "kdeconnect", entry: "org.kde.kdeconnect.app.desktop", name: " YouTube  Music - Phone", automatic: false, expected: ["youtube-music"]},
                {tag: "device-delimiter", model: "kdeconnect", entry: "org.kde.kdeconnect.app", name: "Signal - My - Phone", automatic: false, expected: ["signal", "signal-desktop"]},
                {tag: "app-delimiter-heuristic", model: "kdeconnect", entry: "org.kde.kdeconnect.app", name: "Player - Pro - Phone", automatic: false, expected: ["player"]},
                {tag: "local-label-is-not-phone", model: "mpi-custom", entry: "other-app", name: "Signal - Phone", automatic: false, expected: ["mpi-custom"]},
            ];
        }

        function test_candidates(row) {
            compare(PlayerIcons.iconCandidates(row.model, row.entry, row.name, row.automatic), row.expected);
        }

        function test_remote_labels_cannot_load_paths_or_urls_data() {
            return ["file:///tmp/icon.svg", "/tmp/icon.svg", "../icon", "./icon", "https://example.org/icon.svg", "data:image/svg+xml,test", "", "..", "--option", "name?query", "name#fragment"]
                .map(label => ({tag: label || "empty", label: label}));
        }

        function test_remote_labels_cannot_load_paths_or_urls(row) {
            const identity = row.label + " - Phone";
            compare(PlayerIcons.remoteAppName(identity), "");
            compare(PlayerIcons.iconCandidates("kdeconnect", "org.kde.kdeconnect.app", identity, false), ["kdeconnect"]);
        }

        function player(properties) {
            const item = createTemporaryObject(playerComponent, scene, properties);
            verify(item !== null);
            return item;
        }

        function remote(name, properties = {}) {
            return player(Object.assign({desktopEntry: "org.kde.kdeconnect.app", identity: name + " - Phone"}, properties));
        }

        function retrySpy(item) {
            const spy = createTemporaryObject(retrySpyComponent, tests, {target: item});
            verify(spy.valid);
            return spy;
        }

        Component {
            id: retrySpyComponent
            SignalSpy { signalName: "lookupRetried" }
        }

        function test_supplied_freetube_icon_is_preserved() {
            const item = player({modelIconName: "io.freetubeapp.FreeTube", desktopEntry: "freetube", identity: "FreeTube"});
            tryCompare(item, "status", Kirigami.Icon.Ready);
            compare(item.resolvedIconName, "io.freetubeapp.FreeTube");
            verify(!item.badge.visible);
        }

        function test_missing_freetube_desktop_id_uses_native_alias() {
            const item = player({modelIconName: "emblem-music-symbolic", desktopEntry: "mpi-missing-freetube-id", identity: "FreeTube"});
            tryCompare(item, "status", Kirigami.Icon.Ready);
            compare(item.resolvedIconName, "freetube");
        }

        function test_signal_theme_name_precedes_alias() {
            const item = remote("Signal");
            tryCompare(item, "status", Kirigami.Icon.Ready);
            compare(item.resolvedIconName, IconTestConfig.signalAvailable ? "signal" : "signal-desktop");
        }

        function test_remote_uses_inherited_theme_icon() {
            const item = remote("Mpi Inherited");
            tryCompare(item, "status", Kirigami.Icon.Ready);
            compare(item.resolvedIconName, "mpi-inherited");
        }

        function test_badge_geometry_and_native_source() {
            const item = remote("NewPipe", {iconSize: 22});
            tryCompare(item, "status", Kirigami.Icon.Ready);
            verify(item.badge.visible);
            verify(item.badge instanceof Kirigami.Icon);
            compare(item.badge.source.toString(), "kdeconnect");
            compare(item.badge.parent, item.artwork);
            compare(item.badge.width, Math.round(22 * 0.65));
            compare(item.badge.height, item.badge.width);
            compare(item.badge.x + item.badge.width, item.artwork.width + 2);
            compare(item.badge.y + item.badge.height, item.artwork.height + 2);
        }

        function test_automatic_tab_has_no_device_badge_or_retry() {
            const item = remote("NewPipe", {isMultiplexer: true, modelIconName: "emblem-favorite", refreshEnabled: true});
            const spy = retrySpy(item);
            tryCompare(item, "status", Kirigami.Icon.Ready);
            compare(item.resolvedIconName, "emblem-favorite");
            verify(!item.badge.visible);
            wait(120);
            compare(spy.count, 0);
        }

        function test_retry_only_for_visible_expanded_missing_remote_icon() {
            const item = remote("Mpi Never Exists");
            const spy = retrySpy(item);
            tryCompare(item, "status", Kirigami.Icon.Error);
            wait(120);
            compare(spy.count, 0);
            item.refreshEnabled = true;
            tryVerify(() => spy.count > 0);
            item.refreshEnabled = false;
            const stopped = spy.count;
            wait(120);
            compare(spy.count, stopped);
            item.visible = false;
            item.refreshEnabled = true;
            wait(120);
            compare(spy.count, stopped);
        }

        function test_ready_remote_icon_stops_retry() {
            const item = remote("Mpi Never Exists", {refreshEnabled: true});
            const spy = retrySpy(item);
            tryVerify(() => spy.count > 0);
            item.identity = "NewPipe - Phone";
            tryCompare(item, "status", Kirigami.Icon.Ready);
            const stopped = spy.count;
            wait(120);
            compare(spy.count, stopped);
            compare(item.resolvedIconName, "newpipe");
        }

        function test_local_missing_icon_never_polls() {
            const item = player({modelIconName: "mpi-never-exists", refreshEnabled: true});
            const spy = retrySpy(item);
            tryCompare(item, "status", Kirigami.Icon.Error);
            wait(120);
            compare(spy.count, 0);
        }
    }
}
