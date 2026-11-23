#!/usr/bin/env bash
# Build prayer-times-fr55.iq for the Garmin Forerunner 55.
# Requires the Connect IQ 9.3.0 SDK plus an fr55 device profile installed via
# the Garmin SDK Manager (device profiles are NOT in the SDK zip).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# finds the SDK (CIQ_HOME) and developer key (CIQ_KEY); both can be overridden
. "$HERE/../../skills/garmin-watchface/scripts/ciq_env.sh"
CIQ_BIN="$CIQ_HOME"
KEY="$CIQ_KEY"

mkdir -p "$HERE/bin"

# The local SDK's generated default jungle does not discover source/resource
# files correctly on Linux, so they are listed explicitly in monkey.jungle.
"$CIQ_BIN/monkeyc" \
  -f "$HERE/monkey.jungle" \
  -o "$HERE/bin/prayer-times-fr55.iq" \
  -d fr55 \
  -y "$KEY" \
  -O 3 -r \
  -w

# Second face: analog "Prayer Classic" (own app id, same code and settings)
"$CIQ_BIN/monkeyc" \
  -f "$HERE/monkey-analog.jungle" \
  -o "$HERE/bin/prayer-classic-fr55.iq" \
  -d fr55 \
  -y "$KEY" \
  -O 3 -r \
  -w

echo "Done: $HERE/bin/prayer-times-fr55.iq $HERE/bin/prayer-classic-fr55.iq"
