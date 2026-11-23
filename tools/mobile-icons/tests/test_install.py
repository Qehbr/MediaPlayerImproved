# SPDX-License-Identifier: GPL-2.0-or-later
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import install as installer
from paths import APP, Paths, THEMES

SOURCE = Path(__file__).resolve().parents[1]
INDEX = b"[Icon Theme]\nName=Hicolor\nDirectories=32x32/apps\n\n[32x32/apps]\nSize=32\nType=Fixed\nContext=Applications\n"


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.system = root / "system/share/icons/hicolor/index.theme"
        self.system.parent.mkdir(parents=True)
        self.system.write_bytes(INDEX)
        self.env = {"XDG_DATA_HOME": str(root / "user data"), "XDG_CONFIG_HOME": str(root / "config"),
                    "XDG_STATE_HOME": str(root / "state"), "XDG_CACHE_HOME": str(root / "cache"),
                    "XDG_DATA_DIRS": str(root / "system/share")}
        self.paths = Paths.from_env(self.env, root / "home")
        self.run = Mock()

    def install(self, **kwargs):
        return installer.install(self.paths, SOURCE, enable_online=True, run=self.run, **kwargs)

    def test_explicit_consent_required(self):
        with self.assertRaises(ValueError):
            installer.install(self.paths, SOURCE)
        self.assertFalse(self.paths.data.exists())
        self.assertEqual(self.system.read_bytes(), INDEX)

    def test_install_and_uninstall_created_index(self):
        self.install()
        index = self.paths.icons / "hicolor/index.theme"
        self.assertIn(",".join(THEMES), index.read_text())
        self.assertEqual(self.system.read_bytes(), INDEX)
        self.assertEqual(installer.uninstall(self.paths, run=self.run), [])
        self.assertFalse(index.exists())
        self.assertFalse(self.paths.code.exists())
        self.run.assert_not_called()

    def test_reinstall_can_resolve_despite_prior_success_retry(self):
        import mobile_icons as resolver_module
        from test_resolver import candidate, png
        self.install()
        def resolve():
            resolver = resolver_module.Resolver(self.paths)
            with patch.object(resolver, "native_path", return_value=None), \
                 patch.object(resolver, "notify_icons"), \
                 patch.object(resolver_module, "fdroid", return_value=None), \
                 patch.object(resolver_module.providers, "google_play", return_value=candidate("google-play")), \
                 patch.object(resolver_module, "fetch", return_value=png()) as fetch:
                result = resolver.resolve("Player")
                self.assertEqual(result["provider"], "google-play")
                fetch.assert_called_once()
        resolve()
        installer.uninstall(self.paths, run=self.run)
        self.assertTrue((self.paths.cache / "retries.json").exists())
        self.install()
        resolve()

    def test_existing_user_index_restored_verbatim(self):
        index = self.paths.icons / "hicolor/index.theme"
        index.parent.mkdir(parents=True)
        original = INDEX.replace(b"Name=Hicolor", b"Name=Personal\nInherits=OtherTheme")
        index.write_bytes(original)
        self.install()
        self.assertIn("Inherits=OtherTheme,", index.read_text())
        installer.uninstall(self.paths, run=self.run)
        self.assertEqual(index.read_bytes(), original)

    def test_modified_shared_index_and_config_survive_uninstall(self):
        self.install()
        index = self.paths.icons / "hicolor/index.theme"
        index.write_text(index.read_text() + "# My edit\n")
        config = self.paths.config.read_text() + "\n"
        self.paths.config.write_text(config)
        preserved = installer.uninstall(self.paths, run=self.run)
        self.assertIn(str(index), preserved)
        self.assertIn(str(self.paths.config), preserved)
        self.assertTrue(index.read_text().endswith("# My edit\n"))
        self.assertEqual(self.paths.config.read_text(), config)

    def test_owned_artwork_removed_but_edited_artwork_preserved(self):
        self.install()
        a = self.paths.icons / THEMES[0] / "scalable/apps/a.png"
        b = self.paths.icons / THEMES[0] / "scalable/apps/b.png"
        a.write_bytes(b"owned-a")
        b.write_bytes(b"user-edited")
        (self.paths.state / "icons.json").write_text(json.dumps({
            "a": {"path": str(a), "sha256": installer.digest(b"owned-a")},
            "b": {"path": str(b), "sha256": installer.digest(b"original-b")},
        }))
        preserved = installer.uninstall(self.paths, run=self.run)
        self.assertFalse(a.exists())
        self.assertEqual(b.read_bytes(), b"user-edited")
        self.assertIn(str(b), preserved)

    def test_edited_code_is_preserved(self):
        self.install()
        code = self.paths.code / "mobile_icons.py"
        code.write_text("# User replacement\n")
        self.assertIn(str(code), installer.uninstall(self.paths, run=self.run))
        self.assertEqual(code.read_text(), "# User replacement\n")

    def test_system_index_refresh_only_if_untouched(self):
        self.install()
        self.system.write_bytes(INDEX + b"# system update\n")
        self.assertTrue(installer.refresh_index(self.paths))
        index = self.paths.icons / "hicolor/index.theme"
        self.assertIn("# system update", index.read_text())
        index.write_text(index.read_text() + "# user edit\n")
        self.system.write_bytes(INDEX + b"# next system update\n")
        self.assertFalse(installer.refresh_index(self.paths))
        self.assertNotIn("# next system update", index.read_text())

    def test_preexisting_index_never_refreshed_from_system(self):
        index = self.paths.icons / "hicolor/index.theme"
        index.parent.mkdir(parents=True)
        index.write_bytes(INDEX)
        self.install()
        self.system.write_bytes(INDEX + b"# new system entry\n")
        self.assertFalse(installer.refresh_index(self.paths))

    def test_symlink_icon_base_refused_without_external_writes(self):
        external = Path(self.tmp.name) / "external"
        external.mkdir()
        self.paths.data.mkdir(parents=True)
        self.paths.icons.symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(list(external.iterdir()), [])
        self.assertFalse(self.paths.installation.exists())

    def test_symlink_hicolor_index_refused(self):
        index = self.paths.icons / "hicolor/index.theme"
        index.parent.mkdir(parents=True)
        index.symlink_to(self.system)
        with self.assertRaises(ValueError):
            self.install()
        self.assertEqual(self.system.read_bytes(), INDEX)

    def test_uninstall_refuses_replaced_symlink(self):
        self.install()
        index = self.paths.icons / "hicolor/index.theme"
        index.unlink()
        index.symlink_to(self.system)
        with self.assertRaises(ValueError):
            installer.uninstall(self.paths, run=self.run)
        self.assertEqual(self.system.read_bytes(), INDEX)

    def test_existing_theme_not_overwritten(self):
        directory = self.paths.icons / THEMES[0]
        directory.mkdir(parents=True)
        (directory / "mine.txt").write_text("mine")
        with self.assertRaises(FileExistsError):
            self.install()
        self.assertEqual((directory / "mine.txt").read_text(), "mine")
        self.assertFalse(self.paths.installation.exists())

    def test_optional_watcher_keeps_xdg_environment(self):
        self.install(watcher=True)
        unit = self.paths.service.read_text()
        for key, value in self.env.items():
            self.assertIn(key + "=" + value, unit)
        self.assertIn('ExecStart=:', unit)
        self.run.assert_any_call(["systemctl", "--user", "enable", "--now", self.paths.service.name], check=True)
        installer.uninstall(self.paths, run=self.run)
        self.run.assert_any_call(["systemctl", "--user", "disable", "--now", self.paths.service.name], check=True)

    def test_modified_watcher_refuses_uninstall(self):
        self.install(watcher=True)
        self.paths.service.write_text(self.paths.service.read_text() + "# custom\n")
        with self.assertRaises(RuntimeError):
            installer.uninstall(self.paths, run=self.run)
        self.assertTrue(self.paths.code.exists())

    def test_relative_xdg_values_use_defaults(self):
        paths = Paths.from_env({"XDG_DATA_HOME": "relative"}, Path(self.tmp.name))
        self.assertEqual(paths.data, Path(self.tmp.name) / ".local/share")


if __name__ == "__main__":
    unittest.main()
