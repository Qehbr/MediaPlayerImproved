#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Explicit per-user installation and conservative removal of the optional helper."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from paths import APP, Paths, THEMES

FILES = ("mobile_icons.py", "providers.py", "paths.py", "install.py", "README.md")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(path):
    """Refuse symlinked destinations instead of modifying their external targets."""
    if any(ord(c) < 32 for c in str(path)):
        raise ValueError("Control characters are not supported in installation paths")
    if not path.is_absolute():
        raise ValueError("Installation paths must be absolute")
    for part in reversed([path, *path.parents]):
        if part.is_symlink():
            raise ValueError("Refusing a symlinked installation path: " + str(part))


def write(path, data):
    safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            output.write(data)
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def with_mobile_fallbacks(text):
    lines = text.splitlines()
    start = lines.index("[Icon Theme]")
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
    indexes = [i for i in range(start + 1, end) if lines[i].startswith("Inherits=")]
    if len(indexes) > 1:
        raise ValueError("Ambiguous hicolor inheritance; no changes made")
    current = indexes[0] if indexes else None
    parents = lines[current].split("=", 1)[1].split(",") if current is not None else []
    parents = [x.strip() for x in parents if x.strip() and x.strip() not in THEMES]
    line = "Inherits=" + ",".join(parents + list(THEMES))
    if current is None:
        lines.insert(start + 1, line)
    else:
        lines[current] = line
    return "\n".join(lines) + "\n"


def system_index(paths):
    for directory in paths.data_dirs:
        candidate = directory / "icons/hicolor/index.theme"
        if candidate.is_file() and candidate.resolve() != (paths.icons / "hicolor/index.theme").resolve():
            return candidate
    raise RuntimeError("No system hicolor index was found in XDG_DATA_DIRS")


def theme_index(name):
    return (f"[Icon Theme]\nName={name}\nComment=Optional cached mobile app icons\nHidden=true\n"
            "Directories=scalable/apps\n\n[scalable/apps]\nSize=128\nMinSize=8\nMaxSize=2048\n"
            "Type=Scalable\nContext=Applications\n").encode()


def systemd_quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%') + '"'


def install(paths, source, *, enable_online=False, watcher=False, run=subprocess.run):
    if not enable_online:
        raise ValueError("Online lookup requires explicit --enable-online consent")
    for path in (paths.data, paths.config, paths.state, paths.cache, paths.service):
        safe_path(path)
    if paths.installation.exists() or paths.code.exists():
        raise FileExistsError("Existing installation found; uninstall it before installing an update")
    source = Path(source)
    index = paths.icons / "hicolor/index.theme"
    safe_path(index)
    origin = system_index(paths)
    original = index.read_bytes() if index.exists() else None
    base = original if original is not None else origin.read_bytes()
    output = {paths.code / name: (source / name).read_bytes() for name in FILES}
    for theme in THEMES:
        directory = paths.icons / theme
        safe_path(directory)
        if directory.exists():
            raise FileExistsError("Supplemental theme already exists: " + str(directory))
        output[directory / "index.theme"] = theme_index(theme)
    if paths.config.exists():
        raise FileExistsError("Existing configuration found; preserve it before installing")
    config = json.loads((source / "default-config.json").read_text())
    config["enabled"] = True
    output[paths.config] = (json.dumps(config, indent=2) + "\n").encode()
    if watcher:
        unit = ("[Unit]\nDescription=Optional Media Player Improved mobile icon lookup\n"
                "After=plasma-plasmashell.service\nPartOf=graphical-session.target\n\n"
                "[Service]\nType=simple\nExecStart=:" + systemd_quote(sys.executable) + " " +
                systemd_quote(paths.code / "mobile_icons.py") + " --watch\nRestart=on-failure\n"
                "RestartSec=30\nEnvironment=QT_QPA_PLATFORM=offscreen\n\n"
                "[Install]\nWantedBy=graphical-session.target\n")
        environments = {
            "XDG_DATA_HOME": paths.data, "XDG_CONFIG_HOME": paths.config_home,
            "XDG_STATE_HOME": paths.state.parent, "XDG_CACHE_HOME": paths.cache.parent,
            "XDG_DATA_DIRS": ":".join(map(str, paths.data_dirs)),
        }
        unit = unit.replace("[Install]", "".join("Environment=" + systemd_quote(key + "=" + str(value)) + "\n" for key, value in environments.items()) + "\n[Install]")
        output[paths.service] = unit.encode()
    for path in output:
        safe_path(path)
        if path.exists():
            raise FileExistsError("Refusing to replace existing file: " + str(path))
    updated = with_mobile_fallbacks(base.decode()).encode()
    manifest = {
        "version": 1, "watcher": watcher,
        "files": {str(path): digest(data) for path, data in output.items()},
        "hicolor": {"path": str(index), "before": base64.b64encode(original).decode() if original is not None else None,
                    "managed_sha256": digest(updated), "system_path": str(origin), "system_sha256": digest(origin.read_bytes())},
    }
    # Record intentions before writes so partial failures remain uninstallable.
    write(paths.installation, (json.dumps(manifest, indent=2) + "\n").encode())
    for path, data in output.items():
        write(path, data)
    write(index, updated)
    for theme in THEMES:
        (paths.icons / theme / "scalable/apps").mkdir(parents=True, exist_ok=True)
    if watcher:
        run(["systemctl", "--user", "daemon-reload"], check=True)
        run(["systemctl", "--user", "enable", "--now", paths.service.name], check=True)
    return manifest


def refresh_index(paths):
    """Follow system hicolor updates only while our originally absent copy is untouched."""
    if not paths.installation.exists():
        return False
    safe_path(paths.installation)
    manifest = json.loads(paths.installation.read_text())
    record = manifest["hicolor"]
    index = paths.icons / "hicolor/index.theme"
    safe_path(index)
    if record.get("before") is not None or not index.exists() or digest(index.read_bytes()) != record["managed_sha256"]:
        return False
    origin = system_index(paths)
    raw = origin.read_bytes()
    if digest(raw) == record["system_sha256"]:
        return False
    updated = with_mobile_fallbacks(raw.decode()).encode()
    write(index, updated)
    record.update(system_path=str(origin), system_sha256=digest(raw), managed_sha256=digest(updated))
    write(paths.installation, (json.dumps(manifest, indent=2) + "\n").encode())
    return True


def uninstall(paths, *, run=subprocess.run):
    safe_path(paths.installation)
    manifest = json.loads(paths.installation.read_text())
    preserved = []
    if manifest.get("watcher"):
        expected = manifest["files"].get(str(paths.service))
        safe_path(paths.service)
        if paths.service.exists() and digest(paths.service.read_bytes()) != expected:
            raise RuntimeError("Watcher unit was edited; stop it and restore/remove it before uninstalling")
        run(["systemctl", "--user", "disable", "--now", paths.service.name], check=True)
    index = paths.icons / "hicolor/index.theme"
    safe_path(index)
    record = manifest["hicolor"]
    if index.exists() and digest(index.read_bytes()) == record["managed_sha256"]:
        if record["before"] is None:
            index.unlink()
        else:
            write(index, base64.b64decode(record["before"]))
    elif index.exists():
        preserved.append(str(index))
    ledger = paths.state / "icons.json"
    safe_path(ledger)
    ownership = json.loads(ledger.read_text()) if ledger.exists() else {}
    for app in ownership.values():
        candidate = Path(app.get("path", ""))
        allowed = any(candidate.parent == paths.icons / theme / "scalable/apps" for theme in THEMES)
        if not allowed:
            continue
        safe_path(candidate)
        if candidate.exists() and digest(candidate.read_bytes()) == app.get("sha256"):
            candidate.unlink()
        elif candidate.exists():
            preserved.append(str(candidate))
    allowed_files = {paths.code / name for name in FILES} | {paths.config, paths.service}
    allowed_files |= {paths.icons / theme / "index.theme" for theme in THEMES}
    for filename, expected in manifest["files"].items():
        path = Path(filename)
        if path not in allowed_files:
            preserved.append(str(path))
            continue
        safe_path(path)
        if path.exists() and digest(path.read_bytes()) == expected:
            path.unlink()
        elif path.exists():
            preserved.append(str(path))
    for directory in [paths.code, *[paths.icons / name / "scalable/apps" for name in THEMES],
                      *[paths.icons / name / "scalable" for name in THEMES], *[paths.icons / name for name in THEMES]]:
        try:
            directory.rmdir()
        except OSError:
            pass
    if manifest.get("watcher"):
        run(["systemctl", "--user", "daemon-reload"], check=True)
    # Keep a report and ownership history when the user changed files, so no
    # modified data is silently claimed by a later installation.
    if preserved:
        write(paths.state / "uninstall-preserved.json", (json.dumps(preserved, indent=2) + "\n").encode())
    else:
        paths.installation.unlink()
        ledger.unlink(missing_ok=True)
    return preserved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "uninstall"))
    parser.add_argument("--enable-online", action="store_true", help="Allow missing app names to be sent to public catalogs")
    parser.add_argument("--watch", action="store_true", help="Also enable the optional systemd user watcher")
    args = parser.parse_args()
    paths = Paths.from_env()
    if args.action == "install":
        install(paths, Path(__file__).parent, enable_online=args.enable_online, watcher=args.watch)
        print("Installed optional icon sources. Helper:", paths.code / "mobile_icons.py")
    else:
        preserved = uninstall(paths)
        print("Uninstalled; preserved edited files:" if preserved else "Uninstalled", *preserved, sep="\n")


if __name__ == "__main__":
    main()
