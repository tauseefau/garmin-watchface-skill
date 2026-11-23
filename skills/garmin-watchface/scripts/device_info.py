#!/usr/bin/env python3
"""Print what a watch face has to fit: screen, colours, fonts, memory, API level.

Usage:  device_info.py <device-id>     e.g. fr55, fenix7, venu3
        device_info.py --list          installed device profiles
Reads the profiles the Connect IQ SDK Manager downloads (not shipped in the SDK zip).
"""
import json, os, re, sys
from pathlib import Path

def devices_dir() -> Path:
    cands = [os.environ.get("CIQ_DEVICES", ""),
             "~/.Garmin/ConnectIQ/Devices",                                   # Linux / WSL
             "~/Library/Application Support/Garmin/ConnectIQ/Devices",       # macOS
             os.path.join(os.environ.get("APPDATA", ""), "Garmin/ConnectIQ/Devices")]  # Windows
    for c in cands:
        p = Path(c).expanduser()
        if c and p.is_dir():
            return p
    sys.exit("No Connect IQ device profiles found. Open the SDK Manager and download your watch.")

def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    base = devices_dir()
    if sys.argv[1] == "--list":
        print("\n".join(sorted(d.name for d in base.iterdir() if (d / "compiler.json").exists())))
        return
    d = base / sys.argv[1]
    if not (d / "compiler.json").exists():
        sys.exit(f"{d} not found. Run with --list, or download the device in the SDK Manager.")
    comp = json.loads((d / "compiler.json").read_text())
    sim = json.loads((d / "simulator.json").read_text())
    res = comp["resolution"]
    shape = sim.get("display", {}).get("shape", "?")
    bpp = comp.get("bitsPerPixel")
    mem = {a["type"]: a["memoryLimit"] for a in comp.get("appTypes", [])}
    api = comp.get("partNumbers", [{}])[0].get("connectIQVersion", "?")
    print(f"device      {comp.get('displayName', sys.argv[1])} ({sys.argv[1]})")
    print(f"screen      {res['width']}x{res['height']} {shape}, {bpp} bits/pixel, {comp.get('displayType', '?')}")
    if bpp and bpp <= 4:
        print("            MIP/low-colour: DK_GRAY shows as black, LT_GRAY as white. Use colour, not grey, for hierarchy.")
    print(f"api level   {api}  (set minApiLevel in manifest.xml at or below this)")
    print(f"memory      watchFace {mem.get('watchFace', '?')} bytes, watchApp {mem.get('watchApp', '?')} bytes")
    print("fonts       (name -> source font; the number is roughly the pixel height)")
    for f in sim.get("fonts", [{}])[0].get("fonts", []):
        size = re.findall(r"(\d+)B?$", f["filename"])
        print(f"            {f['name']:<16} {size[0] + 'px' if size else ''}  {f['filename']}")

if __name__ == "__main__":
    main()
