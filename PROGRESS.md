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
| `.cursor/rules/DEPLOY_TROUBLESHOOTING.md` | Full deploy diagnostic history |

---

## Outstanding

- [ ] Walk Athenry Golf Club greens and replace placeholder GPS coordinates in `GolfModel.mc`
- [ ] Confirm `Settings → System → USB Mode → MTP` on watch and test fully automated deploy
- [ ] Shot tracker real-world test on course
