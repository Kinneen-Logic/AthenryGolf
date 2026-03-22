# Athenry Golf – Forerunner 245 Music App

A hardcoded GPS golf app for Athenry Golf Club. No phone, no Bluetooth, no API needed mid-round.

## Features
- Live distance to front / middle / back of green (yards)
- Hole number, par, stroke index
- Shot distance tracker (mark tee → walk to ball → calculate)
- Score entry with vs-par running total
- Round summary screen
- Scorecard view with PGA-style birdie/bogey shapes

## Button layout (Forerunner 245)
| Button | Green view | Shot view | Score view |
|--------|-----------|-----------|------------|
| UP | Next hole | — | Score +1 |
| DOWN | Prev hole | — | Score -1 |
| START | Cycle mode | Cycle mode | Cycle mode |
| LIGHT | Mark shot | Mark/Calc | Mark shot |
| LAP | — | Mark/Calc | Advance hole |

START cycles: Green → Shot → Score → Scorecard → Green

## Setup

### 1. Install the Monkey C extension
- Install the Garmin Monkey C extension in Cursor or VS Code
- If not in the marketplace, download the `.vsix` from the VS Code Marketplace and install via `Extensions: Install from VSIX...`
- Run `Monkey C: Verify Installation` — this installs the SDK and prompts you to download API levels and devices

### 2. Download SDK components
In the Connect IQ SDK Manager that opens:
- **SDK tab** → download **API level 3.3**
- **Devices tab** → download **Forerunner 245 Music**

### 3. Install Java
The Monkey C compiler requires Java:
```bash
brew install --cask temurin
```

### 4. Generate developer key (one-time)
```bash
mkdir -p ~/Library/Application\ Support/Garmin/ConnectIQ
cd ~/Library/Application\ Support/Garmin/ConnectIQ
openssl genrsa -out developer_key 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key -out developer_key.der -nocrypt
```

### 5. Workspace settings
Create `.vscode/settings.json` in the project root (already present):
```json
{
  "monkeyC.developerKeyPath": "/Users/<you>/Library/Application Support/Garmin/ConnectIQ/developer_key.der",
  "workbench.editorAssociations": { "**/manifest.xml": "default" }
}
```
The key path must point to `developer_key.der`. The extension scans the workspace parent folder for key files — keep unrelated Garmin files (sdkmanager launchers etc.) out of the project folder and its parent.

### 6. Daily workflow — three scripts at project root

**Simulate (test in simulator):**
```bash
./sim.sh
```
Builds debug, kills any old simulator, launches it and loads the app.
In the simulator: **Settings → Set Position** → `53.2991, -8.7492` → OK to get GPS.

**Deploy to watch:**
```bash
./build-watch.sh   # compiles release .prg
./deploy.sh        # kills Garmin Express, launches OpenMTP
```
In OpenMTP: right panel → navigate to `GARMIN/APPS/` → drag `bin/AthenryGolf.prg` in.
Unplug watch, wait 10 seconds, then: Hold UP → Activities & Apps → Athenry Golf.

**Watch must be in MTP mode** for OpenMTP to see it:
`Settings → System → USB Mode → MTP`

**To exit the app on the watch:** press BACK 4 times → START to confirm exit.
If completely stuck: hold LIGHT for 15–20 seconds → force restart.

## ⚠️ CALIBRATE THE COURSE DATA FIRST

The coordinates in `GolfModel.mc` are **placeholders**.

### How to walk the greens (30 min, early morning)
For each of the 18 holes:
1. Walk to the **front edge** of the green
2. Open Google Maps, long-press your location → copy coordinates
3. Walk to the **middle** (pin position), repeat
4. Walk to the **back edge**, repeat
5. Paste into the `_holes` array in `GolfModel.mc`

Format per hole (already set up in code):
```
[par, strokeIndex, frontLat, frontLon, midLat, midLon, backLat, backLon]
```

### Tip: Use a free GPS app instead
Apps like **"GPS Fields Area Measure"** or **"GPS Coordinates"** (iOS free)
let you log waypoints easily. Walk the 18 greens, export as CSV, paste in.

## Shot distance tracker
1. Stand at tee/where you hit from
2. Press LIGHT to mark your position (works from any screen)
3. Walk to where the ball landed
4. Press LIGHT again → jumps to Shot view showing distance in yards

## Future: API version
To add dynamic course selection, sign up at https://golfcourseapi.com (free tier, 300 req/day).
The architecture is ready - replace the `_holes` array population with an HTTP call in `onStart()`.
Keep the hardcoded Athenry data as fallback if GPS/Bluetooth isn't available.
