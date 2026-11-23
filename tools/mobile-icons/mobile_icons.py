#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Optional, explicitly enabled icon retrieval for KDE Connect media players."""
import argparse
import fcntl
import hashlib
import io
import json
import logging
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import tempfile
import threading
import time
import urllib.parse
import urllib.request

from PIL import Image
import providers
from paths import Paths, THEMES, STORE_THEME, FDROID_THEME

LOG = logging.getLogger("media-player-improved-mobile-icons")
DAY = 86400


def icon_name(name):
    """Mirror the widget's safe icon-name normalization; never accept paths."""
    slug = re.sub(r"\s+", "-", name.strip().lower())
    if not re.fullmatch(r"[a-z0-9_][a-z0-9_.+-]{0,119}", slug):
        raise ValueError("App name cannot be represented by a safe theme icon name")
    return "signal-desktop" if slug == "signal" else slug


def atomic_write(path, data):
    from install import safe_path
    safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix="." + path.name, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path, default):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def write_json(path, data):
    atomic_write(path, (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode())


def fetch(url, limit=2 * 1024 * 1024):
    """Fetch only validated public image URLs; reject cross-host redirects."""
    parsed = providers._https_url(url)
    if parsed is None:
        raise ValueError("Expected a public HTTPS image URL")
    request = urllib.request.Request(url, headers={"User-Agent": "MediaPlayerImprovedMobileIcons/1.0", "Accept-Encoding": "identity"})
    opener = urllib.request.build_opener(providers._SameHostRedirect(parsed.hostname.lower()))
    with opener.open(request, timeout=12) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Image exceeds size limit")
    return data


def fdroid(name, expected_package=None):
    data = json.loads(providers.read_url("https://search.f-droid.org/api/search_apps?" + urllib.parse.urlencode({"q": name})))
    matches = {}
    for app in data.get("apps", []):
        if providers.norm(app.get("name", "")) != providers.norm(name):
            continue
        page = providers._https_url(app.get("url"), hosts={"f-droid.org"})
        match = re.fullmatch(r"/(?:[a-zA-Z_-]+/)?packages/([A-Za-z0-9_.]+)/?", page.path) if page else None
        if not match:
            continue
        package = match.group(1)
        if expected_package and package != expected_package:
            continue
        icon = providers._https_url(app.get("icon"))
        # The catalog sometimes advertises a mirror. Use the same verified
        # repository-relative file on the canonical repository instead.
        prefix = "/fdroid/repo/" if icon and icon.path.startswith("/fdroid/repo/") else "/repo/"
        if not icon or not icon.path.startswith(prefix + package + "/"):
            continue
        relative = icon.path[len(prefix):]
        if any(part in (".", "..") for part in urllib.parse.unquote(relative).split("/")):
            continue
        matches[package] = {"provider": "fdroid", "package": package, "name": app["name"],
                            "icon": "https://f-droid.org/repo/" + relative, "page": app["url"]}
    if len(matches) > 1:
        raise providers.AmbiguousMatch("Multiple F-Droid packages have this exact app name")
    return next(iter(matches.values()), None)


def png_bytes(data):
    with Image.open(io.BytesIO(data)) as image:
        if image.format not in ("PNG", "JPEG", "WEBP") or not (16 <= image.width <= 2048 and 16 <= image.height <= 2048):
            raise ValueError("Unsupported icon format or dimensions")
        image.load()
        output = io.BytesIO()
        image.convert("RGBA").save(output, format="PNG")
        return output.getvalue()


class Resolver:
    def __init__(self, paths=None):
        self.paths = paths or Paths.from_env()
        from install import safe_path
        for path in (self.paths.state, self.paths.cache, self.paths.config, self.paths.icons):
            safe_path(path)
        self.paths.state.mkdir(parents=True, exist_ok=True)
        self.paths.cache.mkdir(parents=True, exist_ok=True)

    def configuration(self):
        config = read_json(self.paths.config, {})
        if not isinstance(config, dict) or not isinstance(config.get("applications", {}), dict):
            raise ValueError("Invalid mobile-icon configuration")
        return config

    def native_path(self, name):
        from install import refresh_index
        if refresh_index(self.paths):
            self.notify_icons()
        finder = shutil.which("kiconfinder6") or shutil.which("kiconfinder")
        if not finder:
            raise RuntimeError("KDE's kiconfinder6 is required; no online lookup was attempted")
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        candidates = ["signal", "signal-desktop"] if icon_name(name) == "signal-desktop" else [icon_name(name)]
        for slug in candidates:
            result = subprocess.run([finder, slug], env=env, capture_output=True, text=True, timeout=6)
            lines = result.stdout.strip().splitlines()
            if result.returncode == 0 and lines and Path(lines[0]).is_absolute():
                return Path(lines[0]).resolve()
        return None

    def managed(self, path):
        return bool(path and any((self.paths.icons / theme).resolve() in path.resolve().parents for theme in THEMES))

    def unchanged(self, record):
        path = Path(record.get("path", ""))
        from install import safe_path
        try:
            safe_path(path)
        except ValueError:
            return False
        return self.managed(path) and path.is_file() and digest(path.read_bytes()) == record.get("sha256")

    def remove_owned(self, record):
        if self.unchanged(record):
            Path(record["path"]).unlink()
            return True
        return False

    def resolve(self, name, force=False):
        slug, identity = icon_name(name), providers.norm(name)
        with (self.paths.state / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            return self._resolve(name, slug, identity, force)

    def _resolve(self, name, slug, identity, force):
        config = self.configuration()  # Reload on every lookup, including watcher jobs.
        pin = config.get("applications", {}).get(slug, {})
        if not isinstance(pin, dict):
            raise ValueError("Invalid application identity pin")
        pin_hash = digest(json.dumps(pin, sort_keys=True).encode())
        ledger_path = self.paths.state / "icons.json"
        ledger = read_json(ledger_path, {})
        previous = ledger.get(slug, {})
        native = self.native_path(name)
        if native and not self.managed(native):
            return {"name": name, "provider": "desktop", "path": str(native)}
        if previous and previous.get("identity") != identity:
            raise providers.AmbiguousMatch("This icon alias already belongs to a different app name")
        if native and (not previous.get("path") or not self.unchanged(previous)):
            # Do not claim or overwrite an image after ownership records were
            # manually deleted, or after the user edited the cached image.
            return {"name": name, "provider": "user-artwork", "path": str(native)}
        retry_path = self.paths.cache / "retries.json"
        retries = read_json(retry_path, {})
        if previous and previous.get("pin_hash") != pin_hash:
            self.remove_owned(previous)
            previous = {"identity": identity, "pin_hash": pin_hash}
            ledger[slug] = previous
            write_json(ledger_path, ledger)
            retries.pop(slug, None)
            self.notify_icons()
            native = self.native_path(name)
        if config.get("enabled") is not True:
            return dict(previous, name=name, provider="disabled")
        now = time.time()
        retry = retries.get(slug, {})
        if not force and retry.get("identity") == identity and retry.get("pin_hash") == pin_hash and now < retry.get("after", 0):
            if self.unchanged(previous) or (not previous.get("path") and retry.get("resolved") is False):
                return dict(previous, name=name, provider=previous.get("provider", "unresolved"), notes=retry.get("notes", []))
        ledger.setdefault(slug, {"identity": identity, "pin_hash": pin_hash})
        write_json(ledger_path, ledger)
        errors = []
        catalog = None
        package = (pin.get("android_package") or previous.get("android_package")
                   or (previous.get("package") if previous.get("provider") in ("google-play", "fdroid") else None))
        apple_bundle = pin.get("apple_bundle") or previous.get("bundleId")
        # An Apple-only identity cannot be established or contradicted by an
        # unrelated Android app with the same display name.
        if not (apple_bundle and not package):
            try:
                catalog = fdroid(name, package)
                if catalog and package and catalog.get("package") != package:
                    raise providers.AmbiguousMatch("F-Droid result conflicts with the known Android package")
            except providers.AmbiguousMatch as error:
                self._miss(name, slug, identity, pin_hash, previous, retries, [str(error)], now)
                raise
            except Exception as error:
                errors.append("fdroid: " + str(error))
                if not package and not apple_bundle:
                    return self._miss(name, slug, identity, pin_hash, previous, retries, errors, now)
        package = package or (catalog or {}).get("package")

        def apple_candidate():
            candidate = providers.apple(name, apple_bundle)
            if candidate and package and not apple_bundle:
                authors = {providers.norm(x) for x in pin.get("apple_authors", [])}
                if providers.norm(candidate.get("author")) not in authors:
                    return None
            return candidate

        lookups = [
            ("google-play", lambda: providers.google_play(name, package) if package or not apple_bundle else None),
            ("apple-app-store", apple_candidate),
            ("fdroid", lambda: catalog),
        ]
        for provider, lookup in lookups:
            try:
                candidate = lookup()
                if not candidate:
                    continue
                raw = fetch(candidate["icon"])
                encoded = png_bytes(raw)
                theme = FDROID_THEME if provider == "fdroid" else STORE_THEME
                dest = self.paths.icons / theme / "scalable/apps" / (slug + ".png")
                if dest.exists() and str(dest) != previous.get("path"):
                    raise RuntimeError("Destination contains artwork not owned by this resolver")
                if dest.exists() and previous.get("path") and not self.unchanged(previous):
                    raise RuntimeError("Cached artwork was changed by the user")
                atomic_write(dest, encoded)
                if previous.get("path") != str(dest):
                    self.remove_owned(previous)
                verified_package = candidate.get("package") if provider in ("google-play", "fdroid") else package
                record = dict(candidate, name=name, identity=identity, alias=slug,
                              path=str(dest), sha256=digest(encoded), source_sha256=digest(raw),
                              android_package=verified_package, pin_hash=pin_hash)
                ledger[slug] = record
                write_json(ledger_path, ledger)
                retries[slug] = {"identity": identity, "pin_hash": pin_hash, "resolved": True,
                                 "after": now + 7 * DAY, "notes": errors}
                write_json(retry_path, retries)
                self.notify_icons()
                LOG.info("Resolved %s through %s", name, provider)
                return record
            except providers.AmbiguousMatch as error:
                self._miss(name, slug, identity, pin_hash, previous, retries, [str(error)], now)
                raise
            except Exception as error:
                errors.append(provider + ": " + str(error))
        return self._miss(name, slug, identity, pin_hash, previous, retries, errors, now)

    def _miss(self, name, slug, identity, pin_hash, previous, retries, errors, now):
        retries[slug] = {"identity": identity, "pin_hash": pin_hash, "resolved": False,
                         "after": now + (3600 if errors else DAY), "notes": errors}
        write_json(self.paths.cache / "retries.json", retries)
        return dict(previous, name=name, provider=previous.get("provider", "unresolved"), notes=errors)

    @staticmethod
    def notify_icons():
        try:
            import dbus
            message = dbus.lowlevel.SignalMessage("/KIconLoader", "org.kde.KIconLoader", "iconChanged")
            message.append(dbus.Int32(0), signature="i")
            bus = dbus.SessionBus()
            bus.send_message(message)
            bus.flush()
        except Exception as error:
            LOG.debug("Icon refresh will occur on the next desktop refresh: %s", error)


def watch(resolver):
    import dbus
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
    DBusGMainLoop(set_as_default=True)
    bus, jobs, pending = dbus.SessionBus(), queue.Queue(), set()
    guard = threading.Lock()

    def worker():
        while True:
            name = jobs.get()
            try:
                resolver.resolve(name)
            except Exception as error:
                LOG.warning("Cannot resolve %s: %s", name, error)
            finally:
                with guard:
                    pending.discard(name)
                jobs.task_done()

    def scan():
        for service in bus.list_names():
            if not str(service).startswith("org.mpris.MediaPlayer2.kdeconnect."):
                continue
            try:
                props = dbus.Interface(bus.get_object(service, "/org/mpris/MediaPlayer2", introspect=False), "org.freedesktop.DBus.Properties")
                identity = str(props.Get("org.mpris.MediaPlayer2", "Identity", timeout=2))
                name = identity.split(" - ", 1)[0].strip()
                icon_name(name)
                with guard:
                    if name not in pending:
                        pending.add(name)
                        jobs.put(name)
            except Exception as error:
                LOG.debug("Skipping unavailable player: %s", error)
        return True

    def changed(name, old, new):
        if str(name).startswith("org.mpris.MediaPlayer2.kdeconnect.") and new:
            GLib.timeout_add(750, lambda: (scan(), False)[1])

    bus.add_signal_receiver(changed, signal_name="NameOwnerChanged", dbus_interface="org.freedesktop.DBus", path="/org/freedesktop/DBus")
    threading.Thread(target=worker, daemon=True).start()
    scan()
    GLib.timeout_add_seconds(60, scan)
    GLib.MainLoop().run()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    resolver = Resolver()
    for name in args.names:
        print(json.dumps(resolver.resolve(name, args.refresh), ensure_ascii=False))
    if args.watch:
        watch(resolver)
    elif not args.names:
        parser.error("Specify app names or --watch")


if __name__ == "__main__":
    main()
