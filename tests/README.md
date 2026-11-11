# Album artwork regression tests

These Qt Quick Tests load the production `AlbumArtStackView.qml` with a small
replacement for its plasmoid context. They require Qt 6 Quick Test and the
widget's normal Plasma and Kirigami QML dependencies; no player or running
Plasma shell is needed.

From the repository root, run both device pixel ratios:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=1 qmltestrunner -input tests
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=2 qmltestrunner -input tests
```

Some distributions install the runner as `qmltestrunner6` or at
`/usr/lib64/qt6/bin/qmltestrunner`.

The tests cover initial loading while hidden, revealing a deferred image,
normal visible loading, changing tracks while hidden, several pending track
changes and clearing artwork before revealing the panel. They check that
pending images remain transparent and displayed images fit a 64 × 36 logical
pixel slot at both scales.
