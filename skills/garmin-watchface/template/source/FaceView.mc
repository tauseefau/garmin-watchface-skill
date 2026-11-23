// Starter digital face: date, two-colour clock, heart rate, steps, battery.
// Layout uses fractions of the screen size so it scales across watches; check every
// target in the simulator anyway (font sizes differ per device).
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class FaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var accent = ACCENTS[accentIndex()];
        var C = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // date
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 22 / 100, Graphics.FONT_XTINY,
                    info.day_of_week + " " + info.day.format("%d") + " " + info.month, C);

        // clock: hours white, minutes in the accent colour
        var clock = System.getClockTime();
        var hh = clock.hour;
        if (!System.getDeviceSettings().is24Hour) { hh = hh % 12; if (hh == 0) { hh = 12; } }
        var hs = hh.format("%02d") + ":";
        var ms = clock.min.format("%02d");
        var f = Graphics.FONT_NUMBER_HOT;
        var hw = dc.getTextWidthInPixels(hs, f);
        var x0 = cx - (hw + dc.getTextWidthInPixels(ms, f)) / 2;
        var L = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.drawText(x0, h * 45 / 100, f, hs, L);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + hw, h * 45 / 100, f, ms, L);

        // heart rate: live value only exists during an activity, so fall back to the
        // latest all-day sample
        var hr = 0;
        var act = Activity.getActivityInfo();
        if (act != null && act.currentHeartRate != null) { hr = act.currentHeartRate as Number; }
        if (hr == 0 && (ActivityMonitor has :getHeartRateHistory)) {
            var s = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hr = s.heartRate as Number;
            }
        }
        var am = ActivityMonitor.getInfo();
        var steps = (am != null && am.steps != null) ? am.steps as Number : 0;
        var bat = System.getSystemStats().battery.toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 66 / 100, Graphics.FONT_XTINY,
                    (hr > 0 ? hr.format("%d") : "--") + " bpm   " + steps.format("%d") + " steps", C);

        // battery bar
        var bw = w * 30 / 100;
        var by = h * 78 / 100;
        dc.drawRectangle(cx - bw / 2, by, bw, 8);
        dc.setColor(bat < 20 ? Graphics.COLOR_RED : accent, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bw / 2 + 2, by + 2, (bw - 4) * bat / 100, 4);
    }
}
