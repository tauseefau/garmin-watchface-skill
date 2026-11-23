// On-watch settings menu (Watch face > Customize/Settings). Garmin Connect app settings
// do not reach sideloaded faces, so choices are kept in Application.Storage.
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

function hijriAdjLabel(adj as Number) as String {
    if (adj == 0) { return "No change"; }
    return (adj > 0 ? "+" : "") + adj.format("%d") + (adj == 1 || adj == -1 ? " day" : " days");
}

function asrAdjLabel(adj as Number) as String {
    if (adj == 0) { return "No change"; }
    return (adj > 0 ? "+" : "") + adj.format("%d") + " min";
}

function settingsMenu(hanafi as Boolean, arabic as Boolean, hijriAdj as Number, asrAdj as Number) as WatchUi.Menu2 {
    var menu = new WatchUi.Menu2({:title => "Prayer"});
    menu.addItem(new WatchUi.ToggleMenuItem("Asr method", {:enabled => "Hanafi", :disabled => "Shafi'i"},
                                            :asr, hanafi, null));
    // shift Asr to match a mosque timetable: each press steps 0, +5 .. +20, -10, -5, 0 ...
    menu.addItem(new WatchUi.MenuItem("Asr adjust", asrAdjLabel(asrAdj), :asrAdj, null));
    menu.addItem(new WatchUi.ToggleMenuItem("Arabic", {:enabled => "On", :disabled => "Off"},
                                            :arabic, arabic, null));
    // local moon sighting: each press steps 0, +1, +2, -2, -1, 0 ...
    menu.addItem(new WatchUi.MenuItem("Hijri date", hijriAdjLabel(hijriAdj), :hijri, null));
    return menu;
}

class PrayerDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :hijri) {
            var adj = getApp().getHijriAdj() + 1;
            if (adj > 2) { adj = -2; }
            Application.Storage.setValue("hijriAdj", adj);
            item.setSubLabel(hijriAdjLabel(adj));
            getApp().onSettingsChanged();
            return;
        }
        if (item.getId() == :asrAdj) {
            var adj = getApp().getAsrAdj() + 5;
            if (adj > 20) { adj = -10; }
            Application.Storage.setValue("asrAdj", adj);
            item.setSubLabel(asrAdjLabel(adj));
            getApp().onSettingsChanged();
            return;
        }
        var on = (item as WatchUi.ToggleMenuItem).isEnabled();
        if (item.getId() == :asr) {
            Application.Storage.setValue("asr", on ? 2 : 1);
        } else if (item.getId() == :arabic) {
            Application.Storage.setValue("arabic", on);
        }
        getApp().onSettingsChanged();
    }
}
