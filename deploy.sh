#!/bin/zsh
# ─────────────────────────────────────────────────────────────
#  deploy.sh — Sideload AthenryGolf to Forerunner 245 Music
#
#  Usage:
#    chmod +x deploy.sh   (first time only)
#    ./deploy.sh
#
#  What it does:
#    1. Kills Garmin Express
#    2. Waits for watch to be detected
#    3. Launches OpenMTP — drag AthenryGolf.prg to GARMIN/APPS/
#
#  Note: libmtp cannot detect the FR245M (product ID 0x4c05 not in its
#  database). OpenMTP is the only working deploy path on macOS.
# ─────────────────────────────────────────────────────────────

set -e

PRG="bin/AthenryGolf.prg"

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BLUE}  Athenry Golf → FR245M Deploy Script  ${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Step 1: Check .prg exists ─────────────────────────────────
if [ ! -f "$PRG" ]; then
    echo "${RED}✗ $PRG not found — build first (Monkey C: Build for Device)${NC}"
    exit 1
fi
ABS_PRG="$(cd "$(dirname "$PRG")" && pwd)/$(basename "$PRG")"
echo "${GREEN}✓ Found $PRG${NC}"

# ── Step 2: Kill Garmin Express ───────────────────────────────
echo "\n${YELLOW}→ Killing Garmin Express...${NC}"
pkill -9 -f "Garmin Express" 2>/dev/null && echo "${GREEN}✓ Killed${NC}" || echo "  (was not running)"
pkill -9 -f "GarminExpress" 2>/dev/null || true
sleep 1

# ── Step 3: Wait for watch ────────────────────────────────────
echo "\n${YELLOW}→ Checking for watch...${NC}"
ATTEMPTS=0
while ! ioreg -p IOUSB -l -w 0 2>/dev/null | grep -q "idVendor.*2334"; do
    if [ $ATTEMPTS -eq 0 ]; then
        echo "  Plug in your Forerunner 245 Music..."
    fi
    sleep 2
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ $ATTEMPTS -gt 15 ]; then
        echo "${RED}✗ Watch not detected after 30s — check cable${NC}"
        exit 1
    fi
    printf "."
done
echo "${GREEN}✓ Watch detected (vendor ID 2334)${NC}"

# ── Step 4: Launch OpenMTP ────────────────────────────────────
echo ""
echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${YELLOW}  Launching OpenMTP...                  ${NC}"
echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if open -a OpenMTP 2>/dev/null; then
    echo "${GREEN}✓ OpenMTP launched${NC}"
    echo ""
    echo "  In the OpenMTP right panel, navigate to ${YELLOW}GARMIN/APPS/${NC}"
    echo "  then drag ${GREEN}AthenryGolf.prg${NC} from your Mac into that folder."
    echo "  (It's at: $ABS_PRG)"
    echo ""
    echo "  Then unplug the watch and wait ~10 seconds."
    echo "  Hold UP → Activities & Apps → Athenry Golf"
else
    echo "${RED}✗ OpenMTP not installed.${NC}"
    echo "  Download: https://openmtp.ganeshrvel.com"
    echo ""
    echo "  File to copy: ${GREEN}$ABS_PRG${NC}"
    echo "  Destination on watch: GARMIN/APPS/AthenryGolf.prg"
fi
