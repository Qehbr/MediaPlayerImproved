# Optional mobile app icon sources

This **separate, opt-in Linux/KDE helper** fills missing application icons for
KDE Connect media players. Installing or upgrading the plasmoid does not install
this helper, change icon themes, start a service, or contact an app catalog.
It is useful with the widget's remote application icon lookup.

Normal KDE lookup remains first: the selected icon theme, its inherited themes,
and installed `hicolor` application icons. Two hidden supplemental themes then
provide cached artwork from Google Play / Apple App Store, followed by F-Droid.
No application artwork is bundled with the widget or this helper.

The installer explicitly adds the supplemental themes to a **user-level copy of
hicolor's index**. This KDE inheritance behavior was tested with KF6; it is not a
cross-desktop icon resolver. Theme changes still take precedence. System hicolor
index updates are copied only if the installer originally created the user copy
and that copy remains unedited. Existing user customization is preserved.

## Requirements

- Linux with KDE Frameworks 6 and `kiconfinder6` (or the distribution's unversioned
  `kiconfinder` command for KF6).
- Python 3.10 or newer, Beautiful Soup 4, and Pillow.
- For desktop refresh notifications and the optional watcher: `dbus-python`.
- For the watcher: PyGObject with GLib; systemd is needed only for `--watch` installation.

Install these dependencies with your distribution's package manager. For
example, Fedora packages include `python3-beautifulsoup4`, `python3-pillow`,
`python3-dbus`, and `python3-gobject`; command/package names differ elsewhere.
The helper does not install dependencies itself. It refuses online lookup if the
native KDE icon finder is unavailable.

## Explicit installation

Run from this directory, as your desktop user:

```sh
python3 install.py install --enable-online
```

This enables manual lookups. To also run a user service which watches connected
phone media players, add `--watch`:

```sh
python3 install.py install --enable-online --watch
```

Choose one command. A second installation refuses to overwrite existing files;
uninstall before upgrading and retain any customized configuration separately.
The installer uses `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and
`XDG_CACHE_HOME`, with their standard home-directory defaults. It requires real,
non-symlinked destination directories. The optional service retains these XDG
settings even when installed outside their defaults.

With the default XDG locations:

```sh
python3 ~/.local/share/media-player-improved-mobile-icons/helper/mobile_icons.py NewPipe Auxio
python3 ~/.local/share/media-player-improved-mobile-icons/helper/mobile_icons.py --refresh Auxio
```

The printed JSON records the chosen source and installed image. Successful
lookups retry after seven days, missing results after a day, and request failures
after an hour. Existing images remain usable offline. Clearing the disposable
retry cache does not remove image identity and ownership records.

## Identity and privacy

Online lookup is disabled unless configuration contains `"enabled": true`.
Set it to `false` to stop future requests while preserving cached icons. The
watcher reloads configuration on each lookup; restarting it is not required.

Only missing application labels are submitted to public catalog searches.
The watcher reads KDE Connect's MPRIS `Identity`, not track titles, artists,
messages, or audio. F-Droid is consulted first for identity metadata; **artwork**
priority is Google Play, Apple App Store, then F-Droid. An initial catalog failure
without a known package/bundle stops lookup instead of weakening identity checks.

Names are matched exactly after case/whitespace normalization. Multiple matches
stop the chain. A unique name still cannot prove that two independently published
apps are the same. Pin known identities in
`$XDG_CONFIG_HOME/media-player-improved-mobile-icons/config.json`, for example:

```json
{
  "enabled": true,
  "applications": {
    "auxio": {"android_package": "org.oxycblt.auxio"},
    "a-known-cross-platform-app": {
      "android_package": "org.example.android",
      "apple_bundle": "org.example.ios"
    }
  }
}
```

NewPipe and Auxio package pins are included as metadata; this avoids unrelated
same-name store applications. An Apple homonym of a known Android app requires
an explicit bundle pin or an `apple_authors` allowlist. Changing a pin invalidates
its retry decision and removes only an unchanged helper-owned old icon. User
edits are preserved. Known identity survives catalog outages.
An Apple-only bundle pin (or previously resolved Apple-only identity) skips
Android catalogs; a same-name Android app cannot replace that known identity.

The widget and watcher currently derive the app name from the first segment of
KDE Connect's `App - Device` identity. Names containing that separator are
ambiguous. Supported icon aliases use ASCII letters, digits, `_`, `.`, `+`, and
`-`, with whitespace changed to `-`; other names are skipped. Full normalized
labels remain separate ownership keys, so `A B` cannot silently reuse `A-B`'s
cached icon. An unresolved app remains unresolved; no unrelated generic artwork
is downloaded.

Google Play supplies public HTML rather than a stable general catalog API, so
markup changes can make a lookup fail. Apple and F-Droid supply public JSON APIs.
Requests have timeouts and size limits. Icons are validated and re-encoded as PNG.
Downloaded artwork remains subject to its original publisher's terms and rights.

## State and removal

- Configuration: `$XDG_CONFIG_HOME/media-player-improved-mobile-icons/config.json`
- Code: `$XDG_DATA_HOME/media-player-improved-mobile-icons/helper/`
- Artwork: `$XDG_DATA_HOME/icons/MediaPlayerImproved-{MobileStores,FDroid}/`
- Persistent ownership/installation records: `$XDG_STATE_HOME/media-player-improved-mobile-icons/`
- Disposable retry cache: `$XDG_CACHE_HOME/media-player-improved-mobile-icons/`

Uninstall with the source checkout, or the installed installer:

```sh
python3 install.py uninstall
```

This stops a managed watcher if present, restores the original user hicolor index
(or removes the untouched copy it created), and removes only unchanged managed
files and images. Modified files are preserved and listed. If the watcher unit
was edited, uninstall stops and asks you to resolve that unit first. The installer
never recursively removes arbitrary icon directories. Keep the persistent
ownership records until uninstallation finishes; they distinguish downloaded
artwork from later user changes. Retry-cache files may be removed at any time.

The service is separate from the plasmoid and is not removed by `kpackagetool`.

## Verification

Offline tests use temporary XDG roots and mocked providers; they do not contact
catalogs or alter the current desktop:

```sh
python3 -m unittest discover -s tests -v
```

The tests cover native precedence, provider order, catalog failures, identity
pins, alias collisions, cache deletion, user edits, XDG paths, and installer /
uninstaller safety. Live provider HTML remains an external compatibility risk.
