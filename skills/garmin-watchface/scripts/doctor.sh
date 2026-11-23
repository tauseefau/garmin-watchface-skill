#!/usr/bin/env bash
# Check the toolchain before starting. Usage: doctor.sh [device-id]
# Prints one line per check; exit code 1 if anything required is missing.
D="$(dirname "$0")"; bad=0
ok()   { echo "  ok    $*"; }
miss() { echo "  MISSING $*"; bad=1; }
echo "Garmin watch face toolchain:"
if command -v java >/dev/null; then ok "java ($(java -version 2>&1 | head -1))"; else miss "java 17+ (install a JDK, e.g. OpenJDK 17)"; fi
command -v python3 >/dev/null && ok "python3" || miss "python3"
( . "$D/ciq_env.sh" >/dev/null 2>&1 && echo "$CIQ_HOME" ) > /tmp/.ciq_doctor 2>/dev/null
if [ -s /tmp/.ciq_doctor ]; then ok "Connect IQ SDK at $(cat /tmp/.ciq_doctor)"; else
  ( . "$D/ciq_env.sh" ) 2>&1 | sed 's/^/        /'; miss "Connect IQ SDK and/or developer key (see above)"; fi
rm -f /tmp/.ciq_doctor
DEVS=$(python3 "$D/device_info.py" --list 2>/dev/null)
if [ -n "$DEVS" ]; then ok "device profiles: $(echo $DEVS)"; else miss "device profiles (SDK Manager > Devices > download your watch)"; fi
if [ -n "${1:-}" ]; then echo "$DEVS" | grep -qx "$1" && ok "profile for $1" || miss "profile for $1 (download it in the SDK Manager)"; fi
if grep -qi microsoft /proc/version 2>/dev/null; then
  ls -d /mnt/c/Users/*/AppData/Roaming/Garmin/ConnectIQ/Sdks/*/bin >/dev/null 2>&1 && ok "Windows SDK for the simulator (WSL)" || miss "Connect IQ SDK on Windows too (WSL uses the Windows simulator)"
fi
exit $bad
