import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Timer;

class GolfView extends WatchUi.View {

    private var _model as GolfModel;
    private var _gpsPollTimer as Timer.Timer?;
    private var _blinkTimer as Timer.Timer?;

    function initialize(model as GolfModel) {
        View.initialize();
        _model = model;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS,
            method(:onPosition));
        _gpsPollTimer = new Timer.Timer();
        _gpsPollTimer.start(method(:pollPosition), 2000, true);
    }

    function onHide() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        if (_gpsPollTimer != null) {
            _gpsPollTimer.stop();
            _gpsPollTimer = null;
        }
        stopBlink();
    }

    function pollPosition() as Void {
        var info = Position.getInfo();
        if (info.position != null) {
            _model.updatePosition(info);
            WatchUi.requestUpdate();
        }
    }

    function onPosition(info as Position.Info) as Void {
        _model.updatePosition(info);
        WatchUi.requestUpdate();
    }

    function startBlink() as Void {
        _model.blinkOn = true;
        _blinkTimer = new Timer.Timer();
        _blinkTimer.start(method(:onBlink), 400, true);
    }

    function stopBlink() as Void {
        if (_blinkTimer != null) {
            _blinkTimer.stop();
            _blinkTimer = null;
        }
        _model.blinkOn = true;
    }

    function onBlink() as Void {
        _model.blinkOn = !_model.blinkOn;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var mode = _model.uiMode;
        if (mode == :green) {
            drawGreenView(dc);
        } else if (mode == :scoreEntry) {
            drawScoreEntry(dc);
        } else if (mode == :light) {
            var idx = _model.lightIndex;
            if (idx == 0) {
                drawCardView(dc);
            } else if (idx == 1) {
                drawShotView(dc);
            } else if (idx == 2) {
                drawSettingsView(dc);
            } else {
                drawExitView(dc);
            }
        } else if (mode == :summary) {
            drawSummaryView(dc);
        }
    }

    // ── Green view ──────────────────────────────

    private function drawGreenView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.fillRectangle(0, 0, w, 52);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        // Line 1: hole number
        dc.drawText(cx, 6, Graphics.FONT_SMALL, "Hole " + _model.holeNumber(),
            Graphics.TEXT_JUSTIFY_CENTER);
        // Line 2: par and zero-padded SI — FONT_TINY balances FONT_SMALL above
        var si = _model.getStrokeIndex();
        var siStr = si < 10 ? "SI 0" + si : "SI " + si;
        dc.drawText(cx, 28, Graphics.FONT_TINY,
            "Par " + _model.getPar() + "   " + siStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var y1 = 64;
        var y2 = 102;
        var y3 = 140;

        if (!_model.gpsReady) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 56, Graphics.FONT_XTINY, "Acquiring GPS...",
                Graphics.TEXT_JUSTIFY_CENTER);
            var noGpsLabelW = (dc.getTextDimensions("B", Graphics.FONT_SMALL) as Array<Number>)[0];
            var noGpsDistW  = (dc.getTextDimensions("---", Graphics.FONT_MEDIUM) as Array<Number>)[0];
            var noGpsGap    = 8;
            var noGpsRowW   = noGpsLabelW + noGpsGap + noGpsDistW;
            var noGpsLx     = cx - noGpsRowW / 2 + noGpsLabelW;
            var noGpsDx     = noGpsLx + noGpsGap;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(noGpsLx, y1, Graphics.FONT_SMALL, "B", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(noGpsLx, y2, Graphics.FONT_SMALL, "M", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(noGpsLx, y3, Graphics.FONT_SMALL, "F", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(noGpsDx, y1, Graphics.FONT_MEDIUM, "---", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(noGpsDx, y2, Graphics.FONT_MEDIUM, "---", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(noGpsDx, y3, Graphics.FONT_MEDIUM, "---", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var front  = _model.distToFront();
            var middle = _model.distToMiddle();
            var back   = _model.distToBack();

            var labelW = (dc.getTextDimensions("M", Graphics.FONT_SMALL) as Array<Number>)[0];
            var distW  = (dc.getTextDimensions(fmtDist(middle), Graphics.FONT_MEDIUM) as Array<Number>)[0];
            var rowGap = 8;
            var rowW   = labelW + rowGap + distW;
            var lx     = cx - rowW / 2 + labelW;
            var dx     = lx + rowGap;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, y1, Graphics.FONT_SMALL, "B", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dx, y1, Graphics.FONT_MEDIUM, fmtDist(back), Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, y2, Graphics.FONT_SMALL, "M", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(dx, y2, Graphics.FONT_MEDIUM, fmtDist(middle), Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, y3, Graphics.FONT_SMALL, "F", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dx, y3, Graphics.FONT_MEDIUM, fmtDist(front), Graphics.TEXT_JUSTIFY_LEFT);
        }

        drawHints(dc, w, h, "START Score  BACK More");
    }

    // ── Score entry (START from green) ──────────

    private function drawScoreEntry(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_ORANGE);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 14, Graphics.FONT_SMALL,
            "H" + _model.holeNumber() + "  Par " + _model.getPar(),
            Graphics.TEXT_JUSTIFY_CENTER);

        var score = _model.scores[_model.currentHole] as Number;
        var par   = _model.getPar();
        var diff  = score - par;

        dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 52, Graphics.FONT_NUMBER_HOT, score.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 116, Graphics.FONT_SMALL, scoreLabel(score, par, diff),
            Graphics.TEXT_JUSTIFY_CENTER);

        drawHints(dc, w, h, "UP+ DN-  START Next");
    }

    // ── Scorecard with inline edit ──────────────

    private function drawCardView(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var editing = _model.editActive;

        dc.setColor(0x008080, 0x008080);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        if (editing) {
            var eh = _model.editHole;
            var es = _model.scores[eh] as Number;
            var ep = _model.getParForHole(eh);
            dc.drawText(cx, 6, Graphics.FONT_XTINY,
                "Editing H" + (eh + 1) + "  Par " + ep,
                Graphics.TEXT_JUSTIFY_CENTER);
            if (es > 0) {
                dc.setColor(scoreColor(es - ep), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, 20, Graphics.FONT_SMALL,
                    es + " " + scoreLabel(es, ep, es - ep),
                    Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, 20, Graphics.FONT_SMALL, "No score",
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.drawText(cx, 14, Graphics.FONT_SMALL, "Scorecard",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        var cellW = 22;
        var cellH = 18;
        var gap   = 2;
        var cols  = 9;
        var rowW  = cols * cellW + (cols - 1) * gap;
        var startX = (w - rowW) / 2;
        var row1Y  = 48;
        var row2Y  = row1Y + cellH + gap + 4;

        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var textYOff = (cellH - fh) / 2;

        for (var i = 0; i < 18; i++) {
            var col = i % 9;
            var row = i / 9;
            var x   = startX + col * (cellW + gap);
            var y   = row == 0 ? row1Y : row2Y;
            var score = _model.scores[i] as Number;
            var par   = _model.getParForHole(i);
            var diff  = score > 0 ? score - par : 0;

            // Text position: centered in cell
            var tx = x + cellW / 2;
            var ty = y + textYOff;

            // Shape center: derived from text center
            var shapeCx = tx;
            var shapeCy = ty + fh / 2;
            var r = fh / 2 + 2;

            var isEditCell = editing && i == _model.editHole;
            if (isEditCell && !_model.blinkOn) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRectangle(x, y, cellW, cellH);
                continue;
            }

            if (isEditCell) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRectangle(x, y, cellW, cellH);
            }

            if (score == 0) {
                var dotColor = isEditCell ? Graphics.COLOR_BLACK : 0x333333;
                dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(tx, ty, Graphics.FONT_XTINY, "-",
                    Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                if (diff <= -2) {
                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(shapeCx, shapeCy, r);
                    dc.drawCircle(shapeCx, shapeCy, r - 3);
                } else if (diff == -1) {
                    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(shapeCx, shapeCy, r);
                } else if (diff == 1) {
                    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(shapeCx - r, shapeCy - r, r * 2, r * 2);
                } else if (diff >= 2) {
                    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(shapeCx - r, shapeCy - r, r * 2, r * 2);
                    dc.drawRectangle(shapeCx - r + 2, shapeCy - r + 2, r * 2 - 4, r * 2 - 4);
                }

                var numColor = isEditCell ? Graphics.COLOR_BLACK : scoreColor(diff);
                dc.setColor(numColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(tx, ty, Graphics.FONT_XTINY, score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Totals — only count holes with scores entered
        var total = _model.totalStrokes();
        var vpar  = _model.scoreVsPar();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(30, h - 58, w - 30, h - 58);

        if (total > 0) {
            var vparStr = vpar > 0 ? "+" + vpar : vpar.toString();
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h - 54, Graphics.FONT_XTINY,
                total + " strokes  " + vparStr,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (editing) {
            drawHints(dc, w, h, "UP+ DN-  START Hole");
        } else {
            drawHints(dc, w, h, "START Edit  BACK Shot");
        }
    }

    // ── Shot tracker ────────────────────────────

    private function drawShotView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 14, Graphics.FONT_SMALL, "Shot Tracker",
            Graphics.TEXT_JUSTIFY_CENTER);

        if (!_model.gpsReady) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 10, Graphics.FONT_MEDIUM, "No GPS",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "BACK Close");
            return;
        }

        if (_model.shotMarked) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 30, Graphics.FONT_SMALL, "Walk to ball",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_XTINY, "then press START",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START Calc  BACK Next");
        } else if (_model.shotCalculated) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 50, Graphics.FONT_XTINY, "Last shot",
                Graphics.TEXT_JUSTIFY_CENTER);
            var shotNumStr;
            var shotUnit;
            if (_model.useMetres) {
                shotNumStr = (_model.lastShotDist * 0.9144d + 0.5d).toNumber().toString();
                shotUnit = "metres";
            } else {
                shotNumStr = _model.lastShotDist.toString();
                shotUnit = "yards";
            }
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 20, Graphics.FONT_NUMBER_MEDIUM,
                shotNumStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 30, Graphics.FONT_SMALL, shotUnit,
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START New  BACK Next");
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 30, Graphics.FONT_SMALL, "Press START",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, h / 2, Graphics.FONT_XTINY, "to mark position",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START Mark  BACK Next");
        }
    }

    // ── Summary ─────────────────────────────────

    private function drawSummaryView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_PURPLE);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 14, Graphics.FONT_SMALL, "Round Over",
            Graphics.TEXT_JUSTIFY_CENTER);

        var total = _model.totalStrokes();
        var par   = _model.totalPar();

        if (total == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 80, Graphics.FONT_SMALL, "No scores entered",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, 110, Graphics.FONT_XTINY, "Par " + par,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var diff = total - par;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 48, Graphics.FONT_XTINY, "Total strokes",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 64, Graphics.FONT_NUMBER_MEDIUM, total.toString(),
                Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 104, Graphics.FONT_XTINY, "Course par " + par,
                Graphics.TEXT_JUSTIFY_CENTER);

            var vsParStr = diff > 0 ? "+" + diff : diff.toString();
            dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 120, Graphics.FONT_NUMBER_MEDIUM, vsParStr,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawHints(dc, w, h, "DN or BACK to H18");
    }

    // ── Helpers ─────────────────────────────────

    private function fmtDist(d as Number) as String {
        if (_model.useMetres) {
            var m = (d * 0.9144d + 0.5d).toNumber();
            return m.toString() + "M";
        }
        return d.toString() + "Y";
    }

    private function drawHints(dc as Graphics.Dc, w as Number, h as Number, hint as String) as Void {
        if (!_model.showHints) { return; }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 42, Graphics.FONT_XTINY, hint,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSettingsView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 14, Graphics.FONT_SMALL, "Settings",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Row 0: Button hints
        var row0Selected = (_model.settingIndex == 0);
        dc.setColor(row0Selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 10, 60, Graphics.FONT_XTINY, "Button hints",
            Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(_model.showHints ? Graphics.COLOR_GREEN : Graphics.COLOR_RED,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 60, Graphics.FONT_XTINY,
            _model.showHints ? "  ON" : "  OFF", Graphics.TEXT_JUSTIFY_LEFT);
        if (row0Selected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 60, 60, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Row 1: Distance units
        var row1Selected = (_model.settingIndex == 1);
        dc.setColor(row1Selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 10, 90, Graphics.FONT_XTINY, "Distance",
            Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 90, Graphics.FONT_XTINY,
            _model.useMetres ? "  Metres" : "  Yards", Graphics.TEXT_JUSTIFY_LEFT);
        if (row1Selected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 60, 90, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_LEFT);
        }

        drawHints(dc, w, h, "UP/DN Select  START Toggle  BACK Green");
    }

    private function drawExitView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_DK_RED);
        dc.fillRectangle(0, 0, w, 42);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 14, Graphics.FONT_SMALL, "Exit App",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 20, Graphics.FONT_SMALL, "Press START",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 4, Graphics.FONT_XTINY, "to exit the app",
            Graphics.TEXT_JUSTIFY_CENTER);

        drawHints(dc, w, h, "START Exit  BACK Green");
    }

    private function scoreColor(diff as Number) as Number {
        if (diff <= -2) { return Graphics.COLOR_YELLOW; }
        if (diff == -1) { return Graphics.COLOR_GREEN; }
        if (diff ==  0) { return Graphics.COLOR_WHITE; }
        if (diff ==  1) { return Graphics.COLOR_ORANGE; }
        return Graphics.COLOR_RED;
    }

    private function scoreLabel(score as Number, par as Number, diff as Number) as String {
        if (score == 0) { return "--"; }
        if (diff <= -3) { return "Albatross!"; }
        if (diff == -2) { return "Eagle"; }
        if (diff == -1) { return "Birdie"; }
        if (diff ==  0) { return "Par"; }
        if (diff ==  1) { return "Bogey"; }
        if (diff ==  2) { return "Double"; }
        if (diff ==  3) { return "Triple"; }
        return "+" + diff;
    }
}
