#!/usr/bin/env bash
# Copy a built face onto a USB-connected watch and verify the copy.
# Usage: sideload.sh <file.prg> [NAME.PRG]   (NAME: 8.3 upper-case, default from the file name)
# Works for watches that mount as a USB drive (e.g. Forerunner 55/245/945, older fenix).
# Newer watches that use MTP (fenix 7+, Venu 2+, FR 255+) do not mount as a drive: copy the
# .prg into GARMIN/APPS with Windows Explorer or OpenMTP (macOS) instead.
set -euo pipefail
PRG="$(realpath "${1:?prg}")"
NAME="${2:-$(basename "${PRG%.*}" | tr '[:lower:]' '[:upper:]' | cut -c1-8).PRG}"
SUM=$(md5sum "$PRG" 2>/dev/null | cut -c1-32 || md5 -q "$PRG")
if grep -qi microsoft /proc/version 2>/dev/null; then
  W=$(wslpath -w "$PRG")
  R=$(powershell.exe -NoProfile -Command "\$d=Get-PSDrive -PSProvider FileSystem | ?{ Test-Path (\$_.Root + 'GARMIN\APPS') } | select -first 1; if(\$d){ \$t=\$d.Root+'GARMIN\APPS\\$NAME'; Copy-Item -LiteralPath '$W' -Destination \$t -Force; (Get-FileHash \$t -Algorithm MD5).Hash } else { 'NOWATCH' }" | tr -d '\r')
else
  DIR=$(ls -d /media/*/GARMIN/GARMIN/APPS /run/media/*/GARMIN/GARMIN/APPS /Volumes/GARMIN/GARMIN/APPS 2>/dev/null | head -1 || true)
  if [ -z "$DIR" ]; then R=NOWATCH; else cp "$PRG" "$DIR/$NAME" && sync && R=$(md5sum "$DIR/$NAME" 2>/dev/null | cut -c1-32 || md5 -q "$DIR/$NAME"); fi
fi
[ "$R" = NOWATCH ] && { echo "No watch drive with GARMIN/APPS found. Plug the watch in (USB mass storage)." >&2; exit 1; }
if [ "${R,,}" = "${SUM,,}" ]; then echo "installed as $NAME (verified). Unplug the watch, then pick the face under Watch Face."
else echo "copy mismatch: $R vs $SUM" >&2; exit 1; fi
