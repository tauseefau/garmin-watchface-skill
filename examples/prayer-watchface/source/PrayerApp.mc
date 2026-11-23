import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class PrayerApp extends Application.AppBase {

    hidden var mView as PrayerView?;
    hidden var mLat as Float = -37.8136;
    hidden var mLng as Float = 144.9631;
    hidden var mMethod as Number = 0;
    hidden var mAsrFactor as Float = 1.0;
    hidden var mAdhanEnabled as Boolean = true;
    hidden var mAdhanMinutes as Number = 5;
    hidden var mArabic as Boolean = false;
    hidden var mHijriAdj as Number = 0;
    hidden var mAsrAdj as Number = 0;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        loadSettings();
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Watch faces on the Forerunner 55 cannot use an InputDelegate - doing so
    // causes an "Unexpected Type Error" at startup. Page 0 of the view already
    // shows the next prayer plus all five times, so no tap handling is needed.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new PrayerView();
        return [mView];
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [settingsMenu(mAsrFactor == 2.0, mArabic, mHijriAdj, mAsrAdj), new PrayerDelegate()];
    }

    function onSettingsChanged() as Void {
        loadSettings();
        if (mView != null) {
            mView.recalculate();
        }
        WatchUi.requestUpdate();
    }

    // Settings are unavailable for sideloaded apps, and the properties API
    // can throw when the settings store is missing. Keep the defaults in that
    // case so the watch face still runs.
    function loadSettings() as Void {
        try {
            var latStr = Application.Properties.getValue("Latitude") as String;
            var lngStr = Application.Properties.getValue("Longitude") as String;
            if (latStr != null) {
                var v = latStr.toFloat();
                if (v != null) { mLat = v as Float; }
            }
            if (lngStr != null) {
                var v = lngStr.toFloat();
                if (v != null) { mLng = v as Float; }
            }

            var method = Application.Properties.getValue("Method");
            if (method instanceof Number) { mMethod = method as Number; }

            var asr = Application.Properties.getValue("AsrFactor");
            if (asr instanceof Number) { mAsrFactor = (asr as Number).toFloat(); }

            var adhan = Application.Properties.getValue("AdhanEnabled");
            if (adhan instanceof Boolean) { mAdhanEnabled = adhan as Boolean; }

            var minutes = Application.Properties.getValue("AdhanMinutes");
            if (minutes instanceof Number) {
                mAdhanMinutes = minutes as Number;
                if (mAdhanMinutes < 1) { mAdhanMinutes = 1; }
                if (mAdhanMinutes > 15) { mAdhanMinutes = 15; }
            }
        } catch (ex) {
            // Use defaults - sideloaded apps have no settings store.
        }

        // Last GPS position the face picked up (see PrayerView.checkLocation) beats the default.
        var loc = Application.Storage.getValue("loc");
        if (loc instanceof Array && (loc as Array).size() == 2) {
            mLat = ((loc as Array)[0] as Float).toFloat();
            mLng = ((loc as Array)[1] as Float).toFloat();
        }

        // On-watch menu choices (Storage) override the Connect app properties.
        var asrS = Application.Storage.getValue("asr");
        if (asrS instanceof Number) { mAsrFactor = (asrS as Number).toFloat(); }
        var arS = Application.Storage.getValue("arabic");
        if (arS instanceof Boolean) { mArabic = arS as Boolean; }
        var hjS = Application.Storage.getValue("hijriAdj");
        if (hjS instanceof Number) { mHijriAdj = hjS as Number; }
        var aaS = Application.Storage.getValue("asrAdj");
        if (aaS instanceof Number) { mAsrAdj = aaS as Number; }
    }

    function setLocation(lat as Float, lng as Float) as Void {
        mLat = lat;
        mLng = lng;
        Application.Storage.setValue("loc", [lat, lng]);
    }

    function getLat() as Float { return mLat; }
    function getLng() as Float { return mLng; }
    function getMethod() as Number { return mMethod; }
    function getAsrFactor() as Float { return mAsrFactor; }
    function isAdhanEnabled() as Boolean { return mAdhanEnabled; }
    function getAdhanMinutes() as Number { return mAdhanMinutes; }
    function isArabic() as Boolean { return mArabic; }
    function getHijriAdj() as Number { return mHijriAdj; }
    function getAsrAdj() as Number { return mAsrAdj; }
    function getView() as PrayerView? { return mView; }
}

function getApp() as PrayerApp {
    return Application.getApp() as PrayerApp;
}
