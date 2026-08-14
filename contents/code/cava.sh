#!/bin/sh
# Runs cava and writes the latest frame of bar values to a temp file, one frame
# per write (semicolon-separated integers 0-100). The widget polls that file.
# cava captures the system audio output, so the bars react to what is playing.
#
# Usage: cava.sh <bars> <tag> [source]
#   All temp files live at /tmp/mpi-cava-<tag>.{conf,fifo,dat}. The tag appears
#   in this process's and cava's command line, so the widget can reliably stop
#   everything with `pkill -f mpi-cava-<tag>` (the executable data engine does
#   not reliably kill child processes on its own).
#   [source] is an optional PulseAudio/PipeWire source name; empty means cava's
#   default (the system output monitor).

BARS="${1:-20}"
TAG="$2"
SOURCE="$3"
[ -z "$TAG" ] && exit 1
command -v cava >/dev/null 2>&1 || exit 127

# Re-exec once so this process's own command line carries the mpi-cava-<tag>
# marker. Without it the widget's `pkill -f mpi-cava-<tag>` matches only cava
# (via its config path) and leaves this wrapper running, which then keeps or
# restarts an untracked cava the widget has already forgotten about. Since the
# EXIT trap below kills our cava, making this process match the pattern is what
# actually makes a stop reliable.
if [ "$4" != "mpi-cava-$TAG" ]; then
    exec sh "$0" "$BARS" "$TAG" "$SOURCE" "mpi-cava-$TAG"
fi

# Drop temp files belonging to instances that are no longer running. This only
# ever removes files, never signals a process, so it cannot disturb a live
# instance: the panel and the popup each run their own visualizer, with their
# own tags, at the same time.
for _f in /tmp/mpi-cava-*; do
    [ -e "$_f" ] || continue
    _t=${_f#/tmp/mpi-cava-}
    _t=${_t%%.*}
    [ "$_t" = "$TAG" ] && continue
    pgrep -f "mpi-cava-$_t" >/dev/null 2>&1 || rm -f "$_f"
done

CFG="/tmp/mpi-cava-$TAG.conf"
FIFO="/tmp/mpi-cava-$TAG.fifo"
OUT="/tmp/mpi-cava-$TAG.dat"

cleanup() {
    [ -n "$WATCHDOG_PID" ] && kill "$WATCHDOG_PID" 2>/dev/null
    [ -n "$READER_PID" ] && kill "$READER_PID" 2>/dev/null
    [ -n "$CAVA_PID" ] && kill "$CAVA_PID" 2>/dev/null
    rm -f "$CFG" "$FIFO" "$OUT" "$OUT.tmp"
    exit 0
}
trap cleanup EXIT INT TERM

rm -f "$FIFO"
mkfifo "$FIFO" 2>/dev/null || exit 1

{
    echo "[general]"
    echo "bars = $BARS"
    echo "framerate = 60"
    if [ -n "$SOURCE" ]; then
        echo "[input]"
        echo "method = pulse"
        echo "source = $SOURCE"
    fi
    echo "[output]"
    echo "method = raw"
    echo "raw_target = $FIFO"
    echo "data_format = ascii"
    echo "ascii_max_range = 100"
    echo "bar_delimiter = 59"
    echo "frame_delimiter = 10"
} > "$CFG"

cava -p "$CFG" &
CAVA_PID=$!

# Pump frames in the background and wait on cava in the foreground, so this
# wrapper's lifetime tracks cava's exactly. Reading the fifo in the foreground
# instead would block forever whenever cava dies or never starts (no audio
# server, bad source name): nothing would ever open the write end, and the
# wrapper would linger with no cava behind it.
{
    while IFS= read -r line; do
        printf '%s' "$line" > "$OUT.tmp" && mv -f "$OUT.tmp" "$OUT"
    done < "$FIFO"
} &
READER_PID=$!

# If plasmashell goes away without stopping us (crash, SIGKILL, session teardown)
# nothing runs the stop pkill, and cava would keep capturing audio forever. An
# orphan gets reparented, so a change of parent is the signal to shut down. This
# watches only our own process, so unlike a scan-and-kill sweep it can never
# touch another instance, another user's processes, or an unrelated process that
# merely mentions the tag.
MAIN_PID=$$
ORIG_PPID=$(sed -n 's/^PPid:[[:space:]]*//p' "/proc/$MAIN_PID/status" 2>/dev/null)
if [ -n "$ORIG_PPID" ]; then
    {
        while :; do
            sleep 5
            _now=$(sed -n 's/^PPid:[[:space:]]*//p' "/proc/$MAIN_PID/status" 2>/dev/null)
            [ -z "$_now" ] && exit 0
            if [ "$_now" != "$ORIG_PPID" ]; then
                kill -TERM "$MAIN_PID" 2>/dev/null
                exit 0
            fi
        done
    } &
    WATCHDOG_PID=$!
fi

wait "$CAVA_PID"
