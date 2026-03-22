import Toybox.Position;
import Toybox.Math;
import Toybox.Lang;

// ─────────────────────────────────────────────
//  ATHENRY GOLF CLUB – Hardcoded Course Data
//
//  HOW TO CALIBRATE:
//  Walk to the front, middle, and back of each
//  green early morning. Stand still for 5 sec,
//  note the GPS coords from your phone (Google
//  Maps long-press → copy coordinates).
//  Replace the placeholder values below.
//
//  Format per hole:
//    [par, strokeIndex, frontLat, frontLon,
//     midLat, midLon, backLat, backLon]
// ─────────────────────────────────────────────

class GolfModel {

    // Hole data: par, SI, front/mid/back green coords
    // ⚠ REPLACE lat/lon values with your own GPS readings
    private var _holes as Array = [
        // H1  par  SI   frontLat      frontLon     midLat        midLon       backLat       backLon
        [  4,   9,  53.299100,  -8.749200,  53.299050,  -8.749300,  53.299000,  -8.749400 ],
        // H2
        [  4,   1,  53.300200,  -8.748100,  53.300150,  -8.748200,  53.300100,  -8.748300 ],
        // H3
        [  3,  17,  53.301100,  -8.747500,  53.301050,  -8.747600,  53.301000,  -8.747700 ],
        // H4
        [  5,   5,  53.302000,  -8.746800,  53.301950,  -8.746900,  53.301900,  -8.747000 ],
        // H5
        [  4,  13,  53.302900,  -8.746000,  53.302850,  -8.746100,  53.302800,  -8.746200 ],
        // H6
        [  4,   3,  53.303800,  -8.745200,  53.303750,  -8.745300,  53.303700,  -8.745400 ],
        // H7
        [  3,  15,  53.304700,  -8.744400,  53.304650,  -8.744500,  53.304600,  -8.744600 ],
        // H8
        [  5,   7,  53.305600,  -8.743600,  53.305550,  -8.743700,  53.305500,  -8.743800 ],
        // H9
        [  4,  11,  53.306500,  -8.742800,  53.306450,  -8.742900,  53.306400,  -8.743000 ],
        // H10
        [  4,  10,  53.307400,  -8.742000,  53.307350,  -8.742100,  53.307300,  -8.742200 ],
        // H11
        [  4,   2,  53.308300,  -8.741200,  53.308250,  -8.741300,  53.308200,  -8.741400 ],
        // H12
        [  3,  16,  53.309200,  -8.740400,  53.309150,  -8.740500,  53.309100,  -8.740600 ],
        // H13
        [  5,   6,  53.310100,  -8.739600,  53.310050,  -8.739700,  53.310000,  -8.739800 ],
        // H14
        [  4,  14,  53.311000,  -8.738800,  53.310950,  -8.738900,  53.310900,  -8.739000 ],
        // H15
        [  4,   4,  53.311900,  -8.738000,  53.311850,  -8.738100,  53.311800,  -8.738200 ],
        // H16
        [  3,  18,  53.312800,  -8.737200,  53.312750,  -8.737300,  53.312700,  -8.737400 ],
        // H17
        [  4,   8,  53.313700,  -8.736400,  53.313650,  -8.736500,  53.313600,  -8.736600 ],
        // H18
        [  5,  12,  53.314600,  -8.735600,  53.314550,  -8.735700,  53.314500,  -8.735800 ]
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
