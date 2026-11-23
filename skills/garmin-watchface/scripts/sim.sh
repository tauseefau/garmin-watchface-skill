#!/usr/bin/env bash
# Run a .prg in the Connect IQ simulator and save a screenshot of the simulator window.
# Usage: sim.sh <file.prg> <device-id> [screenshot.png]
# Linux/macOS: uses the native simulator.  WSL: uses the Windows simulator (the Linux one
# usually lacks webkit/libsecret libraries) and forwards its port 1234 into WSL.
# The simulator often stops accepting uploads after a load or two, so it is restarted each run.
set -euo pipefail
. "$(dirname "$0")/ciq_env.sh"
PRG="$(realpath "${1:?prg}")"; DEV="${2:?device}"; OUT="${3:-}"

if is_wsl; then
  WIN_SDK=$(ls -d /mnt/c/Users/*/AppData/Roaming/Garmin/ConnectIQ/Sdks/*/bin 2>/dev/null | tail -1)
  [ -n "$WIN_SDK" ] || { echo "Install the Connect IQ SDK on Windows too (SDK Manager) for the simulator." >&2; exit 1; }
  powershell.exe -NoProfile -Command "Stop-Process -Name simulator -Force -ErrorAction SilentlyContinue; Start-Sleep 2; Start-Process -FilePath '$(wslpath -w "$WIN_SDK")\\simulator.exe'; Start-Sleep 8" >/dev/null
  HOST=$(ip route | awk '/default/ {print $3; exit}')
  if ! ss -ltn | grep -q '127.0.0.1:1234'; then
    # tiny TCP forwarder: WSL localhost:1234 -> Windows simulator
    (timeout 1800 python3 -c '
import socket,threading,sys
def pipe(a,b):
    try:
        while (d:=a.recv(65536)): b.sendall(d)
    except OSError: pass
    finally: a.close(); b.close()
L=socket.socket(); L.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); L.bind(("127.0.0.1",1234)); L.listen()
while True:
    c,_=L.accept(); u=socket.create_connection((sys.argv[1],1234))
    for x,y in ((c,u),(u,c)): threading.Thread(target=pipe,args=(x,y),daemon=True).start()
' "$HOST" >/dev/null 2>&1 &)
    sleep 1
  fi
else
  pkill -f "ConnectIQ.*simulator|/simulator$" 2>/dev/null || true
  ("$CIQ_HOME/connectiq" >/dev/null 2>&1 &); sleep 6
fi

timeout 30 "$CIQ_HOME/monkeydo" "$PRG" "$DEV" >/dev/null 2>&1 & sleep 12
[ -z "$OUT" ] && { echo "loaded in simulator"; exit 0; }

if is_wsl; then
  WOUT='C:\Windows\Temp\ciq-sim.png'
  powershell.exe -NoProfile -Command '
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class W{[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out R r);[DllImport("user32.dll")]public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint f);[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);public struct R{public int L,T,Rt,B;}}
"@
[W]::SetProcessDPIAware()|Out-Null
$p=Get-Process simulator|?{$_.MainWindowHandle -ne 0}|select -first 1
[W]::ShowWindow($p.MainWindowHandle,9)|Out-Null; Start-Sleep 1
$r=New-Object W+R; [W]::GetWindowRect($p.MainWindowHandle,[ref]$r)|Out-Null
$b=New-Object Drawing.Bitmap ($r.Rt-$r.L),($r.B-$r.T); $g=[Drawing.Graphics]::FromImage($b)
$h=$g.GetHdc(); [W]::PrintWindow($p.MainWindowHandle,$h,2)|Out-Null; $g.ReleaseHdc($h)
$b.Save("'"$WOUT"'")' >/dev/null
  cp "$(wslpath -u "$WOUT")" "$OUT"
elif [ "$(uname)" = Darwin ]; then
  screencapture -x "$OUT"
elif command -v import >/dev/null; then
  import -window "$(xdotool search --name 'CIQ Simulator' | head -1)" "$OUT" 2>/dev/null || import -window root "$OUT"
else
  echo "Install ImageMagick (import) and xdotool for screenshots, or use the simulator's File > Save Screenshot." >&2; exit 1
fi
echo "screenshot $OUT"
