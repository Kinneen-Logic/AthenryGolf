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
#    3. Tries mtp-sendfile (libmtp) — fully automated if it works
#    4. Falls back to OpenMTP with the file revealed in Finder
#
#  Prerequisites (run once):
#    brew install libmtp
#    brew install --cask macfuse   (may help libmtp on Apple Silicon)
# ─────────────────────────────────────────────────────────────

set -e

PRG="bin/AthenryGolf.prg"

# The FR245M (vendor 0x091e, product 0x4c05) is not in libmtp's device database.
# libmtp will not detect it. OpenMTP has its own MTP stack and works fine.
# deploy.sh auto-launches OpenMTP as the primary deploy path.

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

# ── Step 4: Try libmtp CLI (automated path) ───────────────────
MTP_OK=0
if command -v mtp-sendfile &> /dev/null; then
    echo "\n${YELLOW}→ Trying automated MTP transfer...${NC}"
    sleep 3   # let MTP stack settle

    if [ -n "$APPS_FOLDER_ID" ]; then
        # Folder ID is known — send directly
        if mtp-sendfile "$PRG" "AthenryGolf.prg" "$APPS_FOLDER_ID" 2>/dev/null; then
            MTP_OK=1
        fi
    else
        # Try to discover the APPS folder ID
        FOLDERS=$(mtp-folders 2>/dev/null || sudo mtp-folders 2>/dev/null || true)
        if [ -n "$FOLDERS" ]; then
            GARMIN_ID=$(echo "$FOLDERS" | grep "Name: GARMIN$" | sed -E 's/.*Folder ID: ([0-9]+).*/\1/')
            APPS_ID=$(echo "$FOLDERS" | grep "Name: APPS$" | grep "Parent: ${GARMIN_ID}" | sed -E 's/.*Folder ID: ([0-9]+).*/\1/')
            if [ -n "$APPS_ID" ]; then
                echo "${GREEN}✓ GARMIN/APPS found (folder ID: $APPS_ID)${NC}"
                echo "  Tip: set APPS_FOLDER_ID=$APPS_ID in deploy.sh to skip discovery next time"
                if mtp-sendfile "$PRG" "AthenryGolf.prg" "$APPS_ID" 2>/dev/null; then
                    MTP_OK=1
                fi
            fi
        fi
    fi
fi

if [ $MTP_OK -eq 1 ]; then
    echo ""
    echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${GREEN}  ✓ Deployed via MTP — done!            ${NC}"
    echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Unplug watch → wait 10s → Hold UP → Activities & Apps → Athenry Golf"
    exit 0
fi

# ── Step 5: OpenMTP fallback ──────────────────────────────────
echo ""
echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${YELLOW}  CLI MTP not available — using OpenMTP ${NC}"
echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Launch OpenMTP
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
