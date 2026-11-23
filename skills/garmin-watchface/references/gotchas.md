# Gotchas (each one cost real time)

## Build
- **`base.sourcePath` / `base.resourcePath` were ignored** by SDK 9.x on Linux/WSL ("A bitmap
  resource matching the provided launcher icon can't be found"). Use device-qualified lines
  (`fr55.resourcePath = resources`) for every target; `new_face.sh` writes them.
- **"Unexpected source pixel format"** for one device usually means its profile is only partly
  downloaded. Re-download that device in the SDK Manager.
- Type errors such as `Invalid ... passed as parameter` for `fillPolygon`: return points typed
  as tuples, `as [Number, Number]`, not `Array<Number>`.
- Launcher icon size differs per device (`launcherIcon` in the profile's compiler.json); a
  mismatch only warns and gets scaled.

## Simulator
- **WSL**: the Linux simulator usually misses libraries (webkit2gtk, libsecret). Run the Windows
  simulator and forward port 1234 into WSL; `scripts/sim.sh` does both.
- The simulator often stops accepting uploads ("Unable to connect to simulator") after a load
  or two. Restart it before each upload; `sim.sh` does.
- Screen capture of a covered window gives the wrong pixels. Use `PrintWindow` on Windows
  (`sim.sh` does), `screencapture` on macOS, ImageMagick `import` on Linux.
- Simulator storage persists per app id. A test build that writes Storage (e.g. a fake
  location) leaves that value behind for later runs.

## Layout and drawing
- Fonts are wider than their pixel height suggests. Measure with `dc.getTextWidthInPixels` and
  look at the screenshot. Five "05:06" strings do not fit in a row on a 208 px screen.
- Round screens: at height y from the centre, usable width is `2*sqrt(r^2 - y^2)`. Text near
  the top and bottom has to be short.
- Draw icons with primitives (circles, polygons, lines) instead of bitmaps; they scale and
  cost almost no memory. Cut-outs drawn in "background" colour must take the real background
  as a parameter, or they show as black blobs on coloured banners.

## Settings and data
- Garmin Connect app settings (properties.xml / settings.xml) do not reach **sideloaded** faces.
  Use an on-watch `Menu2` from `getSettingsView()` and `Application.Storage`.
- `Application.Properties.getValue` can throw on sideloaded apps: wrap it in try/catch.
- Heart rate: `Activity.getActivityInfo().currentHeartRate` is null outside an activity; use
  `ActivityMonitor.getHeartRateHistory(1, true).next()` as the fallback.
- Location: faces cannot request GPS. `Activity.getActivityInfo().currentLocation` gives the last
  fix from any activity; persist it and ignore 0,0.

## Non-Latin text (Arabic, Hebrew, etc.)
- Built-in number fonts lack Arabic-Indic digits (they draw boxes). Bundle a BMFont made from an
  open-licence font (see the example's `tools/make_arabic_fonts.py`).
- The watch cannot join Arabic letters: pre-shape words into presentation forms
  (`arabic-reshaper`) when you build. Keep them in **logical** order: the watch's text engine
  already lays out right-to-left, so a pre-reversed string comes out backwards.
- Only redistribute fonts whose licence allows it (SIL OFL fonts such as Noto are fine).

## Calculations
- Verify astronomy/calendar maths against a trusted library over a whole year, not one date.
  The example's original Asr formula had a sign error that only showed up for one setting.
