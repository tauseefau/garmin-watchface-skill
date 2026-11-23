// Prayer watch face for Garmin Forerunner 55 (208x208 round, 16-colour MIP).
// Outer ring is a 24h dial (midnight at the bottom, noon at the top) with a
// dot for each prayer; the green arc fills from the last prayer to now.
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class PrayerView extends WatchUi.WatchFace {

    const IDX = [0, 2, 3, 4, 5] as Array<Number>;
    // Dhuha starts once the sun is a spear's length up; ~20 min after sunrise is the common rule.
    const DHUHA_AFTER_SUNRISE = 20;
    const LABEL = ["FAJR", "DHUHR", "ASR", "MAGHRIB", "ISHA"] as Array<String>;
    const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;
    const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"] as Array<String>;

    const HMONTHS = ["MUHARRAM", "SAFAR", "RABI I", "RABI II", "JUMADA I", "JUMADA II",
                     "RAJAB", "SHABAN", "RAMADAN", "SHAWWAL", "DHUL QADAH", "DHUL HIJJAH"] as Array<String>;
    // Umm al-Qura month lengths for 1446..1460 AH: bit m set = month m+1 has 30 days.
    // Generated from hijri-converter and checked day-by-day; outside this range the
    // tabular (Kuwaiti) calendar is used, which can be a day off.
    const UQ_START = 2460499;  // JDN of 1 Muharram 1446
    const UQ_MASKS = [622, 1373, 2778, 1748, 1701, 1355, 2711, 1358, 2734, 1452,
                      2985, 3474, 2853, 1611, 3243] as Array<Number>;

    hidden var mTimes as Array?;
    hidden var mDay as Number = -1;
    hidden var mMonth as Number = -1;
    hidden var mYear as Number = -1;
    hidden var mActiveAlert as Number = -1;
    hidden var mAlertedDay as Number = -1;
    hidden var mDismissedPrayer as Number = -1;
    hidden var m24h as Boolean = true;
    hidden var mArabic as Boolean = false;
    hidden var mArBig = null;
    hidden var mArSmall = null;
    hidden var mArText = null;
    hidden var mNow as Number = 0;
    hidden var mIdx as Number = 0;
    hidden var mDiff as Number = 0;
    hidden var mPrev as Number = 0;

    function initialize() {
        WatchFace.initialize();
    }

    function onShow() as Void {
        recalculate();
    }

    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    function getTzMinutes() as Number {
        var now = Time.now();
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        var utc = Gregorian.utcInfo(now, Time.FORMAT_SHORT);
        var tz = (local.hour * 60 + local.min) - (utc.hour * 60 + utc.min);
        if (tz > 720) { tz -= 1440; }
        if (tz < -720) { tz += 1440; }
        return tz;
    }

    function recalculate() as Void {
        var app = getApp() as PrayerApp;
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        mYear = info.year;
        mMonth = info.month;
        mDay = info.day;
        var tzHours = getTzMinutes().toFloat() / 60.0;
        mTimes = PrayerCalc.calculate(info.year, info.month, info.day,
                                      app.getLat(), app.getLng(), tzHours,
                                      app.getMethod(), app.getAsrFactor());
        if (mTimes != null) {
            mTimes[3] = (mTimes[3] as Float) + app.getAsrAdj().toFloat();  // user's Asr shift (minutes)
        }
    }

    // Prayer minute (rounded, 0..1439) for prayer slot i.
    function pMin(i as Number) as Number {
        var m = Math.round(mTimes[IDX[i]] as Float).toNumber();
        return ((m % 1440) + 1440) % 1440;
    }

    // Western digits -> Arabic-Indic (U+0660..U+0669) when the Arabic option is on.
    function digits(s as String) as String {
        if (!mArabic) { return s; }
        var out = "";
        var cs = s.toCharArray();
        for (var i = 0; i < cs.size(); i++) {
            var c = cs[i].toNumber();
            out += (c >= 48 && c <= 57) ? (c - 48 + 0x0660).toChar().toString() : cs[i].toString();
        }
        return out;
    }

    // Font for clock digits: system number font, or the bundled Arabic-digit font.
    function clockFont(def) {
        if (!mArabic) { return def; }
        if (mArBig == null) { mArBig = WatchUi.loadResource(Rez.Fonts.ArBig); }
        return mArBig;
    }

    // Font for prayer times drawn with fmtMin().
    function timeFont() {
        if (!mArabic) { return Graphics.FONT_XTINY; }
        if (mArSmall == null) { mArSmall = WatchUi.loadResource(Rez.Fonts.ArSmall); }
        return mArSmall;
    }

    // Font for Arabic words (prayer names, "time left").
    function textFont() {
        if (mArText == null) { mArText = WatchUi.loadResource(Rez.Fonts.ArText); }
        return mArText;
    }

    function fmtMin(m as Number) as String {
        var h = m / 60;
        if (!m24h) {
            h = h % 12;
            if (h == 0) { h = 12; }
            return digits(h.format("%d") + ":" + (m % 60).format("%02d"));
        }
        return digits(h.format("%02d") + ":" + (m % 60).format("%02d"));
    }

    function countdown(minutes as Number) as String {
        var h = minutes / 60;
        var m = minutes % 60;
        if (h > 0) { return h.format("%d") + "h " + m.format("%02d") + "m"; }
        return m.format("%d") + " min";
    }

    function text(dc as Dc, x as Number, y as Number, font, s as String, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Garmin arc degrees (0 = 3 o'clock, counter-clockwise) for a minute of the day,
    // with midnight at 6 o'clock.
    function arcDeg(m as Number) as Number {
        return 270 - (m * 360 / 1440);
    }

    function dot(dc as Dc, cx as Number, cy as Number, r as Number, m as Number,
                 size as Number, colour as Number) as Void {
        var a = Math.toRadians(m.toFloat() * 360.0 / 1440.0 + 180.0);
        var x = cx + (r * Math.sin(a)).toNumber();
        var y = cy - (r * Math.cos(a)).toNumber();
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, size);
    }

    // [year, month, day] in the Hijri calendar for a Gregorian date.
    function hijri(Y as Number, M as Number, D as Number) as Array<Number> {
        var a = (14 - M) / 12;
        var y = Y + 4800 - a;
        var m = M + 12 * a - 3;
        var jd = D + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045;

        var d = jd - UQ_START;
        if (d >= 0) {
            for (var yi = 0; yi < UQ_MASKS.size(); yi++) {
                for (var mi = 0; mi < 12; mi++) {
                    var len = ((UQ_MASKS[yi] >> mi) & 1) == 1 ? 30 : 29;
                    if (d < len) { return [1446 + yi, mi + 1, d + 1] as Array<Number>; }
                    d -= len;
                }
            }
        }
        var l = jd - 1948440 + 10632;
        var n = (l - 1) / 10631;
        l = l - 10631 * n + 354;
        var j = ((10985 - l) / 5316) * ((50 * l) / 17719) + (l / 5670) * ((43 * l) / 15238);
        l = l - ((30 - j) / 15) * ((17719 * j) / 50) - (j / 16) * ((15238 * j) / 43) + 29;
        var hm = (24 * l) / 709;
        return [30 * n + j - 30, hm, l - (709 * hm) / 24] as Array<Number>;
    }

    // Half sun sitting on a horizon line (dawn / sunset).
    function halfSun(dc as Dc, x as Number, y as Number, colour as Number, bg as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + 3, 4);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 5, y + 4, 11, 5);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - 6, y + 4, x + 7, y + 4);
    }

    // 12x12 prayer icon centred on x,y: dawn, high sun, low sun, sunset, crescent.
    function prayerIcon(dc as Dc, i as Number, x as Number, y as Number, bg as Number) as Void {
        if (i == 0) {
            halfSun(dc, x, y, Graphics.COLOR_ORANGE, bg);
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y - 5, x, y - 2);
            dc.drawLine(x - 5, y - 2, x - 3, y);
            dc.drawLine(x + 5, y - 2, x + 3, y);
        } else if (i == 1) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 3);
            dc.drawLine(x, y - 6, x, y - 4);
            dc.drawLine(x, y + 5, x, y + 7);
            dc.drawLine(x - 6, y, x - 4, y);
            dc.drawLine(x + 5, y, x + 7, y);
            dc.drawLine(x - 4, y - 4, x - 3, y - 3);
            dc.drawLine(x + 4, y - 4, x + 3, y - 3);
            dc.drawLine(x - 4, y + 4, x - 3, y + 3);
            dc.drawLine(x + 4, y + 4, x + 3, y + 3);
        } else if (i == 2) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + 2, y - 1, 3);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x - 6, y + 4, x + 7, y + 4);
        } else if (i == 3) {
            halfSun(dc, x, y, Graphics.COLOR_RED, bg);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 5);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + 3, y - 2, 5);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + 5, y + 3, 1);
        }
    }

    // Watch faces cannot start GPS; use the last fix from any activity. Recalculate only when
    // it moved more than ~2 km so a jittery fix does not churn storage every minute.
    function checkLocation() as Void {
        var info = Activity.getActivityInfo();
        if (info == null || info.currentLocation == null) { return; }
        var deg = (info.currentLocation as Position.Location).toDegrees();
        var lat = deg[0].toFloat();
        var lng = deg[1].toFloat();
        if ((lat == 0.0 && lng == 0.0) || lat > 90.0 || lat < -90.0 || lng > 180.0 || lng < -180.0) { return; }
        var app = getApp() as PrayerApp;
        var dLat = lat - app.getLat();
        var dLng = lng - app.getLng();
        if (dLat > 0.02 || dLat < -0.02 || dLng > 0.02 || dLng < -0.02) {
            app.setLocation(lat, lng);
            recalculate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        checkLocation();
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (mTimes == null || today.day != mDay || today.month != mMonth || today.year != mYear) {
            recalculate();
        }
        m24h = System.getDeviceSettings().is24Hour;
        mArabic = (getApp() as PrayerApp).isArabic();

        var clock = System.getClockTime();
        var nowMin = clock.hour * 60 + clock.min;

        // next / previous prayer
        var idx = 0;
        var diff = 0;
        var prevMin = 0;
        if (mTimes != null) {
            var found = false;
            for (var i = 0; i < 5; i++) {
                if (pMin(i) > nowMin) { idx = i; diff = pMin(i) - nowMin; found = true; break; }
            }
            if (!found) { idx = 0; diff = pMin(0) + 1440 - nowMin; }
            prevMin = pMin((idx + 4) % 5);
        }

        // adhan alert window after each prayer
        var app = getApp() as PrayerApp;
        var dayKey = today.day * 100 + today.month;
        if (dayKey != mAlertedDay) { mAlertedDay = dayKey; mDismissedPrayer = -1; }
        var win = app.isAdhanEnabled() ? app.getAdhanMinutes() : 0;
        var active = -1;
        if (win > 0 && mTimes != null) {
            for (var i = 0; i < 5; i++) {
                var ago = ((nowMin - pMin(i)) % 1440 + 1440) % 1440;
                if (ago < win) { active = i; break; }
            }
        }
        mActiveAlert = (active != mDismissedPrayer) ? active : -1;

        mNow = nowMin;
        mIdx = idx;
        mDiff = diff;
        mPrev = prevMin;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Design.ID comes from source/<face>/Design.mc: 0 ring, 1 list, 2 timeline, 3 analog
        if (Design.ID == 1) { drawList(dc, today, clock); }
        else if (Design.ID == 2) { drawTimeline(dc, today, clock); }
        else if (Design.ID == 3) { drawAnalog(dc, today, clock); }
        else { drawRing(dc, today, clock); }
    }

    // ===== shared pieces =====

    function drawDates(dc as Dc, today as Gregorian.Info, y1 as Number, y2 as Number) as Void {
        var cx = dc.getWidth() / 2;
        var dow = ((Time.now().value() + getTzMinutes() * 60) / 86400 + 4) % 7;
        text(dc, cx, y1, Graphics.FONT_XTINY,
             DAYS[dow] + "  " + today.day.format("%d") + " " + MONTHS[(today.month as Number) - 1],
             Graphics.COLOR_WHITE);
        text(dc, cx, y2, Graphics.FONT_XTINY, hijriText(dc, today, 140), Graphics.COLOR_GREEN);
    }

    // "13 JUMADA II 1448", without the year if wider than maxW
    function hijriText(dc as Dc, today as Gregorian.Info, maxW as Number) as String {
        var h = hijri(today.year, today.month as Number, today.day + (getApp() as PrayerApp).getHijriAdj());
        var s = h[2].format("%d") + " " + HMONTHS[h[1] - 1] + " " + h[0].format("%d");
        if (dc.getTextWidthInPixels(s, Graphics.FONT_XTINY) > maxW) {
            s = h[2].format("%d") + " " + HMONTHS[h[1] - 1];
        }
        return s;
    }

    // hours white, minutes green, square colon dots
    function drawClock(dc as Dc, clock as System.ClockTime, f, ty as Number, dotS as Number) as Void {
        var cx = dc.getWidth() / 2;
        var hh = clock.hour;
        if (!m24h) { hh = hh % 12; if (hh == 0) { hh = 12; } }
        var hs = digits(m24h ? hh.format("%02d") : hh.format("%d"));
        var ms = digits(clock.min.format("%02d"));
        var colonW = dotS * 2 + 4;
        f = clockFont(f);
        var hw = dc.getTextWidthInPixels(hs, f);
        var mw = dc.getTextWidthInPixels(ms, f);
        var x0 = cx - (hw + colonW + mw) / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, ty, f, hs, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.fillRectangle(x0 + hw + dotS - 1, ty - dotS * 2, dotS, dotS);
        dc.fillRectangle(x0 + hw + dotS - 1, ty + dotS, dotS, dotS);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + hw + colonW, ty, f, ms, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawBanner(dc as Dc, top as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(28, top, w - 56, 66, 10);
        prayerIcon(dc, mActiveAlert, cx, top + 13, Graphics.COLOR_DK_GREEN);
        text(dc, cx, top + 33, mArabic ? textFont() : Graphics.FONT_MEDIUM,
             mArabic ? ArabicText.NAMES[mActiveAlert] : LABEL[mActiveAlert], Graphics.COLOR_WHITE);
        text(dc, cx, top + 53, timeFont(), fmtMin(pMin(mActiveAlert)), Graphics.COLOR_YELLOW);
    }

    // ===== design A: 24h ring =====

    function drawRing(dc as Dc, today as Gregorian.Info, clock as System.ClockTime) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var idx = mIdx;

        // ---- 24h ring ----
        var r = cx - 5;
        // FR55 MIP has no real greys (DK_GRAY shows black), so the dial is drawn as hour ticks
        for (var h = 0; h < 24; h++) {
            dot(dc, cx, cy, r, h * 60, (h % 6 == 0) ? 2 : 1, Graphics.COLOR_WHITE);
        }
        if (mTimes != null) {
            if (mPrev != mNow) {
                dc.setPenWidth(5);
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, arcDeg(mPrev), arcDeg(mNow));
            }
            for (var i = 0; i < 5; i++) {
                if (i == idx) {
                    dot(dc, cx, cy, r, pMin(i), 5, Graphics.COLOR_YELLOW);
                } else {
                    dot(dc, cx, cy, r, pMin(i), 4, Graphics.COLOR_BLACK);
                    dot(dc, cx, cy, r, pMin(i), 3, Graphics.COLOR_GREEN);
                }
            }
        }
        dot(dc, cx, cy, r, mNow, 4, Graphics.COLOR_WHITE);
        dc.setPenWidth(1);

        drawDates(dc, today, 26, 41);
        drawClock(dc, clock, Graphics.FONT_NUMBER_MEDIUM, 74, 4);

        if (mTimes == null) { return; }

        // ---- adhan banner, or next prayer + grid ----
        if (mActiveAlert >= 0) {
            drawBanner(dc, 98);
        } else {
            var nameW = dc.getTextWidthInPixels(LABEL[idx], Graphics.FONT_SMALL);
            var timeS = fmtMin(pMin(idx));
            var timeW = dc.getTextWidthInPixels(timeS, mArabic ? timeFont() : Graphics.FONT_SMALL);
            var nx = cx - (nameW + 8 + timeW) / 2;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(nx, 109, Graphics.FONT_SMALL, LABEL[idx],
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(nx + nameW + 8, 109, mArabic ? timeFont() : Graphics.FONT_SMALL, timeS,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            text(dc, cx, 124, Graphics.FONT_XTINY, "in " + countdown(mDiff), Graphics.COLOR_YELLOW);

            drawPrayerGrid(dc, 142, 159);
        }

        drawStats(dc, 178);
    }

    function drawStats(dc as Dc, sy as Number) as Void {
        var cx = dc.getWidth() / 2;
        // ---- heart rate, steps, battery: icon + value each ----
        var info = Activity.getActivityInfo();
        var hr = (info != null && info.currentHeartRate != null) ? info.currentHeartRate as Number : 0;
        // outside an activity a watch face gets no live HR; use the latest all-day sample
        if (hr == 0 && (ActivityMonitor has :getHeartRateHistory)) {
            var hs = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (hs != null && hs.heartRate != null && hs.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hr = hs.heartRate as Number;
            }
        }
        var am = ActivityMonitor.getInfo();
        var steps = (am != null && am.steps != null) ? am.steps as Number : 0;
        var bat = System.getSystemStats().battery.toNumber();
        var hrS = hr > 0 ? hr.format("%d") : "--";
        var stS = steps.format("%d");
        var batS = bat.format("%d");  // no "%": the battery icon says it, and it kept hitting the dial
        var F = Graphics.FONT_XTINY;
        var gap = 5;
        var total = 9 + 2 + dc.getTextWidthInPixels(hrS, F) + gap
                  + 8 + 2 + dc.getTextWidthInPixels(stS, F) + gap
                  + 14 + 2 + dc.getTextWidthInPixels(batS, F);
        var sx = cx - total / 2;
        var J = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx + 2, sy - 1, 2);
        dc.fillCircle(sx + 6, sy - 1, 2);
        dc.fillPolygon([[sx, sy], [sx + 9, sy], [sx + 4, sy + 4]]);
        sx += 11;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, sy, F, hrS, J);
        sx += dc.getTextWidthInPixels(hrS, F) + gap;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(sx + 2, sy - 2, 2, 3);
        dc.fillEllipse(sx + 6, sy + 1, 2, 3);
        sx += 10;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, sy, F, stS, J);
        sx += dc.getTextWidthInPixels(stS, F) + gap;

        dc.drawRectangle(sx, sy - 3, 12, 7);
        dc.fillRectangle(sx + 12, sy - 1, 2, 3);
        dc.setColor(bat < 20 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx + 1, sy - 2, (10 * bat / 100).toNumber(), 5);
        sx += 16;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, sy, F, batS, J);
    }

    // ===== design B: list =====

    function drawList(dc as Dc, today as Gregorian.Info, clock as System.ClockTime) as Void {
        var cx = dc.getWidth() / 2;
        drawDates(dc, today, 28, 42);
        drawClock(dc, clock, Graphics.FONT_NUMBER_MEDIUM, 72, 4);
        if (mTimes == null) { return; }
        if (mActiveAlert >= 0) {
            drawBanner(dc, 98);
        } else {
            var F = Graphics.FONT_XTINY;
            for (var i = 0; i < 5; i++) {
                var y = 104 + i * 14;
                var next = (i == mIdx);
                var bg = Graphics.COLOR_BLACK;
                var fg = Graphics.COLOR_WHITE;
                if (next) {
                    bg = Graphics.COLOR_GREEN;
                    fg = Graphics.COLOR_BLACK;
                    dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(cx - 72, y - 7, 144, 14, 5);
                }
                prayerIcon(dc, i, cx - 64, y, bg);
                dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx - 54, y, F, LABEL[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(cx + 64, y, timeFont(), fmtMin(pMin(i)), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
        drawStats(dc, 180);
    }

    // Current prayer window as [start, end, isPrayer] in minutes (start may be negative,
    // end may pass 1440). Fajr ends at sunrise; sunrise..Dhuhr is not a prayer window.
    function prayerWindow(now as Number, p as Array<Number>, sunrise as Number) as Array<Number> {
        if (now < p[0]) { return [p[4] - 1440, p[0], 1] as Array<Number>; }
        if (now < sunrise) { return [p[0], sunrise, 1] as Array<Number>; }
        if (now < p[1]) { return [sunrise, p[1], 0] as Array<Number>; }
        for (var i = 1; i < 4; i++) {
            if (now < p[i + 1]) { return [p[i], p[i + 1], 1] as Array<Number>; }
        }
        return [p[4], p[0] + 1440, 1] as Array<Number>;
    }

    // Edge arc from 12 o'clock, clockwise, length = share of the current window still left.
    function drawRemainingDial(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = cx - 2;
        for (var k = 0; k < 12; k++) {
            dot(dc, cx, cy, r, k * 120, 1, Graphics.COLOR_WHITE);
        }
        var sunrise = Math.round(mTimes[1] as Float).toNumber();
        var win = prayerWindow(mNow, [pMin(0), pMin(1), pMin(2), pMin(3), pMin(4)] as Array<Number>, sunrise);
        var total = win[1] - win[0];
        var left = win[1] - mNow;
        if (total <= 0 || left <= 0) { return; }
        var colour = Graphics.COLOR_GREEN;
        if (win[2] == 0) { colour = Graphics.COLOR_WHITE; }
        else if (left <= 30) { colour = Graphics.COLOR_RED; }
        else if (left <= 60) { colour = Graphics.COLOR_YELLOW; }
        var deg = left * 360 / total;
        dc.setPenWidth(3);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        if (deg >= 359) {
            dc.drawCircle(cx, cy, r);
        } else if (deg >= 1) {
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, 90 - deg);
        }
        dc.setPenWidth(1);
    }

    // ===== design C: big clock + timeline stepper =====

    function drawTimeline(dc as Dc, today as Gregorian.Info, clock as System.ClockTime) as Void {
        var cx = dc.getWidth() / 2;
        drawDates(dc, today, 24, 38);
        drawClock(dc, clock, Graphics.FONT_NUMBER_HOT, 69, 5);
        if (mTimes == null) { return; }
        drawRemainingDial(dc);
        if (mActiveAlert >= 0) {
            drawBanner(dc, 104);
            drawStats(dc, 181);
            return;
        }

        // Next event: after Fajr count down to sunrise, then to Dhuha (sunrise + 20 min), then Dhuhr.
        var evt = LABEL[mIdx];
        var evtAr = ArabicText.NAMES[mIdx];
        var evtDiff = mDiff;
        var evtColour = Graphics.COLOR_GREEN;
        var sunrise = Math.round(mTimes[1] as Float).toNumber();
        if (mIdx == 1 && mNow >= pMin(0) && mNow < sunrise + DHUHA_AFTER_SUNRISE) {
            var sun = mNow < sunrise;
            evt = sun ? "SUNRISE" : "DHUHA";
            evtAr = sun ? ArabicText.SUNRISE : ArabicText.DHUHA;
            evtDiff = sun ? sunrise - mNow : sunrise + DHUHA_AFTER_SUNRISE - mNow;
            evtColour = Graphics.COLOR_ORANGE;
        }

        // "DHUHR in 2h 14m", or Arabic "<name> متبقي h:mm" laid out right-to-left
        var J = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        if (mArabic) {
            var F = textFont();
            // logical order; the watch lays the Arabic run out right-to-left, digits end up on the left
            var b = ArabicText.LEFT + " " + digits((evtDiff / 60).format("%d") + ":" + (evtDiff % 60).format("%02d"));
            var a = evtAr;
            var bw = dc.getTextWidthInPixels(b, F);
            var x0 = cx - (bw + 8 + dc.getTextWidthInPixels(a, F)) / 2;
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, 115, F, b, J);
            dc.setColor(evtColour, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + bw + 8, 115, F, a, J);
        } else {
            var F = Graphics.FONT_SMALL;
            var a = evt;
            var b = "  in " + countdown(evtDiff);
            var aw = dc.getTextWidthInPixels(a, F);
            var x0 = cx - (aw + dc.getTextWidthInPixels(b, F)) / 2;
            dc.setColor(evtColour, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0, 115, F, a, J);
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + aw, 115, F, b, J);
        }

        // stepper: five evenly spaced stations, green fill up to now
        var step = 34;
        var ly = 149;
        var x1 = cx - 2 * step;
        var x5 = cx + 2 * step;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x1, ly, x5, ly);
        var px = x1;
        if (mNow >= pMin(4)) {
            px = x5;
        } else if (mNow >= pMin(0)) {
            var p = (mIdx + 4) % 5;
            var span = pMin(mIdx) - pMin(p);
            px = x1 + p * step + (span > 0 ? step * (mNow - pMin(p)) / span : 0);
        }
        if (px > x1) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x1, ly - 1, px - x1, 3);
        }
        for (var i = 0; i < 5; i++) {
            var x = x1 + i * step;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, ly, 8);
            if (i == mIdx) {
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, ly, 8);
            }
            prayerIcon(dc, i, x, ly, Graphics.COLOR_BLACK);
            text(dc, x, (i % 2 == 0) ? 134 : 164, timeFont(), fmtMin(pMin(i)),
                 i == mIdx ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE);
        }
        drawStats(dc, 181);
    }

    // five prayers as [icon] 4:07 cells: three on row y1, two on row y2; next in yellow
    function drawPrayerGrid(dc as Dc, y1 as Number, y2 as Number) as Void {
        var cx = dc.getWidth() / 2;
        for (var i = 0; i < 5; i++) {
            var x = (i < 3) ? cx + (i - 1) * 56 : cx + (i == 3 ? -28 : 28);
            var y = (i < 3) ? y1 : y2;
            var ts = fmtMin(pMin(i));
            var tw = dc.getTextWidthInPixels(ts, timeFont());
            var lx = x - (12 + 3 + tw) / 2;
            prayerIcon(dc, i, lx + 6, y, Graphics.COLOR_BLACK);
            dc.setColor(i == mIdx ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx + 15, y, timeFont(), ts, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ===== design D: analog dress watch ("Prayer Classic") =====

    // point at `along` px from the centre in direction deg (clockwise from 12), shifted `across` px sideways
    function pol(cx as Number, cy as Number, deg as Float, along as Float, across as Float) as [Number, Number] {
        var a = Math.toRadians(deg);
        var s = Math.sin(a);
        var c = Math.cos(a);
        return [(cx + along * s + across * c).toNumber(), (cy - along * c + across * s).toNumber()];
    }

    // tapered (dauphine) hand with a black rim so it stays readable over text
    function drawHand(dc as Dc, deg as Float, len as Float, w as Float, colour as Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        for (var pass = 0; pass < 2; pass++) {
            var rim = (pass == 0) ? 2.0 : 0.0;
            dc.setColor(pass == 0 ? Graphics.COLOR_BLACK : colour, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([pol(cx, cy, deg, len + rim, 0.0), pol(cx, cy, deg, len * 0.22, w + rim),
                            pol(cx, cy, deg, -12.0 - rim, 0.0), pol(cx, cy, deg, len * 0.22, -w - rim)]);
        }
    }

    function drawAnalog(dc as Dc, today as Gregorian.Info, clock as System.ClockTime) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        // minute track and baton hour indices (double at 12, date window at 3)
        for (var m = 0; m < 60; m++) {
            if (m % 5 != 0) {
                var p = pol(cx, cy, m * 6.0, 96.0, 0.0);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p[0], p[1], 1);
            }
        }
        for (var h = 0; h < 12; h++) {
            if (h == 3) { continue; }
            var d = h * 30.0;
            var offs = (h == 0) ? [-4.0, 4.0] : [0.0];
            for (var k = 0; k < offs.size(); k++) {
                var o = offs[k] as Float;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([pol(cx, cy, d, 97.0, o - 2.0), pol(cx, cy, d, 97.0, o + 2.0),
                                pol(cx, cy, d, 84.0, o + 2.0), pol(cx, cy, d, 84.0, o - 2.0)]);
            }
        }

        if (mTimes != null) {
            // bezel: time left in the current prayer, laid on the 12h dial from "now" (max 12h)
            var sunrise = Math.round(mTimes[1] as Float).toNumber();
            var win = prayerWindow(mNow, [pMin(0), pMin(1), pMin(2), pMin(3), pMin(4)] as Array<Number>, sunrise);
            var left = win[1] - mNow;
            if (left > 719) { left = 719; }
            if (left > 0) {
                var colour = Graphics.COLOR_GREEN;
                if (win[2] == 0) { colour = Graphics.COLOR_WHITE; }
                else if (left <= 30) { colour = Graphics.COLOR_RED; }
                else if (left <= 60) { colour = Graphics.COLOR_YELLOW; }
                var startDeg = (mNow % 720) / 2;
                dc.setPenWidth(3);
                dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, cx - 2, Graphics.ARC_CLOCKWISE, 90 - startDeg, 90 - startDeg - left / 2);
                dc.setPenWidth(1);
            }
            // prayers due in the next 12 hours, at their place on the dial
            for (var i = 0; i < 5; i++) {
                var ahead = ((pMin(i) - mNow) % 1440 + 1440) % 1440;
                if (ahead < 720) {
                    var p = pol(cx, cy, (pMin(i) % 720) / 2.0, 96.0, 0.0);  // on the minute track
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(p[0], p[1], 5);
                    dc.setColor(i == mIdx ? Graphics.COLOR_YELLOW : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(p[0], p[1], i == mIdx ? 4 : 3);
                }
            }
        }

        // weekday at 9, date window at 3
        var dow = ((Time.now().value() + getTzMinutes() * 60) / 86400 + 4) % 7;
        text(dc, cx - 52, cy, Graphics.FONT_XTINY, DAYS[dow], Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(cx + 40, cy - 10, 28, 20);
        text(dc, cx + 54, cy, Graphics.FONT_XTINY, today.day.format("%d"), Graphics.COLOR_WHITE);

        if (mTimes != null) {
            if (mActiveAlert >= 0) {
                drawBanner(dc, 112);
            } else {
                // next prayer and countdown under 12
                var J = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
                if (mArabic) {
                    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, 52, textFont(), ArabicText.NAMES[mIdx] + " " + fmtMin(pMin(mIdx)), J);
                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, 70, textFont(),
                                ArabicText.LEFT + " " + digits((mDiff / 60).format("%d") + ":" + (mDiff % 60).format("%02d")), J);
                } else {
                    text(dc, cx, 52, Graphics.FONT_XTINY, LABEL[mIdx] + "  " + fmtMin(pMin(mIdx)), Graphics.COLOR_GREEN);
                    text(dc, cx, 67, Graphics.FONT_XTINY, "in " + countdown(mDiff), Graphics.COLOR_YELLOW);
                }
                drawPrayerGrid(dc, 124, 139);
            }
            text(dc, cx, 154, Graphics.FONT_XTINY, hijriText(dc, today, 110), Graphics.COLOR_GREEN);
        }
        drawStats(dc, 169);

        // hands last, with a centre cap
        var hourDeg = ((clock.hour % 12) * 60 + clock.min) / 2.0;
        drawHand(dc, hourDeg, 50.0, 5.0, Graphics.COLOR_WHITE);
        drawHand(dc, clock.min * 6.0, 82.0, 4.0, Graphics.COLOR_WHITE);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
    }
}
