---
name: garmin-watchface
description: Design, build, preview and sideload Garmin Connect IQ watch faces (digital or analog) for any Connect IQ watch. Use when the user wants a custom Garmin watch face, wants to change one, preview it in the simulator, or install it on their watch over USB.
---

# Garmin watch face

Build a Connect IQ watch face in Monkey C, check it in the simulator after every visual change,
then sideload it over USB. Scripts are in `scripts/`, a working starter face is in `template/`,
and the source repo's `examples/prayer-watchface` is a complete two-face project (digital +
analog) to copy patterns from.

Read `references/gotchas.md` before writing code. Every item in it cost real debugging time.

## 1. Find out what is being built

Ask only what you cannot default:
- **Which watch?** Get the Connect IQ device id (e.g. `fr55`, `fenix7`, `venu3`). List installed
  profiles with `scripts/device_info.py --list`. If the watch is missing, the user must download
  it in the Connect IQ SDK Manager.
- **Digital or analog**, and what data on the face (date, steps, heart rate, battery, sunrise...).
- **Settings** the wearer should change on the watch (colours, units, options).

## 2. Read the device limits

```
scripts/device_info.py <device-id>
```
Prints the resolution, round or rectangular shape, colour depth (MIP or AMOLED), font pixel
sizes, memory limit and API level. Design for these numbers, not for a phone screen.

## 3. Start from the template

```
scripts/new_face.sh <dir> "<Face Name>" <device-id> [more device ids]
```
It copies `template/`, gives the face a fresh app id (two faces with the same id replace each
other on the watch) and writes per-device build paths. The template already has the clock,
date, heart rate with an all-day fallback, steps, battery and an on-watch settings menu.

## 4. Build, look, fix: repeat

```
scripts/build.sh <dir> <device-id>                        # -> <dir>/bin/<device>.prg
scripts/sim.sh <dir>/bin/<device>.prg <device-id> shot.png
```
**Open the screenshot and look at it after every layout change.** Text is wider than the
nominal font size suggests, and greys disappear on MIP screens. Fix overlaps, then repeat.
Treat compiler warnings as bugs.

## 5. Install on the watch

```
scripts/sideload.sh <dir>/bin/<device>.prg FACENAME.PRG
```
Copies to `GARMIN/APPS` on a USB-mounted watch and verifies the copy. Watches that use MTP
(most models from 2022 on) do not mount as a drive: tell the user to copy the `.prg` into
`GARMIN/APPS` with Windows Explorer or OpenMTP. Then: unplug, hold UP (or the menu button) >
Watch Face > pick the face.

## Rules

- Lay out with `dc.getWidth()` and `dc.getHeight()` fractions, and check each target device in
  the simulator. Round screens lose their corners: keep text inside the circle.
- Settings from the Garmin Connect phone app never reach sideloaded faces. Put options in an
  on-watch `Menu2` returned from `getSettingsView()` and store them with `Application.Storage`.
- Watch faces cannot switch GPS on. For location, read `Activity.getActivityInfo().currentLocation`
  (the last fix from any activity), save it in Storage and keep a default.
- Live heart rate only exists during an activity; fall back to
  `ActivityMonitor.getHeartRateHistory(1, true)`.
- Keep `onUpdate` cheap: it runs once a minute in low-power mode, more often when the wearer
  looks at the watch. Load fonts and bitmaps once, not on every update.
- New logic that is not purely visual (calculations, calendars, parsers) gets a small check:
  mirror it in Python and compare against a trusted library across a range of inputs.
- Never commit or share the developer key (`*.der`).

## References

- `references/devices.md`: compatibility, display types, memory, sideloading by model.
- `references/gotchas.md`: problems already solved: simulator, fonts, Arabic text, settings, jungle files.
