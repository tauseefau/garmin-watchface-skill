# Device compatibility

Connect IQ watch faces run on every Garmin watch that supports Connect IQ (the device appears
in the SDK Manager). That covers current and recent Forerunner, fenix, epix, Enduro, Instinct,
Venu, vivoactive, MARQ, Descent, quatix, tactix and Approach watches. Fitness bands (vivosmart,
vivofit) and Lily do not run Connect IQ.

Check the exact limits for your watch with `scripts/device_info.py <device-id>`.

## Display types

| Type | Examples | What changes |
|---|---|---|
| MIP, 8 or 64 colours (4-bit) | Forerunner 55/255/955, fenix 6/7, Instinct 2 (mono) | No real greys: `COLOR_DK_GRAY` renders black and `COLOR_LT_GRAY` white. Use colour for hierarchy. Always-on, sunlight readable. |
| AMOLED, 16-bit | Forerunner 265/965, Venu 2/3, epix, fenix 8 AMOLED, vivoactive 5 | Full colour. In always-on/low-power mode Garmin limits how many pixels may be lit (burn-in protection): draw a sparse dim version in `onEnterSleep`/`onUpdate` when asleep. |
| Monochrome | Instinct, Instinct 2/3 (main screen) | Black and white only, plus a small round sub-window on some models. |

## Memory

Watch faces have a hard memory limit, often 64-128 KB (`device_info.py` prints it). Bitmaps and
custom fonts count against it. The simulator's status bar shows current/peak memory.

## Sideloading by connection type

| Connection | Watches | How |
|---|---|---|
| USB mass storage (shows as a drive) | Older and simpler models, e.g. Forerunner 55/245/945, fenix 5/6 | `scripts/sideload.sh` copies into `GARMIN/APPS` and verifies it. |
| MTP (shows as a media device) | Most models from about 2022: Forerunner 255/265/955/965, fenix 7/8, epix, Venu 2/3 | Copy the `.prg` into `Internal Storage/GARMIN/Apps` with Windows Explorer, or OpenMTP on macOS. Linux: `gio`/`jmtpfs`. |

A sideloaded face is removed if the watch is reset; keep the `.prg`. To publish for everyone,
export an `.iq` package (`monkeyc -e`) and upload it to the Connect IQ Store.
