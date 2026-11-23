// Prayer time calculation using solar geometry.
// Based on the standard algorithm used by praytimes.org / IslamicFinder.
// All returned times are "minutes from local midnight".

import Toybox.Lang;
import Toybox.Math;

module PrayerCalc {

    const NAMES = ["FAJR", "SUNRISE", "DHUHR", "ASR", "MAGHRIB", "ISHA"] as Array<String>;

    function deg2rad(d as Float) as Float {
        return d * Math.PI / 180.0;
    }

    function rad2deg(r as Float) as Float {
        return r * 180.0 / Math.PI;
    }

    // modulo that stays positive
    function mod(a as Float, n as Float) as Float {
        var r = a - Math.floor(a / n) * n;
        if (r < 0.0) { r += n; }
        return r;
    }

    function julianDay(y as Number, m as Number, d as Number) as Float {
        var yy = y;
        var mm = m;
        if (mm <= 2) { yy = yy - 1; mm = mm + 12; }
        var a = Math.floor(yy / 100.0);
        var b = 2.0 - a + Math.floor(a / 4.0);
        return Math.floor(365.25 * (yy + 4716)) + Math.floor(30.6001 * (mm + 1)) + d + b - 1524.5;
    }

    // Minutes from solar noon at which the sun reaches the given altitude.
    // angle is negative for "below horizon". Returns null in polar day/night.
    function hourAngle(angleDeg as Float, lat as Float, dec as Float) as Float? {
        var latR = deg2rad(lat);
        var decR = deg2rad(dec);
        var angR = deg2rad(angleDeg);
        var cosH = (Math.sin(angR) - Math.sin(latR) * Math.sin(decR)) /
                   (Math.cos(latR) * Math.cos(decR));
        if (cosH > 1.0 || cosH < -1.0) { return null; }
        if (cosH > 1.0) { cosH = 1.0; }
        if (cosH < -1.0) { cosH = -1.0; }
        return rad2deg(Math.acos(cosH)) * 4.0; // 15 deg/hour => 4 minutes per degree
    }

    function normalize(minutes as Float) as Float {
        var m = mod(minutes, 1440.0);
        return m;
    }

    // Returns [fajr, sunrise, dhuhr, asr, maghrib, isha] as minutes from midnight.
    function calculate(year as Number, month as Number, day as Number,
                       lat as Float, lng as Float, tzHours as Float,
                       method as Number, asrFactor as Float) as Array? {

        var jd = julianDay(year, month, day);
        var d = jd - 2451545.0;

        // Solar mean longitude and anomaly
        var meanLong = mod(280.460 + 0.9856474 * d, 360.0);
        var meanAnom = deg2rad(mod(357.528 + 0.9856003 * d, 360.0));

        // Ecliptic longitude
        var lambda = deg2rad(meanLong + 1.915 * Math.sin(meanAnom) + 0.020 * Math.sin(2.0 * meanAnom));

        var obliquity = deg2rad(23.439);
        var ra = rad2deg(Math.atan2(Math.cos(obliquity) * Math.sin(lambda), Math.cos(lambda)));
        if (ra < 0.0) { ra += 360.0; }

        var dec = rad2deg(Math.asin(Math.sin(obliquity) * Math.sin(lambda)));

        // Equation of time (minutes)
        var eqTime = 4.0 * (meanLong - ra);
        if (eqTime > 720.0) { eqTime -= 1440.0; }
        if (eqTime < -720.0) { eqTime += 1440.0; }

        // Solar noon, expressed in local clock minutes
        var noonUtc = 720.0 - 4.0 * lng - eqTime;
        var noon = noonUtc + 60.0 * tzHours;

        // Fajr / Isha angles by calculation method
        var fajrAngle = -18.0;
        var ishaAngle = -17.0;
        if (method == 1) { fajrAngle = -15.0; ishaAngle = -15.0; }       // ISNA
        else if (method == 2) { fajrAngle = -19.5; ishaAngle = -17.5; }   // Egyptian
        else if (method == 3) { fajrAngle = -18.5; ishaAngle = -90.0; }   // Umm al-Qura (special)
        else if (method == 4) { fajrAngle = -18.0; ishaAngle = -18.0; }   // Karachi
        else if (method == 5) { fajrAngle = -17.7; ishaAngle = -14.0; }   // Tehran
        else if (method == 6) { fajrAngle = -16.0; ishaAngle = -14.0; }   // Jafari

        // Asr angle derived from the shadow-length factor
        var diff = lat - dec;
        if (diff < 0.0) { diff = -diff; }
        var shadow = asrFactor + Math.tan(deg2rad(diff));
        // Asr: sun is ABOVE the horizon at altitude arccot(factor + tan|lat - dec|)
        var asrAngle = rad2deg(Math.atan(1.0 / shadow));

        var sunriseOff = hourAngle(-0.833, lat, dec);
        var fajrOff = hourAngle(fajrAngle, lat, dec);
        var asrOff = hourAngle(asrAngle, lat, dec);
        var ishaOff = hourAngle(ishaAngle, lat, dec);

        var sunriseOffMinutes = 360.0;
        if (sunriseOff != null) { sunriseOffMinutes = sunriseOff as Float; }
        var sunrise = noon - sunriseOffMinutes;
        var maghrib = noon + sunriseOffMinutes;
        var dhuhr = noon;

        var fajrOffMinutes = 540.0;
        if (fajrOff != null) { fajrOffMinutes = fajrOff as Float; }
        var fajr = noon - fajrOffMinutes;
        if (fajrOff == null) { fajr = sunrise - 540.0; } // middle-of-night fallback

        var asrOffMinutes = 240.0;
        if (asrOff != null) { asrOffMinutes = asrOff as Float; }
        var asr = noon + asrOffMinutes;

        var isha = 0.0;
        if (method == 3) {
            isha = maghrib + 90.0; // Umm al-Qura: 90 min after Maghrib
        } else if (ishaOff == null) {
            isha = maghrib + 540.0;
        } else {
            isha = noon + (ishaOff as Float);
        }

        return [normalize(fajr), normalize(sunrise), normalize(dhuhr),
                normalize(asr), normalize(maghrib), normalize(isha)];
    }
}
