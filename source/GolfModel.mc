import Toybox.Position;
import Toybox.Math;
import Toybox.Lang;

// ─────────────────────────────────────────────
//  ATHENRY GOLF CLUB – Hardcoded Course Data
//
//  Green GPS coordinates recorded 2026-03-26
//  using BasicAirData GPS Logger (Android).
//  Source: 20260326-112903 - Athenry FMB Greens.kml
//
//  Format per hole:
//    [par, strokeIndex, frontLat, frontLon,
//     midLat, midLon, backLat, backLon, yardsWhite]
//
//  Par/SI source: official Athenry scorecard.
//  Total par 70 (front 35, back 35).
//  Front 9 SI: odd numbers (1,3,5,7,9,11,13,15,17)
//  Back  9 SI: even numbers (2,4,6,8,10,12,14,16,18)
//
//  yardsWhite: official hole yardage from White tees.
//  Source: GolfCourseAPI.com course ID 15077
//  (total 6,445Y; course rating 70.7; slope 121)
// ─────────────────────────────────────────────

class GolfModel {

    // Hole data: par, SI, frontLat, frontLon, midLat, midLon, backLat, backLon, yardsWhite
    private var _holes as Array = [
        // H1  par  SI   frontLat        frontLon       midLat          midLon         backLat         backLon        yd
        [  4,   3,  53.28639231d,  -8.84882937d,  53.28654423d,  -8.84895276d,  53.28663276d,  -8.84904305d,  414 ],
        // H2
        [  4,   7,  53.28789738d,  -8.84513002d,  53.28792269d,  -8.84494442d,  53.28796748d,  -8.84483139d,  366 ],
        // H3
        [  3,  17,  53.28934958d,  -8.84459078d,  53.28935331d,  -8.84439755d,  53.28945926d,  -8.84442587d,  174 ],
        // H4
        [  4,  13,  53.28901196d,  -8.84867440d,  53.28906998d,  -8.84880444d,  53.28905431d,  -8.84896240d,  331 ],
        // H5
        [  4,   9,  53.28816887d,  -8.85215981d,  53.28813935d,  -8.85238022d,  53.28805583d,  -8.85255743d,  367 ],
        // H6
        [  3,  15,  53.28683548d,  -8.85153046d,  53.28675083d,  -8.85141293d,  53.28665331d,  -8.85123286d,  170 ],
        // H7
        [  4,   1,  53.28869358d,  -8.84557448d,  53.28877599d,  -8.84538022d,  53.28880206d,  -8.84515190d,  457 ],
        // H8
        [  5,  11,  53.28780801d,  -8.85170236d,  53.28778020d,  -8.85187673d,  53.28767938d,  -8.85212705d,  529 ],
        // H9
        [  4,   5,  53.28444219d,  -8.84856189d,  53.28437906d,  -8.84844816d,  53.28427416d,  -8.84828525d,  382 ],
        // H10
        [  5,  18,  53.28703418d,  -8.85050912d,  53.28713768d,  -8.85058091d,  53.28725589d,  -8.85067847d,  484 ],
        // H11
        [  4,  10,  53.28831831d,  -8.84518651d,  53.28834536d,  -8.84502540d,  53.28839535d,  -8.84490675d,  387 ],
        // H12
        [  3,  12,  53.28827572d,  -8.84326475d,  53.28816722d,  -8.84309481d,  53.28803340d,  -8.84305385d,  187 ],
        // H13
        [  4,   2,  53.28755124d,  -8.84343407d,  53.28760524d,  -8.84320375d,  53.28762663d,  -8.84295364d,  424 ],
        // H14
        [  4,   4,  53.28523855d,  -8.84631114d,  53.28510435d,  -8.84630322d,  53.28494376d,  -8.84648910d,  437 ],
        // H15
        [  4,   6,  53.28431435d,  -8.84562554d,  53.28420498d,  -8.84571182d,  53.28410807d,  -8.84570291d,  417 ],
        // H16
        [  4,   8,  53.28614484d,  -8.84276877d,  53.28629036d,  -8.84257290d,  53.28641546d,  -8.84247021d,  401 ],
        // H17
        [  3,  16,  53.28518566d,  -8.84295321d,  53.28512766d,  -8.84308677d,  53.28502168d,  -8.84320399d,  156 ],
        // H18
        [  4,  14,  53.28321317d,  -8.84504377d,  53.28309199d,  -8.84515084d,  53.28296152d,  -8.84526952d,  362 ]
    ];

    // ── State ──────────────────────────────────
    var currentHole  as Number = 0;   // 0-indexed
    var scores       as Array  = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

    // GPS
    var currentLat   as Double = 0.0d;
    var currentLon   as Double = 0.0d;
    var gpsReady     as Boolean = false;

    // Shot tracking
    var shotMarkedLat  as Double = 0.0d;
    var shotMarkedLon  as Double = 0.0d;
    var shotMarked      as Boolean = false;
    var shotCalculated  as Boolean = false;
    var lastShotDist    as Number = 0;  // yards

    // UI modes: :green, :scoreEntry, :light, :summary
    var uiMode as Symbol = :green;

    // Within :light mode: 0=scorecard, 1=shot tracker, 2=settings, 3=exit
    var lightIndex as Number = 0;
    const LIGHT_COUNT = 4;

    // Settings
    var showHints    as Boolean = true;
    var useMetres    as Boolean = false;
    var settingIndex as Number  = 0;  // 0=hints, 1=units

    // Scorecard edit state
    var editHole as Number = 0;
    var editActive as Boolean = false;
    var blinkOn as Boolean = true;

    function initialize() {
    }

    // ── Hole helpers ──────────────────────────

    function getPar() as Number {
        return _holes[currentHole][0] as Number;
    }

    function getParForHole(hole as Number) as Number {
        return _holes[hole][0] as Number;
    }

    function getStrokeIndex() as Number {
        return _holes[currentHole][1] as Number;
    }

    function holeNumber() as Number {
        return currentHole + 1;
    }

    function getYardage() as Number {
        return _holes[currentHole][8] as Number;
    }

    function scoreVsPar() as Number {
        var total = 0;
        var totalPar = 0;
        for (var i = 0; i <= currentHole; i++) {
            if (scores[i] > 0) {
                total += scores[i];
                totalPar += (_holes[i][0] as Number);
            }
        }
        return total - totalPar;
    }

    function totalStrokes() as Number {
        var total = 0;
        for (var i = 0; i < 18; i++) {
            if ((scores[i] as Number) > 0) {
                total += scores[i] as Number;
            }
        }
        return total;
    }

    function front9Strokes() as Number {
        var total = 0;
        for (var i = 0; i < 9; i++) {
            if ((scores[i] as Number) > 0) {
                total += scores[i] as Number;
            }
        }
        return total;
    }

    function back9Strokes() as Number {
        var total = 0;
        for (var i = 9; i < 18; i++) {
            if ((scores[i] as Number) > 0) {
                total += scores[i] as Number;
            }
        }
        return total;
    }

    function front9Complete() as Boolean {
        for (var i = 0; i < 9; i++) {
            if ((scores[i] as Number) == 0) { return false; }
        }
        return true;
    }

    function back9Complete() as Boolean {
        for (var i = 9; i < 18; i++) {
            if ((scores[i] as Number) == 0) { return false; }
        }
        return true;
    }

    function totalPar() as Number {
        var total = 0;
        for (var i = 0; i < 18; i++) {
            total += (_holes[i][0] as Number);
        }
        return total;
    }

    function adjustScore(delta as Number) as Void {
        var s = (scores[currentHole] as Number) + delta;
        if (s < 0) { s = 0; }
        if (s > 12) { s = 12; }
        scores[currentHole] = s;
    }

    function adjustScoreForHole(hole as Number, delta as Number) as Void {
        var s = (scores[hole] as Number) + delta;
        if (s < 0) { s = 0; }
        if (s > 12) { s = 12; }
        scores[hole] = s;
    }

    function nextHole() as Void {
        if (currentHole < 17) {
            currentHole++;
            shotMarked = false;
            shotCalculated = false;
            lastShotDist = 0;
            uiMode = :green;
        } else {
            uiMode = :summary;
        }
    }

    function prevHole() as Void {
        if (currentHole > 0) {
            currentHole--;
            shotMarked = false;
            shotCalculated = false;
            lastShotDist = 0;
            uiMode = :green;
        }
    }

    // ── GPS ───────────────────────────────────

    function updatePosition(info as Position.Info) as Void {
        if (info.position != null) {
            var loc = info.position.toDegrees();
            var lat = loc[0] as Double;
            var lon = loc[1] as Double;
            // Reject simulator sentinel (180, 180) and poles
            if (lat > 89.0d || lat < -89.0d || lon > 179.0d || lon < -179.0d) {
                return;
            }
            currentLat = lat;
            currentLon = lon;
            gpsReady = true;
        }
    }

    // Equirectangular distance in yards between two lat/lon points
    private function distYards(lat1 as Double, lon1 as Double,
                                lat2 as Double, lon2 as Double) as Number {
        var R = 6371000.0d;  // Earth radius metres
        var dLat = (lat2 - lat1) * Math.PI / 180.0d;
        var dLon = (lon2 - lon1) * Math.PI / 180.0d;
        var midLat = (lat1 + lat2) / 2.0d * Math.PI / 180.0d;
        var x = dLon * Math.cos(midLat);
        var dist = Math.sqrt(x * x + dLat * dLat) * R;
        return (dist * 1.09361d + 0.5d).toNumber();  // metres → yards
    }

    function distToFront() as Number {
        if (!gpsReady) { return 0; }
        return distYards(currentLat, currentLon,
            _holes[currentHole][2] as Double,
            _holes[currentHole][3] as Double);
    }

    function distToMiddle() as Number {
        if (!gpsReady) { return 0; }
        return distYards(currentLat, currentLon,
            _holes[currentHole][4] as Double,
            _holes[currentHole][5] as Double);
    }

    function distToBack() as Number {
        if (!gpsReady) { return 0; }
        return distYards(currentLat, currentLon,
            _holes[currentHole][6] as Double,
            _holes[currentHole][7] as Double);
    }

    // ── Shot tracking ─────────────────────────

    function markShot() as Void {
        if (!gpsReady) { return; }
        shotMarkedLat = currentLat;
        shotMarkedLon = currentLon;
        shotMarked = true;
        shotCalculated = false;
        lastShotDist = 0;
    }

    function calculateShotDist() as Void {
        if (!shotMarked || !gpsReady) { return; }
        lastShotDist = distYards(shotMarkedLat, shotMarkedLon,
                                  currentLat, currentLon);
        shotMarked = false;
        shotCalculated = true;
    }
}
