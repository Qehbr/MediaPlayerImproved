# SPDX-License-Identifier: GPL-2.0-or-later
"""Locations shared by the optional resolver and its explicit installer."""
from dataclasses import dataclass
import os
from pathlib import Path

APP = "media-player-improved-mobile-icons"
STORE_THEME = "MediaPlayerImproved-MobileStores"
FDROID_THEME = "MediaPlayerImproved-FDroid"
THEMES = (STORE_THEME, FDROID_THEME)


def xdg_directory(env, name, default):
    value = env.get(name, "")
    return Path(value) if value and Path(value).is_absolute() else default


@dataclass(frozen=True)
class Paths:
    data: Path
    config: Path
    state: Path
    cache: Path
    config_home: Path
    data_dirs: tuple

    @classmethod
    def from_env(cls, env=None, home=None):
        env = os.environ if env is None else env
        home = Path.home() if home is None else Path(home)
        data = xdg_directory(env, "XDG_DATA_HOME", home / ".local/share")
        config = xdg_directory(env, "XDG_CONFIG_HOME", home / ".config")
        state = xdg_directory(env, "XDG_STATE_HOME", home / ".local/state")
        cache = xdg_directory(env, "XDG_CACHE_HOME", home / ".cache")
        dirs = tuple(Path(p) for p in env.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p and Path(p).is_absolute())
        return cls(data, config / APP / "config.json", state / APP,
                   cache / APP, config, dirs)

    @property
    def icons(self):
        return self.data / "icons"

    @property
    def code(self):
        return self.data / APP / "helper"

    @property
    def service(self):
        return self.config_home / "systemd/user" / (APP + ".service")

    @property
    def installation(self):
        return self.state / "installation.json"
