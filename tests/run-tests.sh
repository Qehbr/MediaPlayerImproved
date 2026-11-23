#!/bin/sh
# Use an isolated native icon theme; never depend on or modify the user's icons.
set -eu
cd "$(dirname "$0")/.."
runner=${QMLTESTRUNNER:-}
if [ -z "$runner" ]; then
    for candidate in qmltestrunner qmltestrunner6 qmltestrunner-qt6 /usr/lib64/qt6/bin/qmltestrunner; do
        if command -v "$candidate" >/dev/null 2>&1; then
            runner=$candidate
            break
        fi
    done
fi
if [ -z "$runner" ]; then
    echo 'Qt 6 qmltestrunner is required.' >&2
    exit 1
fi
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
icon_dir="$test_dir/data/icons/MediaPlayerImprovedTests/scalable/apps"
mkdir -p "$icon_dir" "$test_dir/config"
cat > "$test_dir/config/kdeglobals" <<'CONFIG'
[Icons]
Theme=MediaPlayerImprovedTests
CONFIG
cat > "$test_dir/data/icons/MediaPlayerImprovedTests/index.theme" <<'THEME'
[Icon Theme]
Name=Media Player Improved Tests
Inherits=MediaPlayerImprovedInherited,hicolor
Directories=scalable/apps

[scalable/apps]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications
THEME
for icon in mpi-custom freetube io.freetubeapp.FreeTube kdeconnect emblem-favorite unknown signal-desktop newpipe spotify emblem-music-symbolic; do
    cp tests/fixtures/square.svg "$icon_dir/$icon.svg"
done
inherited_dir="$test_dir/data/icons/MediaPlayerImprovedInherited/scalable/apps"
config_dir="$test_dir/qml/MediaPlayerIconTestConfig"
mkdir -p "$inherited_dir" "$config_dir"
cat > "$test_dir/data/icons/MediaPlayerImprovedInherited/index.theme" <<'THEME'
[Icon Theme]
Name=Media Player Improved Inherited Tests
Inherits=hicolor
Directories=scalable/apps

[scalable/apps]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications
THEME
cp tests/fixtures/square.svg "$inherited_dir/mpi-inherited.svg"
cat > "$config_dir/qmldir" <<'MODULE'
module MediaPlayerIconTestConfig
singleton IconTestConfig 1.0 IconTestConfig.qml
MODULE
for signal_available in true false; do
    if [ "$signal_available" = true ]; then
        cp tests/fixtures/square.svg "$inherited_dir/signal.svg"
    else
        rm -f "$inherited_dir/signal.svg"
    fi
    cat > "$config_dir/IconTestConfig.qml" <<CONFIG
pragma Singleton
import QtQml
QtObject { readonly property bool signalAvailable: $signal_available }
CONFIG
    for scale in 1 2; do
        echo "Running Qt Quick tests at scale $scale; native Signal available: $signal_available"
        XDG_DATA_HOME="$test_dir/data" XDG_DATA_DIRS="$test_dir/data" \
            XDG_CONFIG_HOME="$test_dir/config" \
            QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde \
            QT_QUICK_BACKEND=software QT_SCALE_FACTOR="$scale" \
            "$runner" -import "$test_dir/qml" -input tests "$@"
    done
done
