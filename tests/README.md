# Qt Quick regression tests

The tests load the production artwork and player-icon components. They require
Qt 6 Quick Test and the widget's normal Plasma and Kirigami QML dependencies;
no player or running Plasma shell is needed.

From the repository root:

```sh
tests/run-tests.sh
```

The runner creates an isolated temporary icon theme and runs the suite at both
1× and 2× device pixel ratios, with both an inherited Signal icon and an
alias-only theme. It does not modify the selected desktop theme.
Set `QMLTESTRUNNER` if the Qt 6 test runner has a different location.

Artwork tests cover initial loading while hidden, revealing a deferred image,
visible loading, hidden track changes, several pending changes, and clearing
artwork before revealing the panel. They check transparency and a 64 × 36
logical-pixel slot at both scales.

Player-icon tests cover preserving supplied FreeTube icons, correcting missing
FreeTube aliases, native Signal icon preference and alias resolution, inherited
theme artwork, KDE Connect name parsing,
rejecting URL/path-like remote names, automatic-tab behavior, badge geometry,
and retrying missing icons only while a remote tab is visible in an open popup.
They also verify that retries stop after artwork resolves.

KDE Connect joins the app and device names with an unescaped ` - ` delimiter.
The widget uses the first segment as the app name; names containing that
separator in the app label cannot be disambiguated from this MPRIS field alone.
