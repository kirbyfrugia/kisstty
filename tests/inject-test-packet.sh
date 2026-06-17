#!/usr/bin/env bash
# inject-test-packet.sh - Simulate an APRS packet arriving at kiss8b: generate the
# packet's audio and feed it through a temporary Direwolf, which decodes it to KISS.
#
# Usage:
#   inject-test-packet.sh [options] <packet-file>
#
# Options:
#   -c <conf>      Path to direwolf.conf template (default: direwolf.conf.template
#                  in the same dir as this script)
#   -s <device>    Serial device for KISS (default: /tmp/altirra-tty, the socat
#                  PTY for the Altirra bridge). Pass -s '' for TCP KISS only
#                  (port 8001, no SERIALKISS line).
#   -r <seconds>   Repeat every N seconds (indefinitely, Ctrl-C to stop)
#   -n <count>     Repeat N times (default: 1)
#   -h             Show this help
#
# Examples:
#   inject-test-packet.sh tests/aprs/position.txt
#   inject-test-packet.sh -s /dev/ttyUSB0 tests/aprs/position.txt
#   inject-test-packet.sh -r 30 tests/aprs/position.txt
#   inject-test-packet.sh -n 5 tests/aprs/position.txt
#   inject-test-packet.sh -c ~/.config/direwolf/direwolf.conf.template tests/aprs/position.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/direwolf.conf.template"
# Default to the socat PTY for the Altirra bridge (the primary use case).
# Override with -s <device>, or -s '' for TCP KISS only.
SERIAL_DEVICE="/tmp/altirra-tty"
REPEAT_INTERVAL=""
REPEAT_COUNT=1
DW_PID=""
WAV_FILE=""
GEN_CONF=""
FIFO=""
LOG="/tmp/direwolf-test.log"

usage() {
    sed -n '3,23p' "$0" | sed 's/^# \?//'
    exit 1
}

cleanup() {
    # Close the FIFO writer so direwolf sees EOF and exits cleanly.
    exec 3>&- 2>/dev/null || true
    if [[ -n "$DW_PID" ]] && kill -0 "$DW_PID" 2>/dev/null; then
        echo "Stopping direwolf (pid $DW_PID)..."
        kill "$DW_PID"
        wait "$DW_PID" 2>/dev/null || true
    fi
    [[ -n "$WAV_FILE" ]] && rm -f "$WAV_FILE"
    [[ -n "$GEN_CONF" ]] && rm -f "$GEN_CONF"
    [[ -n "$FIFO" ]]     && rm -f "$FIFO"
    [[ -f "$LOG" ]] && echo "direwolf log: $LOG"
}

while getopts ":c:s:r:n:h" opt; do
    case $opt in
        c) CONF="$OPTARG" ;;
        s) SERIAL_DEVICE="$OPTARG" ;;
        r) REPEAT_INTERVAL="$OPTARG" ;;
        n) REPEAT_COUNT="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "Error: Unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
    echo "Error: packet file required." >&2
    usage
fi

PACKET_FILE="$1"

[[ -f "$PACKET_FILE" ]] || { echo "Error: file not found: $PACKET_FILE" >&2; exit 1; }
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

# Generate WAV. Strip comment/blank lines, and feed the packet with no trailing
# newline -- gen_packets would otherwise keep it as a stray <0x0a> in the info
# field (which an APRS message's {seq number runs into, for example).
echo "Generating WAV from: $PACKET_FILE"
printf '%s' "$(grep -v '^\s*#' "$PACKET_FILE" | grep -v '^\s*$')" | gen_packets -o "$WAV_FILE" -

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
