#!/usr/bin/env bash
# Run a kiss8b build in Altirra (under Bottles/Wine).
#
#   run-atari.sh debug      build/atari/debug/kiss8b.atr
#   run-atari.sh release    build/atari/release/kiss8b.atr
#
# One-time setup:
#   - flatpak override --user com.usebottles.bottles --filesystem=home
#   - export ALTIRRA_EXE=/path/to/Altirra64.exe
#   - put the 850 firmware at .altirra-firmware/850.rom, two directories
#     up from Altirra64.exe (e.g. mine's at ~/.altirra-firmware)
#     get it from: https://github.com/ascrnet/FW-Altirra/raw/refs/heads/main/Automatic/850.rom
#
# platform/atari/altirra/Altirra.ini has a profile with the 850 + TCP (port 9000) serial
# port configured.

set -euo pipefail

: "${ALTIRRA_EXE:?set ALTIRRA_EXE to the path of Altirra64.exe}"
bottle="${ALTIRRA_BOTTLE:-altirra}"
profile="${ALTIRRA_PROFILE:-kiss8b}"
ini="platform/atari/altirra/Altirra.ini"

case "${1:-}" in
  debug|release) atr="build/atari/$1/kiss8b.atr" ;;
  *) echo "usage: $0 debug|release" >&2; exit 1 ;;
esac

[[ -f "$atr" ]] || { echo "no such file: $atr" >&2; exit 1; }

# Wine maps Z: to the host root
winpath() { printf 'Z:%s' "$(realpath "$1" | sed 's#/#\\\\#g')"; }

exec flatpak run --command=bottles-cli com.usebottles.bottles \
  run -b "$bottle" -e "$ALTIRRA_EXE" --args-replace -- \
  /singleinstance \
  "/portablealt:$(winpath "$ini")" \
  "/profile:$profile" \
  "$(winpath "$atr")"
