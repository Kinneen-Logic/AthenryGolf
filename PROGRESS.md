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
- [ ] Verify H11/H12 and H13/H14 green assignments on-course (GPS logger reused labels — see Session 6)
- [ ] Shot tracker real-world test on course

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

Thursday 26 March