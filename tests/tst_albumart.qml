// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../contents/ui" as Widget

Item {
    id: root
    width: 260
    height: 100

    // Context normally supplied by the plasmoid's main.qml.
    property string albumArt: ""
    property bool expanded: false
    property string iconName: "applications-multimedia"
    property string track: "test track"
    property int playbackStatus: 1

    Component {
        id: artworkComponent
        Widget.AlbumArtStackView {
            width: 64
            height: 36
            inCompactRepresentation: true
        }
    }

    TestCase {
        id: tests
        name: "DeferredAlbumArt"
        when: windowShown

        readonly property string wideArt: Qt.resolvedUrl("fixtures/wide.svg").toString()
        readonly property string squareArt: Qt.resolvedUrl("fixtures/square.svg").toString()

        function init() {
            root.albumArt = wideArt;
        }

        function artwork(visible) {
            const art = createTemporaryObject(artworkComponent, root, {visible: visible});
            verify(art !== null);
            art.loadAlbumArt();
            return art;
        }

        function pendingReady(art) {
            tryVerify(() => art.pendingImage !== null && art.pendingImage.status === Image.Ready);
            // Let the opacity workaround run while the image is still pending.
            wait(Kirigami.Units.longDuration + 100);
            compare(art.pendingImage.opacity, 0, "Pending images must stay invisible until sized by StackView");
        }

        function currentReady(art, source) {
            tryVerify(() => art.albumArt.currentItem !== null && art.pendingImage === null);
            const current = art.albumArt.currentItem;
            compare(current.source.toString(), source);
            compare(current.width, 64);
            compare(current.height, 36);
            tryCompare(current, "opacity", 1);
        }

        function test_first_image_loaded_while_hidden() {
            const art = artwork(false);
            pendingReady(art);
            compare(art.albumArt.currentItem, null);
            art.visible = true;
            currentReady(art, wideArt);
        }

        function test_reveal_retries_deferred_image() {
            const art = artwork(false);
            tryVerify(() => art.pendingImage !== null && art.pendingImage.status === Image.Ready);
            art.visible = true;
            currentReady(art, wideArt);
        }

        function test_visible_image_still_loads() {
            const art = artwork(true);
            currentReady(art, wideArt);
        }

        function test_hidden_track_change_replaces_old_image() {
            const art = artwork(true);
            currentReady(art, wideArt);
            art.visible = false;
            root.albumArt = squareArt;
            art.loadAlbumArt();
            pendingReady(art);
            art.visible = true;
            currentReady(art, squareArt);
        }

        function test_multiple_hidden_changes_use_latest_image() {
            const art = artwork(false);
            root.albumArt = squareArt;
            art.loadAlbumArt();
            root.albumArt = wideArt;
            art.loadAlbumArt();
            pendingReady(art);
            art.visible = true;
            currentReady(art, wideArt);
        }

        function test_cleared_art_is_not_restored_on_reveal() {
            const art = artwork(false);
            pendingReady(art);
            root.albumArt = "";
            art.loadAlbumArt();
            compare(art.pendingImage, null);
            art.visible = true;
            wait(Kirigami.Units.longDuration + 100);
            compare(art.pendingImage, null);
            compare(art.albumArt.currentItem, null);
        }
    }
}
