import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class AthenryGolfApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        var model = new GolfModel();
        var view = new GolfView(model);
        var delegate = new GolfDelegate(model, view);
        return [view, delegate];
    }
}

function getApp() as AthenryGolfApp {
    return Application.getApp() as AthenryGolfApp;
}
