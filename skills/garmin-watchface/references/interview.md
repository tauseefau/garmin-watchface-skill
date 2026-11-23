# Grill-me interview: watch face requirements

Inspired by Matt Pocock's "grill-me" skill (https://github.com/mattpocock/skills/tree/main/skills/productivity/grill-me): interview the
user relentlessly, one question at a time, until there is a shared understanding. Then build.

## How to run it

- Ask **one question per message**. Wait for the answer before the next one.
- Every question comes with **your recommended answer** and a one-line reason, so the user can
  just reply "yes".
- **Don't ask what you can find out.** Check installed device profiles (`device_info.py --list`),
  the watch's screen and fonts (`device_info.py <id>`), and the user's OS yourself.
- Follow the branches: an analog face needs hand and index questions, a data-heavy face needs a
  priority order, an AMOLED watch needs an always-on question. Skip branches that don't apply.
- Push back on things that won't fit. A 208 px round screen holds roughly the time, 2 small text
  lines and one row of 3 icons + numbers. Say so, and ask what to drop.
- Stop when every question below is answered or ruled out. Then write the brief (see the end)
  and get a clear "yes" before writing code.
- If the user says "just build it", use your recommended answers for the rest and list them in
  the brief.

## Question tree

1. **Watch model.** Which Garmin watch is it for? Map the answer to a device id and confirm the
   profile is installed. Recommend: the watch they wear. Several models: pick the main one now,
   add the others after the first one works.
2. **Style.** Digital, analog (hands), or hybrid? Sporty, classic/dress, minimal, or
   information-dense? Ask for a reference photo or a watch they like the look of.
   Recommend: digital for MIP screens with lots of data; analog for a classic look.
3. **The one thing.** What should they read in under a second? Usually the time. Then ask
   for the ranked list in question 4.
4. **Data, ranked.** From: date, day, steps, heart rate, battery, calories, distance, floors,
   active minutes, sunrise/sunset, weather (if the watch supports it), notifications count,
   alarms, seconds, a second time zone, or something custom (e.g. prayer times, tide, a
   countdown). Ask them to rank. Explain the screen budget and agree what to drop.
5. **Behaviour of each item.** For each chosen item: number only, icon + number, or a progress
   arc/bar? What should it show when there is no data ("--", hide it)?
6. **Colours.** Background, main colour, and one accent colour. On MIP screens, remind them
   there are no greys: hierarchy comes from colour. Recommend black background, white main, one
   accent.
7. **Time format.** Follow the watch's 12/24 h setting (recommended), or force one? Leading
   zero? Seconds? (Seconds only update every minute in low-power mode on most watches.)
8. **Analog only.** Hand shape (baton, dauphine, sword), index style (batons, numerals,
   dots), date window position, a coloured seconds hand or centre cap.
9. **AMOLED only.** Always-on look: dim minimal version (time only) or screen off? Garmin limits
   lit pixels in always-on mode.
10. **On-watch settings.** Which options should the wearer change on the watch (accent colour,
    which data in a slot, units, language)? Recommend 1-3. Settings in the Garmin Connect
    phone app don't reach sideloaded faces.
11. **Language and units.** Language of text, number style (e.g. Arabic digits), km/mi, °C/°F.
12. **Name.** The face's name as it appears in the watch's face list (short, under ~16 characters).
13. **Install.** How will it get onto the watch? Check whether the watch mounts as a USB
    drive or needs MTP, and which OS they use. Store publishing is a separate later step.

## The brief

Write `BRIEF.md` in the face's folder and show it:

```
# <Face name> - brief
Watch: <model> (<device id>), <WxH> <shape>, <MIP/AMOLED>
Style: <...>
Glance item: <...>
Layout, top to bottom: <...>
Data (ranked): 1. ... 2. ... 3. ...
Colours: background <...>, main <...>, accent <...>
Time: <12/24 rule>, seconds <yes/no>
Settings on the watch: <...>
Language/units: <...>
Install: <USB drive / MTP>
Defaults I chose (you didn't specify): <...>
```

Ask: "Build this?" Only start on step 3 of SKILL.md after a yes. Keep the brief updated if
they change their mind later.
