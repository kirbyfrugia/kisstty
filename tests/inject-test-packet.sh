#!/usr/bin/env bash
# inject-test-packet.sh - Simulate an APRS packet arriving at kisstty: generate the
# packet's audio and feed it through a temporary Direwolf, which decodes it to KISS.
#
# Usage:
#   inject-test-packet.sh [options] <packet-file>
#   inject-test-packet.sh [options] -R
#
# Options:
#   -c <conf>      Path to direwolf.conf template (default: direwolf.conf.template
#                  in the same dir as this script)
#   -s <device>    Serial device for KISS (default: /tmp/altirra-tty, the socat
#                  PTY for the Altirra bridge). Pass -s '' for TCP KISS only
#                  (port 8001, no SERIALKISS line).
#   -r <seconds>   Repeat every N seconds (indefinitely, Ctrl-C to stop)
#   -n <count>     Repeat N times (default: 1)
#   -R             Generate a random APRS message (text 0-67 bytes) instead of
#                  reading a packet file. A fresh message is generated for each
#                  repetition (see -r/-n).
#   -h             Show this help
#
# Examples:
#   inject-test-packet.sh tests/aprs/position.txt
#   inject-test-packet.sh -s /dev/ttyUSB0 tests/aprs/position.txt
#   inject-test-packet.sh -r 30 tests/aprs/position.txt
#   inject-test-packet.sh -n 5 tests/aprs/position.txt
#   inject-test-packet.sh -n 10 -R
#   inject-test-packet.sh -c ~/.config/direwolf/direwolf.conf.template tests/aprs/position.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/direwolf.conf.template"
# Default to the socat PTY for the Altirra bridge (the primary use case).
# Override with -s <device>, or -s '' for TCP KISS only.
SERIAL_DEVICE="/tmp/altirra-tty"
REPEAT_INTERVAL=""
REPEAT_COUNT=1
RANDOM_MODE=false
DW_PID=""
WAV_FILE=""
GEN_CONF=""
FIFO=""
RANDOM_FILE=""
LOG="/tmp/direwolf-test.log"

usage() {
    sed -n '3,28p' "$0" | sed 's/^# \?//'
    exit 1
}

# Natural-language messages for -R, varied in length (a few chars up to the
# 67-byte APRS message-text max) so the scrolling output looks organic for
# terminal-refresh testing.
LOREM=(
    "OK"
    "Roger that."
    "Back in 5."
    "QSL, 73 and good DX."
    "Heading home now, traffic is light."
    "The quick brown fox jumps over the lazy dog."
    "She sells seashells by the seashore at dawn."
    "All work and no play makes Jack a dull boy today."
    "Pack my box with five dozen liquor jugs before noon."
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    "The morning sun rises slowly above the quiet green hills."
    "How vexingly quick daft zebras jump under the pale moonlight."
    "Sphinx of black quartz, judge my vow on this calm clear night."
    "The river winds gently through the valley toward the harbor light."
    "A gentle breeze drifts across the wide open meadow on a summer day."
)

# Generate one random APRS message packet (addressed to NOCALL) by picking a
# message from LOREM at random.
gen_random_packet() {
    local src="${LOREM[$((RANDOM % ${#LOREM[@]}))]}"
    printf 'NOCALL>APZ001,WIDE1-1,WIDE2-1::NOCALL   :%s\n' "$src"
}

# Generate the WAV for the current PACKET_FILE. Strip comment/blank lines, and
# feed the packet with no trailing newline -- gen_packets would otherwise keep
# it as a stray <0x0a> in the info field (which an APRS message's {seq number
# runs into, for example).
make_wav() {
    printf '%s' "$(grep -v '^\s*#' "$PACKET_FILE" | grep -v '^\s*$')" | gen_packets -o "$WAV_FILE" -
}

cleanup() {
    # Close the FIFO writer so direwolf sees EOF and exits cleanly.
    exec 3>&- 2>/dev/null || true
    if [[ -n "$DW_PID" ]] && kill -0 "$DW_PID" 2>/dev/null; then
        echo "Stopping direwolf (pid $DW_PID)..."
        kill "$DW_PID"
        wait "$DW_PID" 2>/dev/null || true
    fi
    [[ -n "$WAV_FILE" ]]    && rm -f "$WAV_FILE"
    [[ -n "$GEN_CONF" ]]    && rm -f "$GEN_CONF"
    [[ -n "$FIFO" ]]        && rm -f "$FIFO"
    [[ -n "$RANDOM_FILE" ]] && rm -f "$RANDOM_FILE"
    [[ -f "$LOG" ]] && echo "direwolf log: $LOG"
}

while getopts ":c:s:r:n:Rh" opt; do
    case $opt in
        c) CONF="$OPTARG" ;;
        s) SERIAL_DEVICE="$OPTARG" ;;
        r) REPEAT_INTERVAL="$OPTARG" ;;
        n) REPEAT_COUNT="$OPTARG" ;;
        R) RANDOM_MODE=true ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "Error: Unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ "$RANDOM_MODE" == true ]]; then
    # Random mode generates its own packet into a temp file; no input file needed.
    RANDOM_FILE=$(mktemp /tmp/aprs-random-XXXXXX.txt)
    PACKET_FILE="$RANDOM_FILE"
    gen_random_packet > "$PACKET_FILE"
else
    if [[ $# -lt 1 ]]; then
        echo "Error: packet file required (or pass -R for a random message)." >&2
        usage
    fi
    PACKET_FILE="$1"
    [[ -f "$PACKET_FILE" ]] || { echo "Error: file not found: $PACKET_FILE" >&2; exit 1; }
fi

[[ -f "$CONF" ]]        || { echo "Error: direwolf conf template not found: $CONF" >&2; exit 1; }

command -v direwolf    &>/dev/null || { echo "Error: direwolf not found." >&2; exit 1; }
command -v gen_packets &>/dev/null || { echo "Error: gen_packets not found." >&2; exit 1; }

WAV_FILE=$(mktemp /tmp/aprs-test-XXXXXX.wav)
GEN_CONF=$(mktemp /tmp/direwolf-test-XXXXXX.conf)
FIFO=$(mktemp -u /tmp/aprs-test-XXXXXX.fifo)
mkfifo "$FIFO"
trap cleanup EXIT INT TERM

# Generate the direwolf.conf from the template, resolving %%SERIALKISS%%.
if [[ -n "$SERIAL_DEVICE" ]]; then
    echo "Using serial KISS device: $SERIAL_DEVICE"
    sed "s|^%%SERIALKISS%%$|SERIALKISS ${SERIAL_DEVICE}|" "$CONF" > "$GEN_CONF"
else
    sed '/^%%SERIALKISS%%$/d' "$CONF" > "$GEN_CONF"
fi

# Generate the initial WAV. In random mode play_once regenerates a fresh
# message (and WAV) for each injection, so skip the upfront work here.
if [[ "$RANDOM_MODE" != true ]]; then
    echo "Generating WAV from: $PACKET_FILE"
    make_wav
fi

# direwolf reads RX audio from the FIFO (ADEVICE stdin in the conf). Open the
# FIFO read-write on fd 3 first so the open never blocks and direwolf never sees
# EOF between packets; it decodes each WAV we feed and forwards the frame to its
# KISS client(s).
exec 3<>"$FIFO"
direwolf -t 0 -c "$GEN_CONF" < "$FIFO" > "$LOG" 2>&1 &
DW_PID=$!
echo "Started direwolf (pid $DW_PID)"

# Wait for direwolf's KISS port to come up.
echo "Waiting for direwolf to be ready..."
for i in $(seq 1 20); do
    (exec 4<>/dev/tcp/localhost/8001) 2>/dev/null && break
    sleep 0.25
done
echo "Direwolf ready."

play_once() {
    if [[ "$RANDOM_MODE" == true ]]; then
        gen_random_packet > "$PACKET_FILE"
        make_wav
    fi
    echo "Injecting: $(cat "$PACKET_FILE")"
    cat "$WAV_FILE" >&3
}

if [[ -n "$REPEAT_INTERVAL" ]]; then
    echo "Repeating every ${REPEAT_INTERVAL}s. Ctrl-C to stop."
    while true; do
        play_once
        sleep "$REPEAT_INTERVAL"
    done
else
    for ((i = 1; i <= REPEAT_COUNT; i++)); do
        [[ $REPEAT_COUNT -gt 1 ]] && echo "[$i/$REPEAT_COUNT]"
        play_once
        [[ $i -lt $REPEAT_COUNT ]] && sleep 1
    done
    # Give direwolf a moment to decode and forward the last packet before
    # cleanup closes the FIFO and stops it.
    sleep 1
fi
