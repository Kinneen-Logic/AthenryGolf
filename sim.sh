#!/bin/zsh
# First-time setup: builds, starts simulator, loads app.
# After exiting the app, just run: ./run.sh

set -e

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
PRG="AthenryGolf.prg"
DEVICE="fr245m"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$PROJECT_DIR"

echo "── Building $PRG ──"
"$SDK/bin/monkeyc" \
  -o "$PRG" \
  -f monkey.jungle \
  -y "$KEY" \
  -d "$DEVICE" \
  -w

echo "── Killing old simulator ──"
pkill -9 simulator 2>/dev/null || true
pkill -9 monkeydo 2>/dev/null || true
sleep 1

echo "── Launching simulator ──"
open "$SDK/bin/ConnectIQ.app"
sleep 6

echo "── Loading app ──"
"$SDK/bin/monkeydo" "$PRG" "$DEVICE" &
MONKEYDO_PID=$!

echo ""
echo "✓ App running (PID $MONKEYDO_PID)"
echo "  → Set GPS: Settings → Set Position → 53.299100, -8.749200"
echo "  → After exiting app, reload with: ./run.sh"
echo ""

wait $MONKEYDO_PID 2>/dev/null
