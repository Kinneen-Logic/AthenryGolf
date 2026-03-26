import Toybox.WatchUi;
import Toybox.Lang;

// Forerunner 245 — 4-button scheme
// BACK cycles: Green → Scorecard → Shot Tracker → Settings → Exit → Green
//
// GREEN:             UP next hole, DN prev, START score, BACK scorecard
// SCORE ENTRY:       UP +1, DN -1, START save & next, BACK cancel
// SCORECARD browse:  UP/DN move cursor, START enter edit, BACK → shot
// SCORECARD edit:    UP/DN adjust score, START confirm, BACK cancel
// SHOT TRACKER:      START mark/calc, BACK → settings
// SETTINGS:          UP/DN toggle options, START toggle, BACK → exit screen
// EXIT SCREEN:       START exits app, BACK → green
// SUMMARY:           DN/BACK → H18

class GolfDelegate extends WatchUi.BehaviorDelegate {

    private var _model as GolfModel;
    private var _view  as GolfView;

    function initialize(model as GolfModel, view as GolfView) {
        BehaviorDelegate.initialize();
        _model = model;
        _view  = view;
    }

    function onPreviousPage() as Boolean {
        var mode = _model.uiMode;
        if (mode == :green) {
            _model.nextHole();
        } else if (mode == :scoreEntry) {
            _model.adjustScore(1);
        } else if (mode == :light && _model.lightIndex == 0) {
            if (_model.editActive) {
                _model.adjustScoreForHole(_model.editHole, 1);
            } else {
                _model.editHole = (_model.editHole + 1) % 18; // browse next
            }
        } else if (mode == :light && _model.lightIndex == 2) {
            _model.settingIndex = (_model.settingIndex + 1) % 2;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        var mode = _model.uiMode;
        if (mode == :green) {
            _model.prevHole();
        } else if (mode == :scoreEntry) {
            _model.adjustScore(-1);
        } else if (mode == :light && _model.lightIndex == 0) {
            if (_model.editActive) {
                _model.adjustScoreForHole(_model.editHole, -1);
            } else {
                _model.editHole = (_model.editHole + 17) % 18; // browse prev
            }
        } else if (mode == :light && _model.lightIndex == 2) {
            _model.settingIndex = (_model.settingIndex + 1) % 2;
        } else if (mode == :summary) {
            _model.prevHole();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        var mode = _model.uiMode;
        if (mode == :green) {
            if ((_model.scores[_model.currentHole] as Number) == 0) {
                _model.scores[_model.currentHole] = _model.getPar();
            }
            _model.uiMode = :scoreEntry;
        } else if (mode == :scoreEntry) {
            _model.nextHole();
        } else if (mode == :light && _model.lightIndex == 0) {
            if (_model.editActive) {
                // Confirm edit — return to browsing on same hole
                _model.editActive = false;
                _view.stopBlink();
            } else {
                // Enter edit for the cursor hole
                if ((_model.scores[_model.editHole] as Number) == 0) {
                    _model.scores[_model.editHole] = _model.getParForHole(_model.editHole);
                }
                _model.editActive = true;
                _view.startBlink();
            }
        } else if (mode == :light && _model.lightIndex == 1) {
            if (_model.shotMarked) {
                _model.calculateShotDist();
            } else {
                    _model.markShot();
            }
        } else if (mode == :light && _model.lightIndex == 2) {
            // START toggles the selected setting
            if (_model.settingIndex == 0) {
                _model.showHints = !_model.showHints;
            } else {
                _model.useMetres = !_model.useMetres;
            }
        } else if (mode == :light && _model.lightIndex == 3) {
            // START on exit screen — exit the app
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        } else if (mode == :summary) {
            _model.uiMode = :green;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        var mode = _model.uiMode;

        if (mode == :green) {
            // Enter the secondary menu — cursor starts on current hole
            _model.lightIndex = 0;
            _model.editActive = false;
            _model.editHole   = _model.currentHole;
            _model.uiMode = :light;
            WatchUi.requestUpdate();
            return true;
        }

        if (mode == :light) {
            if (_model.lightIndex == 0 && _model.editActive) {
                // Cancel scorecard edit
                _model.editActive = false;
                _view.stopBlink();
                WatchUi.requestUpdate();
                return true;
            }
            if (_model.lightIndex < _model.LIGHT_COUNT - 1) {
                // Advance through submenus
                _model.lightIndex = _model.lightIndex + 1;
                WatchUi.requestUpdate();
                return true;
            } else {
                // Exit screen — wrap back to green
                _model.uiMode = :green;
                WatchUi.requestUpdate();
                return true;
            }
        }

        if (mode == :scoreEntry) {
            _model.uiMode = :green;
            WatchUi.requestUpdate();
            return true;
        }

        if (mode == :summary) {
            _model.prevHole();
            WatchUi.requestUpdate();
            return true;
        }

        return false;
    }
}
