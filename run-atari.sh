#!/usr/bin/env bash
# Run a kisstty build in Altirra (under Bottles/Wine).
#
#   run-atari.sh debug      build/atari/debug/kisstty.atr
#   run-atari.sh release    build/atari/release/kisstty.atr
#
# One-time setup:
#   - flatpak override --user com.usebottles.bottles --filesystem=home
#   - export ALTIRRA_EXE=/path/to/Altirra64.exe
#   - put the 850 firmware at .altirra-firmware/850.rom, two directories
#     up from Altirra64.exe (e.g. mine's at ~/.altirra-firmware)
#     get it from: https://github.com/ascrnet/FW-Altirra/raw/refs/heads/main/Automatic/850.rom
#
# Altirra.ini is generated from Altirra.ini.template (a profile with the 850 +
# TCP port 9000 serial configured). Delete it to regenerate.

set -euo pipefail

: "${ALTIRRA_EXE:?set ALTIRRA_EXE to the path of Altirra64.exe}"
bottle="${ALTIRRA_BOTTLE:-altirra}"
profile="${ALTIRRA_PROFILE:-kisstty}"
ini="platform/atari/altirra/Altirra.ini"

case "${1:-}" in
  debug|release) atr="build/atari/$1/kisstty.atr" ;;
  *) echo "usage: $0 debug|release" >&2; exit 1 ;;
esac

[[ -f "$atr" ]] || { echo "no such file: $atr" >&2; exit 1; }

# Wine maps Z: to the host root
winpath() { printf 'Z:%s' "$(realpath "$1" | sed 's#/#\\\\#g')"; }

# Generate Altirra.ini from the template when missing (so Altirra's own edits
# to it survive), substituting %%PROJECT_ROOT%% and %%DIST%%. The .ini escapes
# backslashes, so each "/" becomes "\\"; awk via ENVIRON keeps them literal,
# where sed or bash ${//} would mangle them. The mounted disk is set by the CLI
# arg below regardless, so a stale %%DIST%% here only affects Altirra's own UI.
if [[ ! -f "$ini" ]]; then
  [[ -f "$ini.template" ]] || { echo "missing template: $ini.template" >&2; exit 1; }
  proj_root="$(realpath .)"
  proj_root="${proj_root//\//\\\\}"
  PROJECT_ROOT="$proj_root" DIST="$1" awk '
    BEGIN { FS="%%PROJECT_ROOT%%"; root=ENVIRON["PROJECT_ROOT"]; dist=ENVIRON["DIST"] }
    { line=$1; for (i=2;i<=NF;i++) line=line root $i; gsub(/%%DIST%%/, dist, line); print line }
  ' "$ini.template" > "$ini"
  echo "generated $ini from template" >&2
fi

exec flatpak run --command=bottles-cli com.usebottles.bottles \
  run -b "$bottle" -e "$ALTIRRA_EXE" --args-replace -- \
  /singleinstance \
  "/portablealt:$(winpath "$ini")" \
  "/profile:$profile" \
  "$(winpath "$atr")"
