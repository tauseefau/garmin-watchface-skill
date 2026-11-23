// On-watch settings menu. Choices are kept in Application.Storage (works for sideloaded faces).
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const ACCENTS = [Graphics.COLOR_GREEN, Graphics.COLOR_BLUE, Graphics.COLOR_YELLOW,
                 Graphics.COLOR_ORANGE, Graphics.COLOR_RED] as Array<Number>;
const ACCENT_NAMES = ["Green", "Blue", "Yellow", "Orange", "Red"] as Array<String>;

function accentIndex() as Number {
    var v = Application.Storage.getValue("accent");
    return (v instanceof Number && v >= 0 && v < ACCENTS.size()) ? v as Number : 0;
}

function settingsMenu() as WatchUi.Menu2 {
    var menu = new WatchUi.Menu2({:title => "Settings"});
    menu.addItem(new WatchUi.MenuItem("Accent colour", ACCENT_NAMES[accentIndex()], :accent, null));
    return menu;
}

class FaceSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // each press cycles to the next value and shows it as the sub-label
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :accent) {
            var i = (accentIndex() + 1) % ACCENTS.size();
            Application.Storage.setValue("accent", i);
            item.setSubLabel(ACCENT_NAMES[i]);
        }
        WatchUi.requestUpdate();
    }
}
