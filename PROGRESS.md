# Athenry Golf — Project Progress

GPS golf app for a Garmin Forerunner 245 Music. Built in Monkey C (Connect IQ SDK 3.3). No phone, no Bluetooth, no API mid-round.

---

## What's Built

- Live B/M/F distances to green in yards (GPS-based)
- Hole number, par, SI displayed on green screen
- Shot distance tracker (mark tee → walk to ball → calculate)
- Score entry per hole with running vs-par total
- Full 18-hole scorecard with PGA-style birdie/bogey shapes (circles/squares)
- Round summary screen after hole 18

---

## Session History & Challenges

### Session 1 — Toolchain Setup
**Goal:** Get building and running in the Connect IQ simulator.

**Challenges overcome:**
- Monkey C extension requires Java — `brew install --cask temurin` needed but not documented
- `manifest.xml` schema: `minApiLevel` is wrong, must use `minSdkVersion`; `type="watchApp"` is wrong, must be `watch-app`; `<iq:language>eng</iq:language>` is text content not an attribute
- `monkey.jungle` rejects three-level property names — `fr245m.lang.default` breaks the parse and silently swallows `project.manifest` too
- Launcher icon is required — omitting it causes a build error; generated a minimal 70×70 PNG via Python
- Developer key must be `.der` format, not `.pem`; must be in workspace `.vscode/settings.json` not global settings; parent folder must not contain unrelated Garmin files
- **Build mode matters:** "Run Tests" ≠ "Run in Simulator". Release build goes to project root; debug goes to `bin/`
- Simulator shows blank until you use "Build for Device → Release" then open the `.prg` manually with `monkeydo`

**Outcome:** App building and running in simulator.

---

### Session 2 — Core Development
**Goal:** Build all features and get the UI working.

**Challenges overcome:**
- **GPS simulator never fires `onPosition`** even with coordinates set via Settings → Set Position. Fix: don't block navigation on `gpsReady`; show `---` for distances; accept any position with a non-null location (don't require `QUALITY_GOOD`)
- `Graphics.COLOR_TEAL` doesn't exist at API 3.3 — use `0x008080`
- Integer division by default — distances calculated as 0 until `1.0d` suffix added
- Scorecard PGA shapes (circles/squares) required manual pixel-level alignment; hardcoded offsets per shape type
- Shot tracker state machine needed a dedicated mode (`markSet` flag + LAP to confirm)
- Button layout constraints: long-press is claimed by watch OS defaults, so features were consolidated into a START-cycled mode system
- Score entry: UP/DOWN adjusts score, START exits edit mode — avoids needing a dedicated button
- SI display: `SI 01` zero-padded to prevent layout jumping on single vs double digit

**Outcome:** All features working in simulator. App loaded to watch via OpenMTP.

---

### Session 3 — UI Polish
**Goal:** Fix alignment and units.

**Challenges overcome:**
- Yards/metres inconsistency: green view used device units but shot tracker hardcoded yards — unified via `_useMetric` flag from `System.getDeviceSettings()`
- B/M/F horizontal centering: moved to screen centre rather than fixed x positions
- PGA shape alignment: circles and squares each need different offsets; no dynamic centering available — solved by measuring each character width

**Outcome:** UI consistent, units correct, shapes aligned.

---

### Session 4 — Sideloading
**Goal:** Automate deployment to the physical watch.

**Challenges overcome:**
- FR245M firmware 13.x removed mass storage — watch no longer mounts in Finder
- `simple-mtpfs` (initial approach) is **Linux-only** — Homebrew refuses to install it on macOS
- `libmtp` (`brew install libmtp`) does have macOS bottles and is the correct CLI MTP tool
- `mtp-detect` returned "No raw devices found" even as root — two root causes discovered:
  1. **FR245M product ID 0x4c05 is not in libmtp's device database** — only Monterra (0x2585) and FR645 Music (0x4b48) are listed
  2. **Watch USB mode must be set to MTP** — default is "Garmin" mode (for Garmin Connect sync), which presents no MTP interface; setting: `Settings → System → USB Mode → MTP`
- Automated path: `deploy.sh` exports `LIBMTP_DEVICE=0x091e:0x4c05` to hint libmtp, adds a `sleep 3` for MTP stack settle time, then falls back to launching OpenMTP automatically with instructions
- macOS `awk` lacks 3-argument `match()` (GNU awk extension) — folder detection rewritten with `sed`
- `UsbExclusiveOwner = AppleUSB20Hub` in ioreg is the USB hub driver, not Garmin Express — not actionable, was causing false positives

**Current status:** Confirmed — watch was already in MTP mode. libmtp simply cannot detect the FR245M (product ID 0x4c05 not in its database). OpenMTP is the permanent deploy path. `deploy.sh` auto-launches OpenMTP; one manual drag to `GARMIN/APPS/` is the workflow.

---

## Files

| File | Purpose |
|------|---------|
| `source/AthenryGolfApp.mc` | Entry point |
| `source/GolfModel.mc` | GPS, course data, scoring |
| `source/GolfView.mc` | All rendering |
| `source/GolfDelegate.mc` | Button handling |
| `deploy.sh` | Sideload script |
| `.cursor/rules/garmin-monkeyc-setup.mdc` | Build & SDK reference |
| `.cursor/rules/app-architecture.mdc` | App structure & Monkey C gotchas |
| `.cursor/rules/deploy.mdc` | Deployment reference |

---

### Session 5 — Navigation & Deploy Cleanup
**Goal:** Fix back-button dead-end and tidy deploy script.

**Changes:**
- **Back button wrap-around:** Pressing BACK from the Settings screen (last submenu) previously returned `false`, which caused the app to exit entirely. Fixed to set `uiMode = :green` so the full BACK cycle is: Green → Scorecard → Shot Tracker → Settings → Green. Settings hint updated from "BACK Close" to "BACK Green".
- **Deploy script cleaned up:** Removed the dead `mtp-sendfile` (libmtp) automated transfer step. The FR245M is confirmed undetectable by libmtp (product ID 0x4c05 not in its database). Script now goes straight to OpenMTP after detecting the watch, with no misleading "Trying automated MTP transfer..." message.

---

## Outstanding

**Done**
- [x] Toolchain — Monkey C extension, Java, developer key, manifest schema, jungle syntax
- [x] Core features — GPS distances (B/M/F), score entry, 18-hole scorecard, shot tracker, round summary
- [x] UI polish — alignment, yards/metres units, PGA birdie/bogey shapes
- [x] Sideloading — OpenMTP workflow, `deploy.sh` auto-launches with drag instructions
- [x] Back button navigation — cycles Green → Scorecard → Shot → Settings without accidental app exit
- [x] Deploy cleanup — removed dead libmtp path, single `AthenryGolf.prg` in project root
- [x] App exit — dedicated Exit screen added to the BACK cycle (Green → Scorecard → Shot → Settings → Exit → Green); START on Exit screen exits, BACK keeps cycling

- [x] Shell scripts — replaced the Monkey C extension's build/run commands (`Monkey C: Build for Device`, `Run in Simulator` etc.) with `sim.sh`, `run.sh`, `build-watch.sh`, and `deploy.sh`; the extension commands are unreliable, output to inconsistent locations, and require too many manual steps

**To Do**
- [x] Walk Athenry Golf Club greens and record GPS coordinates for all 18 holes in `GolfModel.mc`
- [x] Update par and stroke index from official scorecard
- [x] H13/H14 swap confirmed and corrected (API comparison + visual map)
- [ ] Verify H13/H14 on-course (API confirmed the swap — need to validate the corrected assignment is right)
- [x] Shot tracker real-world test on course
- [x] Dual Walk vs API columns → resolved: API-only (Session 16)
- [x] Scorecard colour cleanup (Session 20)
- [~] Hole shape / dogleg display → investigated, **decided not to build** (only 2 API doglegs for Athenry, not enough value — Session 19)
- [ ] Consider hazard distance display for H1/H9/H10/H13 water and H7/H18 bunkers (data available, not yet wired up)
- [ ] Evaluate redundant `pollPosition` timer — consider removing to save battery

Saturday and Sunday 21/22 March time spent ~6 hours

---

### Session 6 — Real GPS Coordinates & Scorecard Data
**Goal:** Replace all placeholder course data with real Athenry Golf Club coordinates and official par/SI values.

**What was done:**
- Walked all 18 greens and recorded Front/Middle/Back pin positions using BasicAirData GPS Logger for Android (KML export: `20260326-112903 - Athenry FMB Greens.kml`)
- Imported all 54 GPS coordinates into `GolfModel.mc` — all holes now have real lat/lon for F/M/B green distances
- Updated all par and stroke index values from the official Athenry scorecard (total par 70, front 35 / back 35; front 9 odd SIs 1–17, back 9 even SIs 2–18)

**Data issue found and resolved:**
- The GPS logger app did not advance its hole label when recording holes 12 and 13 — both were saved under the H11 and H14 names respectively, leaving H12 and H13 absent from the KML
- Resolved by cross-referencing GPS coordinates against the course layout map (`athenry_layout.png`): H11 group A (lon ~-8.845, more west) = H11; H11 group B (lon ~-8.843, more east) = H12; H14 group B (lat ~53.288, more north) = H13; H14 group A (lat ~53.285, same latitude band as H15–H17) = H14
- These assignments are best estimates from the map — to be verified on-course

**Par changes from placeholders:**
- H4: 5 → **4**, H6: 4 → **3**, H10: 4 → **5** (441m hole), H13: 5 → **4**, H17: 4 → **3**, H18: 5 → **4**

---

### Session 7 — Score Badge & Scorecard Grid
**Goal:** Surface scored holes on the green view and rework the scorecard layout.

**What was done:**
- Added a score badge to the green view — positioned in the left gutter at the M-row centre; shows the PGA shape (circle/square) and hole score so you can glance at progress without leaving the green screen
- Fixed score entry not auto-advancing to the next hole after START
- Rebuilt the scorecard grid: 3 rows × 6 holes replacing the old cluttered layout
- Fixed Eagle label vertical position and font size in the scorecard header

---

### Session 8 — Scorecard Polish & GPS Animation
**Goal:** Add Out/In totals, tighten the scorecard UX, and improve GPS acquisition feedback.

**What was done:**
- Added Out/In sub-totals below the scorecard grid — only appear once the front 9 or back 9 is fully complete
- Combined total line into a single inline `"54 strokes (+7)"` format with colour-coded vs-par
- Running totals no longer update live while adjusting a score — only commit on START, preventing distracting number jumps
- Edit cursor changed from white box to same-background so score remains visible
- Hints stacked and re-centred to respect the round bezel clipping zone
- GPS acquiring animation: cycles `. → .. → ...` on a 400 ms timer with a fixed label pivot so text never drifts
- Scorecard: UP/DN now browses holes (cursor moves), START toggles edit mode for the selected hole — one-direction-only START navigation removed
- Cursor indicator: unscored holes show `_`, edit-active hole shows a blinking `0`; UP/DN directions corrected

---

### Session 9 — UI Polish Pass
**Goal:** Clean up score defaults, cursor visibility, and scorecard header clutter.

**What was done:**
- Score entry and card edit now **default to par** when a hole has no score yet — user adjusts up/down from par rather than up from 0
- Scored holes are now **visible while the browse cursor passes over them** — previously the `continue` after drawing `_` hid the score entirely; now only unscored cells show `_`
- Added a **dim gray border** around the cursor cell in browse mode so position is always clear without obscuring the score or shape
- Scorecard header simplified: browse mode shows `"H4  Par 4"` only; removed score/label line and "Editing" prefix — score detail is visible in the grid cell itself
- Green view: **score badge hidden when GPS not yet acquired** — acquiring animation has the screen to itself
- Green view: **par no longer gets a shape** — par is the baseline, shown as plain white number with no circle
- Edit mode: the **number and shape blink** instead of a white border flashing around the cell — number disappears on blink-off, reappears on blink-on

---

Thursday 26 March — time spent ~7.5 hours (4 hr walking greens with GPS logger, ~3.5 hrs coding)

---

### Session 10 — Golf API Integration & Dual Yardage Comparison

**Goal:** Cross-reference our walked GPS coordinates against Golf API data, fix H13/H14 swap, add dual-column yardage display for on-course comparison.

**What was done:**
- Subscribed to Golf API (golfapi.io). Key stored in gitignored comparison doc.
- Fetched real Athenry Golf Club coordinates: course ID `012141519725013601029`
- Created `golfapi_coordinates_comparison.md` and `golfapi_coordinates_raw.json` (both gitignored)
- **Confirmed H13/H14 swap**: our walked data had the two greens assigned backwards (~350 m off). The GPS logger mislabelled them on-course. Corrected by swapping the coordinate values in `GolfModel.mc` H13/H14 rows.
- **Agreement analysis**: most holes < 10 m from API; H1/H3/H12 front pins 15–23 m off (walked from apron, not green edge — conservative/safe); H5/H6/H7 sub-3 m best-in-class.
- Added `_apiHoles` array to `GolfModel.mc` (18 × 6 doubles, Golf API green coordinates).
- Added `distToFrontApi()`, `distToMiddleApi()`, `distToBackApi()` to `GolfModel.mc`.
- Redesigned green view for dual-column yardage display:
  - Left column "Walk" (our data, white/yellow): B / M / F
  - Right column "API" (cyan): B / M / F
  - Divider line at screen centre
  - Score badge `[N]` between column headers once a hole is scored
  - Numbers in FONT_SMALL (was FONT_MEDIUM) to fit two columns

**Outstanding after session 10:**
- [ ] On-course: verify H13/H14 assignment is now correct
- [ ] After round: decide whether to keep dual columns or revert to single (our data is good; API is close enough)
- [ ] If keeping API data: update `_holes` coordinates to use API values for the 3 front-pin outliers (H1, H3, H12)

---

### Session 11 — Green Map Visualisation & Layout Comparison

**Goal:** Visually verify the H13/H14 situation before playing, and sanity-check all 18 holes against the official course map.

**What was done:**
- Generated a Python/matplotlib map plotting all 18 greens (F/M/B pins) in GPS space, opened in Preview
- Compared the generated map against `athenry_layout.png` (official course image)
- Concluded relative hole positions look broadly correct — H13/H14 had already been fixed by the API comparison in Session 10

---

### Session 12 — GolfCourseAPI Official Yardages

**Goal:** Pull official per-hole yardages from a second API (GolfCourseAPI, golfcourseapi.com — separate service from golfapi.io).

**What was done:**
- Searched GolfCourseAPI — found Athenry Golf Club (course ID 15077, location: Palmerstown, Oranmore, Co. Galway)
- API returns par + yardage per hole (no GPS coordinates — only a single course-level lat/lon)
- Added White tee yardage as element `[8]` to each hole in `_holes` array in `GolfModel.mc`
- Added `getYardage()` helper function to `GolfModel.mc`
- Updated green view header line 2 to show yardage alongside par and SI: `"Par 4  457Y  SI 01"`
- Confirmed: GolfCourseAPI does not provide per-hole green/tee GPS coordinates; golfapi.io is the only source for those

---

### Session 13 — Coordinate Comparison Doc & Walked Mid Coordinates

**Goal:** Tidy up the coordinate comparison doc, use physically walked mid values instead of computed midpoints, and fix POI code errors.

**What was done:**
- Received original GPS export from walk (GPX + KML — same data, different formats); GPX is universal fitness format, KML is Google Earth format
- Updated `golfapi_coordinates_comparison.md` to show **three data sets** per hole:
  - Column 1: **Raw walked GPX** — the physically recorded F, M, B waypoints exactly as logged
  - Column 2: **Walk F/B + computed M** — what was previously in `GolfModel.mc` (computed mid as (front+back)/2)
  - Column 3: **API (golfapi.io)** — fetched coordinates from Session 10
- Replaced all 18 computed mid values in `GolfModel.mc` with the physically walked GPX `M` waypoints — mid is now a real GPS fix, not an arithmetic average
- **Fixed POI codes 4 and 9 swapped** in `golfapi.mdc` and comparison doc: API schema shows `poi=4` is Water, `poi=9` is Dogleg (we had them backwards)
- Also documented the full POI list: 1=Green, 2=Green Bunker, 3=Fairway Bunker, 4=Water, 5=Trees, 6=100m Marker, 7=150m Marker, 8=200m Marker, 9=Dogleg, 10=Road, 11=Tee Front, 12=Tee Back

**GPS polling analysis:**
- Current code runs a **double-polling** setup: `LOCATION_CONTINUOUS` callback at ~1 Hz plus an explicit 2-second `pollPosition` timer — the timer is redundant; left as-is for now (battery impact minor vs a full round)

---

### Session 14 — Postman Collection & golfapi.mdc Corrections

**Goal:** Import the full Golf API Postman collection and fix any inaccuracies in the rule file.

**What was done:**
- Exported the Golf API Postman collection from the browser as `Golf API.postman_collection.json` (added to workspace, gitignored)
- Updated `golfapi.mdc` from the collection:
  - **Fixed `GET /clubs/{id}` cost** — was incorrectly marked as free; confirmed **1.0 credit** like all fetch-by-ID endpoints
  - **Fixed `GET /courses/{id}` cost** — was marked `?`; confirmed **1.0 credit**
  - **Added `GET /courses` search endpoint** with query params (`name`, `club_id`, `lat`, `lon`, `dist`) — same 0.1 credit as club search
- Full API has exactly 5 endpoints; no hidden endpoints

---

### Session 15 — API Hazard & Feature Analysis

**Goal:** Determine what else the Golf API has for Athenry that could be added to the app.

**What was done:**
- Parsed `golfapi_coordinates_raw.json` (saved from Session 10, no extra credits needed) to count all POI types
- **Hazard data available for Athenry (12 points across 5 holes):**

| POI | Type | Count | Holes |
|-----|------|-------|-------|
| poi=3 | Fairway bunker | 3 | H7 (×2), H18 (×1) |
| poi=4 | Water | 7 | H1 (×2), H9 (×2), H10 (×1), H13 (×2) |
| poi=9 | Dogleg | 2 | H4 (×1), H14 (×1) |

- **Tee data**: poi=11 (Tee Front) and poi=12 (Tee Back) present for all 18 holes but are identical coordinates — API has only one tee marker per hole for Athenry
- **Identified**: H1's poi=9 "dogleg" marker is between tee and green at ~53.2854, -8.8477 — consistent with H1's routing
- **Note on poi=9 reliability**: H4 has a dogleg POI but there is no water on H4 — confirmed this is the API using poi=9 for hazards broadly (could be OOB/ditches), not just water exclusively; greens (poi=1) are the most reliable data
- **Conclusion**: Hazard distance display is technically feasible but limited in scope (5 holes with data); deferred

Saturday 28 March — time spent ~4 hours (evening sessions)

---

### Session 16 — API-Only Distances & Auto-Return

**Goal:** Simplify the green view to a single yardage source, add idle timeout.

**What was done:**
- Removed the dual Walk/API column layout — green view now shows **API distances only** (golfapi.io data is accurate enough; dual columns were cluttered on a 240 px screen)
- Middle distance drawn largest (FONT_NUMBER_MEDIUM), Front and Back smaller — the number you glance at most is the biggest
- Removed "Y" unit suffix from B/M/F rows — yards are implied, saves horizontal space
- Re-centred the B/M/F text block with tighter vertical gaps
- Added **auto-return to green view** after 15 seconds idle on any submenu — prevents the watch sitting on the scorecard or settings screen during play

---

### Session 17 — Irish Green Header & Live Shot Distance

**Goal:** Visual identity pass and shot tracker UX improvement.

**What was done:**
- Changed header background from teal (`0x008080`) to **Irish green** (`0x009A44`) across all screens via a shared `drawHeader()` helper
- Renamed "Shot Tracker" → **"Shot Dist"** (shorter, fits header better)
- Added **live distance** to the shot tracker — after pressing START to mark your position, the screen shows a continuously updating distance as you walk to the ball, before pressing START again to lock it in
- Shot tracker hints updated: "START Lock" while distance is live

---

### Session 18 — Timer Bug Fixes & Idle Settings

**Goal:** Fix recurring "Too Many Timers" crash.

**What was done:**
- **Root cause:** Connect IQ allows a maximum of 3 concurrent timers. The app was stacking: GPS poll timer + blink timer + idle timer. Entering score edit mode could create a 4th, crashing the app.
- **First fix** (Session 18a): added `stopBlink()` at the start of `startBlink()` to prevent stacked blink timers — insufficient, still crashed with idle timer active
- **Final fix** (Session 18b): **removed the blink timer entirely**. Edit-mode blink now uses `System.getTimer()` modulo 400 ms, checked during the existing `onGpsAnim` 1 Hz callback. Zero additional timers for blink.
- Made idle return timeout **configurable**: OFF / 15 / 30 / 45 / 60 seconds, selectable in Settings screen
- Updated `app-architecture.mdc` with the new timer architecture

---

### Session 19 — Hole Shape Investigation (not built)

**Goal:** Explore displaying hole shape / dogleg routing on the green view.

**What was done:**
- Investigated Golf API dogleg data (poi=9): Athenry has **only 2 dogleg points** (H4 and H14) — not enough to show meaningful hole routing for the other 16 holes
- Explored BlueGolf-style hole diagrams with ratio-based scaling anchored to tee/green coordinates — conceptually viable but complex for a 240 px round screen
- Considered satellite image tracing with a click-to-waypoint tool
- **Decision: not built.** The API data is too sparse (2/18 holes), and manually tracing all 18 holes from satellite imagery is more effort than the feature warrants on a watch screen. The green view already shows B/M/F distances which is what you need mid-shot.

---

### Session 20 — Scorecard Cleanup

**Goal:** Reduce visual noise on the 18-hole scorecard.

**What was done:**
- **Simplified score colours:** removed the 5-colour rainbow (yellow/green/white/orange/red). All score numbers are now **white**. PGA shapes alone convey meaning — white circles for under par, red squares for over par.
- **Cursor unified:** replaced the rectangle border (scored holes) and underscore (unscored holes) with a single **subtle underline** beneath the cell — consistent regardless of score state
- **Totals line simplified:** `"24 strokes (+2)"` is now a single string in `COLOR_LT_GRAY` instead of split-coloured text. Less visual competition with the score grid.
- **Even par display:** `(0)` replaced with `(E)` — standard golf shorthand for "even"

Wednesday 9 April — time spent ~1.5 hours