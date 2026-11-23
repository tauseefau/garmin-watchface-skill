import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new FaceView()];
    }

    // On-watch settings (hold UP > Watch Face > this face > Customize/Settings).
    // Settings from the Garmin Connect app do NOT reach sideloaded faces, so use this.
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [settingsMenu(), new FaceSettingsDelegate()];
    }
}

function getApp() as FaceApp {
    return Application.getApp() as FaceApp;
}
