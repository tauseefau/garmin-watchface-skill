#!/usr/bin/env bash
# Build a watch face for one device.  Usage: build.sh <project-dir> <device-id> [jungle-file]
# Output: <project-dir>/bin/<device>.prg (sideload this).  Warnings are shown; treat them as bugs.
set -euo pipefail
. "$(dirname "$0")/ciq_env.sh"
P="${1:?project dir}"; DEV="${2:?device id, e.g. fr55}"; J="${3:-monkey.jungle}"
mkdir -p "$P/bin"
"$CIQ_HOME/monkeyc" -f "$P/$J" -o "$P/bin/$DEV.prg" -d "$DEV" -y "$CIQ_KEY" -w -O 3 -r
echo "built $P/bin/$DEV.prg"
