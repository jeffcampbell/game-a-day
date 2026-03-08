#!/bin/bash
# Deploy game-a-day: run tests, export to HTML/JS, and push to GitHub
set -e

cd /home/pi/Development/game-a-day

TODAY=$(date +%Y-%m-%d)
GAME_DIR="games/$TODAY"

if [ ! -f "$GAME_DIR/game.p8" ]; then
    echo "No game found at $GAME_DIR/game.p8"
    exit 0  # Not an error — game may not be ready yet
fi

# Run tests on all games
echo "Running game tests..."
if python3 tools/run-game-tests.py; then
    echo "✅ All tests passed"
else
    if [ "$1" != "--ignore-failures" ]; then
        echo "❌ Test failures detected. Use --ignore-failures to skip."
        exit 1
    fi
    echo "⚠️  Test failures detected, but --ignore-failures flag used"
fi

# Export to HTML (requires PICO-8)
if command -v pico8 &>/dev/null; then
    pico8 "$GAME_DIR/game.p8" -export "$GAME_DIR/game.html"
fi

# Generate game library catalog
echo "Generating game library catalog..."
python3 tools/generate-library.py

# Sync all games to pixel-dashboard
SYNC_SCRIPT="/home/pi/Development/pixel-dashboard/scripts/sync-games.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    "$SYNC_SCRIPT"
fi

# Push to GitHub
git add -A
git commit -m "Game of the day: $TODAY" || true  # ok if nothing to commit
git push origin main
