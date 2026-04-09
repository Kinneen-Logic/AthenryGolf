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
    }

    function onGpsAnim() as Void {
        if (!_model.gpsReady) {
            WatchUi.requestUpdate();
        }
        // Scorecard edit blink uses System.getTimer() in draw — tick here so it animates
        // without a fourth Timer (CIQ enforces a low concurrent timer limit).
        if (_model.uiMode == :light && _model.lightIndex == 0 && _model.editActive) {
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

    function resetIdleTimer() as Void {
        if (_idleTimer != null) {
            _idleTimer.stop();
        }
        if (_model.uiMode != :green && _model.idleTimerSec > 0) {
            _idleTimer = new Timer.Timer();
            _idleTimer.start(method(:onIdleTimeout), _model.idleTimerSec * 1000, false);
        }
    }

    function onIdleTimeout() as Void {
        if (_model.uiMode != :green) {
            _model.editActive = false;
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

        var si = _model.getStrokeIndex();
        var siStr = si < 10 ? "SI 0" + si : "SI " + si;
        var yd = _model.getYardage();
        var ydStr = _model.useMetres
            ? ((yd * 0.9144d + 0.5d).toNumber().toString() + "M")
            : (yd.toString() + "Y");
        var headerH = drawHeader(dc, 0x009A44, Graphics.COLOR_BLACK,
            "Hole " + _model.holeNumber(),
            "Par " + _model.getPar() + "  " + ydStr + "  " + siStr);

        var hintsTop = h - 44;

        if (!_model.gpsReady) {
            var phase   = ((System.getTimer() / 400) % 3).toNumber();
            var dots    = phase == 0 ? "." : (phase == 1 ? ".." : "...");
            var fhSmall = dc.getFontHeight(Graphics.FONT_SMALL);
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

        var headerH = drawHeader(dc, Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK,
            "H" + _model.holeNumber() + "  Par " + _model.getPar(), "");

        var score = _model.scores[_model.currentHole] as Number;
        var par   = _model.getPar();
        var diff  = score - par;

        var hintsTop = h - 44;
        var fhHot = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var fhSm  = dc.getFontHeight(Graphics.FONT_SMALL);
        var blockH = fhHot + fhSm + 4;
        var topY = headerH + (hintsTop - headerH - blockH) / 2;

        dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY, Graphics.FONT_NUMBER_HOT, score.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY + fhHot + 4, Graphics.FONT_SMALL, scoreLabel(score, par, diff),
            Graphics.TEXT_JUSTIFY_CENTER);

        drawHints(dc, w, h, "UP+ DN-", "START Next");
    }

    // ── Scorecard with inline edit ──────────────

    private function drawCardView(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var editing = _model.editActive;

        var eh = _model.editHole;
        var ep = _model.getParForHole(eh);
        var headerH = drawHeader(dc, 0x008080, Graphics.COLOR_BLACK,
            "H" + (eh + 1) + "  Par " + ep, "");

        // Grid: 3 rows × 6 holes
        var cellW  = 30;
        var cellH  = 22;
        var colGap = 4;
        var rowGap = 6;
        var cols   = 6;
        var rowW   = cols * cellW + (cols - 1) * colGap;
        var startX = (w - rowW) / 2;
        var row1Y  = headerH + 8;
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
            // ~400 ms flash phase; driven by onGpsAnim requestUpdate (same interval as old blink timer)
            if (isEditCell && ((System.getTimer() / 400) % 2) != 0) {
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

        var headerH = drawHeader(dc, Graphics.COLOR_BLUE, Graphics.COLOR_WHITE,
            "Shot Dist", "");

        if (!_model.gpsReady) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 10, Graphics.FONT_MEDIUM, "No GPS",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "BACK Close", "");
            return;
        }

        if (_model.shotMarked) {
            var liveDist = _model.liveShotDist();
            var liveStr;
            var liveUnit;
            if (_model.useMetres) {
                liveStr = (liveDist * 0.9144d + 0.5d).toNumber().toString();
                liveUnit = "metres";
            } else {
                liveStr = liveDist.toString();
                liveUnit = "yards";
            }

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, headerH + 14, Graphics.FONT_XTINY, "Walk to ball",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 - 20, Graphics.FONT_NUMBER_MEDIUM,
                liveStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2 + 30, Graphics.FONT_SMALL, liveUnit,
                Graphics.TEXT_JUSTIFY_CENTER);
            drawHints(dc, w, h, "START Lock", "BACK Next");
        } else if (_model.shotCalculated) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, headerH + 14, Graphics.FONT_XTINY, "Last shot",
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

        var headerH = drawHeader(dc, Graphics.COLOR_PURPLE, Graphics.COLOR_WHITE,
            "Round Over", "");

        var total = _model.totalStrokes();
        var par   = _model.totalPar();
        var hintsTop = h - 44;

        if (total == 0) {
            var fhSm = dc.getFontHeight(Graphics.FONT_SMALL);
            var fhXt = dc.getFontHeight(Graphics.FONT_XTINY);
            var blockH = fhSm + fhXt + 4;
            var topY = headerH + (hintsTop - headerH - blockH) / 2;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, topY, Graphics.FONT_SMALL, "No scores entered",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, topY + fhSm + 4, Graphics.FONT_XTINY, "Par " + par,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var diff = total - par;
            var fhXt  = dc.getFontHeight(Graphics.FONT_XTINY);
            var fhNum = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
            var gap = 4;
            var blockH = (fhXt + gap + fhNum) * 2 + 8;
            var y0 = headerH + (hintsTop - headerH - blockH) / 2;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y0, Graphics.FONT_XTINY, "Total strokes",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y0 + fhXt + gap, Graphics.FONT_NUMBER_MEDIUM,
                total.toString(), Graphics.TEXT_JUSTIFY_CENTER);

            var y1 = y0 + fhXt + gap + fhNum + 8;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y1, Graphics.FONT_XTINY, "Course par " + par,
                Graphics.TEXT_JUSTIFY_CENTER);

            var vsParStr = diff > 0 ? "+" + diff : diff.toString();
            dc.setColor(scoreColor(diff), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y1 + fhXt + gap, Graphics.FONT_NUMBER_MEDIUM,
                vsParStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawHints(dc, w, h, "DN or BACK to H18", "");
    }

    // ── Helpers ─────────────────────────────────

    private function drawHeader(dc as Graphics.Dc, bgColor as Number, textColor as Number,
                                line1 as String, line2 as String) as Number {
        var w = dc.getWidth();
        var cx = w / 2;
        var fhSmall = dc.getFontHeight(Graphics.FONT_SMALL);
        var headerH;
        if (line2.length() > 0) {
            var fhTiny = dc.getFontHeight(Graphics.FONT_TINY);
            headerH = fhSmall + fhTiny + 12;
            dc.setColor(bgColor, bgColor);
            dc.fillRectangle(0, 0, w, headerH);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            var topY = (headerH - fhSmall - fhTiny - 4) / 2;
            dc.drawText(cx, topY, Graphics.FONT_SMALL, line1,
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, topY + fhSmall + 4, Graphics.FONT_TINY, line2,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            headerH = fhSmall + 12;
            dc.setColor(bgColor, bgColor);
            dc.fillRectangle(0, 0, w, headerH);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (headerH - fhSmall) / 2, Graphics.FONT_SMALL, line1,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        return headerH;
    }

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

        var headerH = drawHeader(dc, Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE,
            "Settings", "");

        var fh       = dc.getFontHeight(Graphics.FONT_TINY);
        var hintsTop = h - 44;
        var rowGap   = fh / 2;
        var rows     = 3;
        var blockH   = fh * rows + rowGap * (rows - 1);
        var row0Y    = headerH + (hintsTop - headerH - blockH) / 2;
        var row1Y    = row0Y + fh + rowGap;
        var row2Y    = row1Y + fh + rowGap;

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

        // Row 2: Idle timer
        var row2Sel = (_model.settingIndex == 2);
        dc.setColor(row2Sel ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 8, row2Y, Graphics.FONT_TINY, "Idle return",
            Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(_model.idleTimerSec > 0 ? Graphics.COLOR_YELLOW : Graphics.COLOR_RED,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 8, row2Y, Graphics.FONT_TINY,
            _model.idleTimerSec > 0 ? (_model.idleTimerSec + "s") : "OFF",
            Graphics.TEXT_JUSTIFY_LEFT);
        if (row2Sel) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(chevronX, row2Y, Graphics.FONT_TINY, ">",
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        drawHints(dc, w, h, "UP/DN Select", "START Toggle  BACK");
    }

    private function drawExitView(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var headerH = drawHeader(dc, Graphics.COLOR_DK_RED, Graphics.COLOR_WHITE,
            "Exit App", "");

        var hintsTop = h - 44;
        var fhSm = dc.getFontHeight(Graphics.FONT_SMALL);
        var fhXt = dc.getFontHeight(Graphics.FONT_XTINY);
        var blockH = fhSm + fhXt + 4;
        var topY = headerH + (hintsTop - headerH - blockH) / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, topY, Graphics.FONT_SMALL, "Press START",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, topY + fhSm + 4, Graphics.FONT_XTINY, "to exit the app",
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
