import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

class GolfView extends WatchUi.View {

    private var _model as GolfModel;
    private var _gpsPollTimer as Timer.Timer?;
    private var _gpsAnimTimer as Timer.Timer?;
    private var _blinkTimer as Timer.Timer?;
    private var _idleTimer as Timer.Timer?;

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
        _gpsAnimTimer = new Timer.Timer();
        _gpsAnimTimer.start(method(:onGpsAnim), 400, true);
    }

    function onHide() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        if (_gpsPollTimer != null) {
            _gpsPollTimer.stop();
            _gpsPollTimer = null;
        }
        if (_gpsAnimTimer != null) {
            _gpsAnimTimer.stop();
            _gpsAnimTimer = null;
        }
        if (_idleTimer != null) {
            _idleTimer.stop();
            _idleTimer = null;
        }
        stopBlink();
    }

    function onGpsAnim() as Void {
        if (!_model.gpsReady) {
            WatchUi.requestUpdate();
        }
    }

    function pollPosition() as Void {
        var info = Position.getInfo();
        if (info.position != null) {
            _model.updatePosition(info);
        }
        WatchUi.requestUpdate();
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

    // Restart the 15-second idle timer; only arms when not on green view.
    function resetIdleTimer() as Void {
        if (_idleTimer != null) {
            _idleTimer.stop();
        }
        if (_model.uiMode != :green) {
            _idleTimer = new Timer.Timer();
            _idleTimer.start(method(:onIdleTimeout), 15000, false);
        }
    }

    function onIdleTimeout() as Void {
        if (_model.uiMode != :green) {
            _model.editActive = false;
            stopBlink();
            _model.uiMode = :green;
            WatchUi.requestUpdate();
        }
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

        // ── Header band ─────────────────────────
        var fhSmall = dc.getFontHeight(Graphics.FONT_SMALL);
        var fhTiny  = dc.getFontHeight(Graphics.FONT_TINY);
        var headerH = fhSmall + fhTiny + 12;

        dc.setColor(0x009A44, 0x009A44);
        dc.fillRectangle(0, 0, w, headerH);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        var line1Y = (headerH - fhSmall - fhTiny - 4) / 2;
        dc.drawText(cx, line1Y, Graphics.FONT_SMALL,
            "Hole " + _model.holeNumber(),
            Graphics.TEXT_JUSTIFY_CENTER);
        var si = _model.getStrokeIndex();
        var siStr = si < 10 ? "SI 0" + si : "SI " + si;
        var yd = _model.getYardage();
        var ydStr = _model.useMetres
            ? ((yd * 0.9144d + 0.5d).toNumber().toString() + "M")
            : (yd.toString() + "Y");
        dc.drawText(cx, line1Y + fhSmall + 4, Graphics.FONT_TINY,
            "Par " + _model.getPar() + "  " + ydStr + "  " + siStr,
            Graphics.TEXT_JUSTIFY_CENTER);

        var hintsTop = h - 44;

        if (!_model.gpsReady) {
            var phase   = ((System.getTimer() / 400) % 3).toNumber();
            var dots    = phase == 0 ? "." : (phase == 1 ? ".." : "...");
            var animY   = headerH + (hintsTop - headerH - fhSmall) / 2;
            var labelW  = (dc.getTextDimensions("Acquiring GPS", Graphics.FONT_SMALL) as Array<Number>)[0];
            var maxDotW = (dc.getTextDimensions("...", Graphics.FONT_SMALL) as Array<Number>)[0];
            var pivot   = cx - (labelW + maxDotW) / 2 + labelW;
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pivot, animY, Graphics.FONT_SMALL, "Acquiring GPS",
                Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(pivot, animY, Graphics.FONT_SMALL, dots,
                Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var front = _model.distToFrontApi();
            var mid   = _model.distToMiddleApi();
            var back  = _model.distToBackApi();

            // Bare numbers — unit is already in the header
            var frontStr = fmtDistNum(front);
            var midStr   = fmtDistNum(mid);
            var backStr  = fmtDistNum(back);

            var fontBF    = Graphics.FONT_MEDIUM;
            var fontM     = Graphics.FONT_NUMBER_MEDIUM;
            var fontLabel = Graphics.FONT_TINY;

            var fhBF    = dc.getFontHeight(fontBF);
            var fhM     = dc.getFontHeight(fontM);
            var fhLabel = dc.getFontHeight(fontLabel);

            var gap    = 4;
            var blockH = fhBF + fhM + fhBF + gap * 2;
            var topY   = headerH + (hintsTop - headerH - blockH) / 2;

            var lblGap = 6;

            // Score badge below header
            var holeScore = _model.scores[_model.currentHole] as Number;
            if (holeScore > 0) {
                var par  = _model.getPar();
                var diff = holeScore - par;
                dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, headerH + 2, Graphics.FONT_XTINY,
                    "[" + holeScore + "]",
                    Graphics.TEXT_JUSTIFY_CENTER);
            }

            // B row — centered at cx
            var backW     = (dc.getTextDimensions(backStr, fontBF) as Array<Number>)[0];
            var bDistLeft = cx - backW / 2;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bDistLeft - lblGap, topY + (fhBF - fhLabel) / 2,
                fontLabel, "B", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, topY, fontBF, backStr,
                Graphics.TEXT_JUSTIFY_CENTER);

            // M row — big number, centered at cx
            var midY    = topY + fhBF + gap;
            var midW    = (dc.getTextDimensions(midStr, fontM) as Array<Number>)[0];
            var midLeft = cx - midW / 2;
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(midLeft - lblGap, midY + (fhM - fhLabel) / 2,
                fontLabel, "M", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawText(cx, midY, fontM, midStr,
                Graphics.TEXT_JUSTIFY_CENTER);

            // F row — centered at cx
            var frontY    = midY + fhM + gap;
            var frontW    = (dc.getTextDimensions(frontStr, fontBF) as Array<Number>)[0];
            var fDistLeft = cx - frontW / 2;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(fDistLeft - lblGap, frontY + (fhBF - fhLabel) / 2,
                fontLabel, "F", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, frontY, fontBF, frontStr,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawHints(dc, w, h, "START Score", "BACK More");
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

        drawHints(dc, w, h, "UP+ DN-", "START Next");
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

        // Header always shows the cursor hole — "Editing" prefix only when in edit mode
        var eh = _model.editHole;
        var es = _model.scores[eh] as Number;
        var ep = _model.getParForHole(eh);
        dc.drawText(cx, 6, Graphics.FONT_XTINY, "H" + (eh + 1) + "  Par " + ep,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Grid: 3 rows × 6 holes
        var cellW  = 30;
        var cellH  = 22;
        var colGap = 4;
        var rowGap = 6;
        var cols   = 6;
        var rowW   = cols * cellW + (cols - 1) * colGap;
        var startX = (w - rowW) / 2;
        var row1Y  = 50;
        var row2Y  = row1Y + cellH + rowGap;
        var row3Y  = row2Y + cellH + rowGap;

        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var textYOff = (cellH - fh) / 2;

        for (var i = 0; i < 18; i++) {
            var col = i % cols;
            var row = i / cols;
            var x   = startX + col * (cellW + colGap);
            var y   = row == 0 ? row1Y : (row == 1 ? row2Y : row3Y);
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

            var isCursor  = (i == _model.editHole);
            var isEditCell = editing && isCursor;

            if (isCursor && !editing && score == 0) {
                // Browsing an unscored hole — show underscore placeholder only
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(tx, ty, Graphics.FONT_XTINY, "_",
                    Graphics.TEXT_JUSTIFY_CENTER);
                continue;
            }
            if (isCursor && !editing) {
                // Browsing a scored hole — dim border shows cursor position
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(x, y, cellW, cellH);
            }
            if (isEditCell && !_model.blinkOn) {
                continue;  // blink-off: hide number+shape to make it flash
            }

            if (score == 0) {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
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

                dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
                dc.drawText(tx, ty, Graphics.FONT_XTINY, score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Totals — exclude the hole currently being edited so numbers
        // only move when a score is committed, not during live adjustment.
        var total    = 0;
        var vpar     = 0;
        var outScore = 0;
        var inScore  = 0;
        for (var i = 0; i < 18; i++) {
            if (editing && i == _model.editHole) { continue; }
            var s = _model.scores[i] as Number;
            if (s > 0) {
                var p = _model.getParForHole(i);
                total += s;
                vpar  += s - p;
                if (i < 9) { outScore += s; } else { inScore += s; }
            }
        }

        var divY = row3Y + cellH + 6;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(40, divY, w - 40, divY);

        if (total > 0) {
            var vparStr   = vpar > 0 ? "(+" + vpar + ")" : "(" + vpar.toString() + ")";
            var vparColor = vpar < 0 ? Graphics.COLOR_GREEN
                                     : (vpar > 0 ? Graphics.COLOR_RED
                                                 : Graphics.COLOR_WHITE);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 2, divY + 6, Graphics.FONT_TINY,
                total + " strokes ",
                Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(vparColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 2, divY + 6, Graphics.FONT_TINY,
                vparStr,
                Graphics.TEXT_JUSTIFY_LEFT);

            var outDone = _model.front9Complete();
            var inDone  = _model.back9Complete();
            if (outDone || inDone) {
                var outStr = outDone ? "Out " + outScore : "";
                var inStr  = inDone  ? "In "  + inScore  : "";
                var sep    = (outDone && inDone) ? "   " : "";
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, divY + 28, Graphics.FONT_XTINY,
                    outStr + sep + inStr,
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (editing) {
            drawHints(dc, w, h, "UP+ DN-", "START Done");
        } else {
            drawHints(dc, w, h, "UP/DN Hole  START Edit", "BACK Shot");
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
            drawHints(dc, w, h, "BACK Close", "");
            return;
        }

        if (_model.shotMarked) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 30, Graphics.FONT_SMALL, "Walk to ball",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_XTINY, "then press START",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START Calc", "BACK Next");
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
            drawHints(dc, w, h, "START New", "BACK Next");
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 30, Graphics.FONT_SMALL, "Press START",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, h / 2, Graphics.FONT_XTINY, "to mark position",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START Mark", "BACK Next");
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

        drawHints(dc, w, h, "DN or BACK to H18", "");
    }

    // ── Helpers ─────────────────────────────────

    private function fmtDist(d as Number) as String {
        if (_model.useMetres) {
            var m = (d * 0.9144d + 0.5d).toNumber();
            return m.toString() + "M";
        }
        return d.toString() + "Y";
    }

    private function fmtDistNum(d as Number) as String {
        if (_model.useMetres) {
            return (d * 0.9144d + 0.5d).toNumber().toString();
        }
        return d.toString();
    }

    private function drawHints(dc as Graphics.Dc, w as Number, h as Number, line1 as String, line2 as String) as Void {
        if (!_model.showHints) { return; }
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        if (line2.length() == 0) {
            dc.drawText(cx, h - 35, Graphics.FONT_XTINY, line1,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, h - 42, Graphics.FONT_XTINY, line1,
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, h - 28, Graphics.FONT_XTINY, line2,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawSettingsView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var headerH = 42;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(0, 0, w, headerH);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, headerH / 2, Graphics.FONT_SMALL, "Settings",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Vertically centre two rows between header bottom and hints top.
        // All positions derived from actual font height — no magic numbers.
        var fh       = dc.getFontHeight(Graphics.FONT_TINY);
        var hintsTop = h - 44;
        var rowGap   = fh / 2;
        var blockH   = fh * 2 + rowGap;
        var row0Y    = headerH + (hintsTop - headerH - blockH) / 2;
        var row1Y    = row0Y + fh + rowGap;

        // Chevron sits a fixed gap left of the widest label ("Button hints")
        var labelW   = (dc.getTextDimensions("Button hints", Graphics.FONT_TINY) as Array<Number>)[0];
        var chevronX = cx - 8 - labelW - 8;

        // Row 0: Button hints
        var row0Sel = (_model.settingIndex == 0);
        dc.setColor(row0Sel ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 8, row0Y, Graphics.FONT_TINY, "Button hints",
            Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(_model.showHints ? Graphics.COLOR_GREEN : Graphics.COLOR_RED,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 8, row0Y, Graphics.FONT_TINY,
            _model.showHints ? "ON" : "OFF", Graphics.TEXT_JUSTIFY_LEFT);
        if (row0Sel) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(chevronX, row0Y, Graphics.FONT_TINY, ">",
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Row 1: Distance units
        var row1Sel = (_model.settingIndex == 1);
        dc.setColor(row1Sel ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 8, row1Y, Graphics.FONT_TINY, "Distance",
            Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 8, row1Y, Graphics.FONT_TINY,
            _model.useMetres ? "Metres" : "Yards", Graphics.TEXT_JUSTIFY_LEFT);
        if (row1Sel) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(chevronX, row1Y, Graphics.FONT_TINY, ">",
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Keep each hint line short — the round bezel clips the bottom corners
        drawHints(dc, w, h, "UP/DN Select", "START Toggle  BACK");
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

        drawHints(dc, w, h, "START Exit", "BACK Green");
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
