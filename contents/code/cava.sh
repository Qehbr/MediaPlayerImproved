#!/bin/sh
# Runs cava and writes the latest frame of bar values to a temp file, one frame
# per write (semicolon-separated integers 0-100). The widget polls that file.
# cava captures the system audio output, so the bars react to what is playing.
#
# Usage: cava.sh <bars> <tag>
#   All temp files live at /tmp/mpi-cava-<tag>.{conf,fifo,dat}. The tag appears
#   in this process's and cava's command line, so the widget can reliably stop
#   everything with `pkill -f mpi-cava-<tag>` (the executable data engine does
#   not reliably kill child processes on its own).

BARS="${1:-20}"
TAG="$2"
[ -z "$TAG" ] && exit 1
command -v cava >/dev/null 2>&1 || exit 127

CFG="/tmp/mpi-cava-$TAG.conf"
FIFO="/tmp/mpi-cava-$TAG.fifo"
OUT="/tmp/mpi-cava-$TAG.dat"

cleanup() {
    [ -n "$CAVA_PID" ] && kill "$CAVA_PID" 2>/dev/null
    rm -f "$CFG" "$FIFO" "$OUT" "$OUT.tmp"
    exit 0
}
trap cleanup EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO" 2>/dev/null || exit 1

cat > "$CFG" <<EOF
[general]
bars = $BARS
framerate = 60
[output]
method = raw
raw_target = $FIFO
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
EOF

cava -p "$CFG" &
CAVA_PID=$!

while IFS= read -r line; do
    printf '%s' "$line" > "$OUT.tmp" && mv -f "$OUT.tmp" "$OUT"
done < "$FIFO"
