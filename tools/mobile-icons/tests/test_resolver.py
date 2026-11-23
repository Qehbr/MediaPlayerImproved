# SPDX-License-Identifier: GPL-2.0-or-later
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mobile_icons as m
from paths import Paths, THEMES
from PIL import Image


def png(color="red"):
    output = io.BytesIO()
    Image.new("RGBA", (32, 32), color).save(output, format="PNG")
    return output.getvalue()


def candidate(provider, package="org.example.player", name="Player"):
    result = {"provider": provider, "name": name, "author": "Example",
              "icon": "https://example.invalid/icon.png", "page": "https://example.invalid/app"}
    result["bundleId" if provider == "apple-app-store" else "package"] = package
    return result


class ResolverTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.paths = Paths.from_env({}, self.tmp.name)
        self.paths.config.parent.mkdir(parents=True)
        self.configure({})
        self.resolver = m.Resolver(self.paths)
        self.finder = patch.object(self.resolver, "native_path", side_effect=self.lookup).start()
        self.catalog = patch.object(m, "fdroid", return_value=None).start()
        self.google = patch.object(m.providers, "google_play", return_value=None).start()
        self.apple = patch.object(m.providers, "apple", return_value=None).start()
        self.fetch = patch.object(m, "fetch", return_value=png()).start()
        self.notify = patch.object(self.resolver, "notify_icons").start()
        self.addCleanup(patch.stopall)

    def configure(self, pins, enabled=True):
        self.paths.config.write_text(json.dumps({"enabled": enabled, "applications": pins}))

    def lookup(self, name):
        for theme in THEMES:
            path = self.paths.icons / theme / "scalable/apps" / (m.icon_name(name) + ".png")
            if path.exists():
                return path
        return None

    def test_native_short_circuits_network(self):
        self.finder.side_effect = None
        self.finder.return_value = Path("/usr/share/icons/hicolor/player.svg")
        self.assertEqual(self.resolver.resolve("Player")["provider"], "desktop")
        self.catalog.assert_not_called()
        self.google.assert_not_called()

    def test_online_is_explicit(self):
        self.configure({}, enabled=False)
        self.assertEqual(self.resolver.resolve("Player")["provider"], "disabled")
        self.catalog.assert_not_called()

    def test_google_first_for_artwork(self):
        self.catalog.return_value = candidate("fdroid")
        self.google.return_value = candidate("google-play")
        self.assertEqual(self.resolver.resolve("Player")["provider"], "google-play")
        self.google.assert_called_once_with("Player", "org.example.player")
        self.apple.assert_not_called()
        self.fetch.assert_called_once()

    def test_apple_second_when_no_catalog_identity(self):
        self.apple.return_value = candidate("apple-app-store")
        self.assertEqual(self.resolver.resolve("Player")["provider"], "apple-app-store")
        self.google.assert_called_once()
        self.apple.assert_called_once()

    def test_apple_only_pin_skips_unrelated_android_catalog(self):
        self.configure({"player": {"apple_bundle": "org.verified.player"}})
        self.catalog.side_effect = m.providers.AmbiguousMatch("Unrelated Android apps")
        self.apple.return_value = candidate("apple-app-store", "org.verified.player")
        result = self.resolver.resolve("Player")
        self.assertEqual(result["provider"], "apple-app-store")
        self.assertIsNone(result["android_package"])
        self.catalog.assert_not_called()
        self.google.assert_not_called()
        self.apple.assert_called_once_with("Player", "org.verified.player")

    def test_previous_apple_identity_cannot_gain_unrelated_android_package(self):
        self.apple.return_value = candidate("apple-app-store", "org.verified.player")
        self.resolver.resolve("Player")
        self.catalog.reset_mock()
        self.google.reset_mock()
        self.catalog.return_value = candidate("fdroid", "org.unrelated.player")
        result = self.resolver.resolve("Player", force=True)
        self.assertIsNone(result["android_package"])
        self.catalog.assert_not_called()
        self.google.assert_not_called()

    def test_fdroid_last_rejects_wrong_apple_author(self):
        self.catalog.return_value = candidate("fdroid")
        self.apple.return_value = candidate("apple-app-store", "unrelated.bundle")
        self.assertEqual(self.resolver.resolve("Player")["provider"], "fdroid")

    def test_first_catalog_outage_fails_closed(self):
        self.catalog.side_effect = TimeoutError("offline")
        self.google.return_value = candidate("google-play", "unrelated.bundle")
        self.assertEqual(self.resolver.resolve("Player")["provider"], "unresolved")
        self.google.assert_not_called()
        self.apple.assert_not_called()

    def test_known_identity_survives_outage(self):
        self.catalog.return_value = candidate("fdroid")
        self.resolver.resolve("Player")
        self.catalog.side_effect = TimeoutError("offline")
        self.google.reset_mock()
        result = self.resolver.resolve("Player", force=True)
        self.google.assert_called_once_with("Player", "org.example.player")
        self.assertEqual(result["provider"], "fdroid")

    def test_google_identity_persists_without_catalog(self):
        self.google.return_value = candidate("google-play", "org.original.player")
        first = self.resolver.resolve("Player")
        self.assertEqual(first["android_package"], "org.original.player")
        self.catalog.side_effect = TimeoutError("offline")
        self.google.reset_mock()
        self.resolver.resolve("Player", force=True)
        self.google.assert_called_once_with("Player", "org.original.player")

    def test_conflicting_later_catalog_cannot_change_identity(self):
        self.google.return_value = candidate("google-play", "org.original.player")
        first = self.resolver.resolve("Player")
        self.catalog.return_value = candidate("fdroid", "org.unrelated.player")
        self.google.reset_mock()
        with self.assertRaises(m.providers.AmbiguousMatch):
            self.resolver.resolve("Player", force=True)
        self.google.assert_not_called()
        ledger = json.loads((self.paths.state / "icons.json").read_text())
        self.assertEqual(ledger["player"]["android_package"], "org.original.player")
        self.assertTrue(Path(first["path"]).exists())

    def test_cache_deletion_does_not_lose_ownership(self):
        self.google.return_value = candidate("google-play")
        first = self.resolver.resolve("Player")
        (self.paths.cache / "retries.json").unlink()
        self.google.return_value = None
        self.catalog.return_value = candidate("fdroid")
        second = self.resolver.resolve("Player")
        self.assertEqual(second["provider"], "fdroid")
        self.assertFalse(Path(first["path"]).exists())
        self.assertTrue(Path(second["path"]).exists())

    def test_config_reload_invalidates_pin_and_retry(self):
        self.google.return_value = candidate("google-play")
        self.resolver.resolve("Player")
        self.configure({"player": {"android_package": "org.example.changed"}})
        self.google.reset_mock()
        self.google.return_value = candidate("google-play", "org.example.changed")
        second = self.resolver.resolve("Player")
        self.google.assert_called_once_with("Player", "org.example.changed")
        self.assertEqual(second["android_package"], "org.example.changed")

    def test_alias_collision_rejected(self):
        self.google.return_value = candidate("google-play")
        self.resolver.resolve("A B")
        self.google.reset_mock()
        with self.assertRaises(m.providers.AmbiguousMatch):
            self.resolver.resolve("A-B")
        self.google.assert_not_called()

    def test_modified_artwork_is_preserved(self):
        self.google.return_value = candidate("google-play")
        first = self.resolver.resolve("Player")
        Path(first["path"]).write_bytes(png("blue"))
        self.google.reset_mock()
        self.configure({"player": {"android_package": "org.example.changed"}})
        result = self.resolver.resolve("Player", force=True)
        self.assertEqual(result["provider"], "user-artwork")
        self.google.assert_not_called()
        self.assertEqual(Path(first["path"]).read_bytes(), png("blue"))

    def test_replaced_icon_directory_never_removes_external_artwork(self):
        self.google.return_value = candidate("google-play")
        first = self.resolver.resolve("Player")
        icon = Path(first["path"])
        theme = icon.parents[2]
        external = Path(self.tmp.name) / "external-icons"
        theme.rename(external)
        theme.symlink_to(external, target_is_directory=True)
        self.assertFalse(self.resolver.remove_owned(first))
        self.configure({"player": {"android_package": "org.example.changed"}})
        result = self.resolver.resolve("Player", force=True)
        self.assertEqual(result["provider"], "user-artwork")
        self.assertTrue((external / "scalable/apps" / icon.name).exists())

    def test_removed_ownership_record_does_not_claim_orphan(self):
        self.google.return_value = candidate("google-play")
        self.resolver.resolve("Player")
        (self.paths.state / "icons.json").unlink()
        self.google.reset_mock()
        self.assertEqual(self.resolver.resolve("Player", force=True)["provider"], "user-artwork")
        self.google.assert_not_called()

    def test_ambiguity_stops_chain_and_is_cached(self):
        self.google.side_effect = m.providers.AmbiguousMatch("two matches")
        with self.assertRaises(m.providers.AmbiguousMatch):
            self.resolver.resolve("Player")
        self.apple.assert_not_called()
        self.resolver.resolve("Player")
        self.google.assert_called_once()

    def test_missing_cached_file_is_downloaded_again(self):
        self.google.return_value = candidate("google-play")
        first = self.resolver.resolve("Player")
        Path(first["path"]).unlink()
        self.resolver.resolve("Player")
        self.assertEqual(self.fetch.call_count, 2)

    def test_success_retry_without_ledger_or_image_does_not_block_download(self):
        self.google.return_value = candidate("google-play")
        first = self.resolver.resolve("Player")
        Path(first["path"]).unlink()
        (self.paths.state / "icons.json").unlink()
        self.resolver.resolve("Player")
        self.assertEqual(self.fetch.call_count, 2)

    def test_invalid_image_tries_next_provider(self):
        self.google.return_value = candidate("google-play")
        self.apple.return_value = candidate("apple-app-store")
        self.fetch.side_effect = [b"invalid image", png()]
        self.assertEqual(self.resolver.resolve("Player")["provider"], "apple-app-store")

    def test_unsafe_names_rejected_before_network(self):
        for name in ("../bad", "https://example.invalid", "a/b", "éclair"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.resolver.resolve(name)
        self.catalog.assert_not_called()

    def test_symlink_state_is_rejected_without_writes(self):
        other = Path(self.tmp.name) / "external"
        other.mkdir()
        self.paths.state.rename(self.paths.state.with_name("old-state"))
        self.paths.state.symlink_to(other, target_is_directory=True)
        with self.assertRaises(ValueError):
            m.Resolver(self.paths)
        self.assertEqual(list(other.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
