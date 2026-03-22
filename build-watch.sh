#!/bin/zsh
# Build release .prg for deployment to watch
# Output: AthenryGolf.prg in project root

set -e

SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
DEVICE="fr245m"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$PROJECT_DIR"

echo "── Building release AthenryGolf.prg ──"
"$SDK/bin/monkeyc" \
  -o "AthenryGolf.prg" \
  -f monkey.jungle \
  -y "$KEY" \
  -d "$DEVICE" \
  -r \
  -w

echo ""
echo "✓ Release build complete → AthenryGolf.prg"
echo "  Run ./deploy.sh to sideload to watch"

