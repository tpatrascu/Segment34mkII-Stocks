import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class Segment34App extends Application.AppBase {
    
    var mView;
    
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() {
        mView = new Segment34View();
        var delegate = new Segment34Delegate(mView);
        scheduleStonksUpdate(isStonksCacheStale());
        return [mView, delegate];
    }

    function getServiceDelegate() {
        return [new StonksServiceDelegate()];
    }

    // The cache is never deleted: a failed or skipped update (market closed, no network) keeps the previous values
    function onBackgroundData(data as Application.PropertyValueType) as Void {
        if(data instanceof Array and data.size() == StonksData.CACHE_SIZE) {
            var previous = Application.Storage.getValue(StonksData.CACHE_KEY);
            if(data[StonksData.C_PL] == null and previous instanceof Array and previous.size() == StonksData.CACHE_SIZE) {
                data[StonksData.C_PL] = previous[StonksData.C_PL];
                data[StonksData.C_PL_PCT] = previous[StonksData.C_PL_PCT];
            }
            Application.Storage.setValue(StonksData.CACHE_KEY, data);
            if(mView != null) { mView.onStonksData(data); }
        }
        scheduleStonksUpdate(false);
    }

    function onSettingsChanged() as Void {
        mView.onSettingsChanged();
        scheduleStonksUpdate(true);
        WatchUi.requestUpdate();
    }

    hidden function isStonksCacheStale() as Boolean {
        var cache = Application.Storage.getValue(StonksData.CACHE_KEY);
        if(!(cache instanceof Array) or cache.size() != StonksData.CACHE_SIZE) { return true; }
        var ttl = Application.Properties.getValue("stonksTtl") as Number;
        return Time.now().value() - (cache[StonksData.C_TIME] as Number) >= ttl * 60;
    }

    // The background service runs every TTL minutes (5 minute minimum), it checks if the market is open itself.
    // updateNow schedules a single run as soon as allowed, the regular interval is restored after its data arrives.
    hidden function scheduleStonksUpdate(updateNow as Boolean) as Void {
        var p = Application.Properties;
        if((p.getValue("t212ClientId") as String).length() == 0 or (p.getValue("t212SecretKey") as String).length() == 0) {
            Background.deleteTemporalEvent();
            return;
        }

        if(updateNow) {
            var last = Background.getLastTemporalEventTime();
            Background.registerForTemporalEvent((last == null) ? Time.now() : last.add(new Time.Duration(5 * 60)));
            return;
        }

        var interval = (p.getValue("stonksTtl") as Number) * 60;
        var registered = Background.getTemporalEventRegisteredTime();
        if(registered instanceof Time.Duration and registered.value() == interval) { return; }
        Background.registerForTemporalEvent(new Time.Duration(interval));
    }

}

function getApp() as Segment34App {
    return Application.getApp() as Segment34App;
}
