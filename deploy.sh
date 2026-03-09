#!/bin/bash
# Deploy game-a-day: run tests, export to HTML/JS, and push to GitHub
set -e

cd /home/pi/Development/game-a-day

TODAY=$(date +%Y-%m-%d)
GAME_DIR="games/$TODAY"

# Auto-initialize today's game if missing (idempotent)
python3 tools/auto-init-daily-game.py "$TODAY" || true

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
# pico8 is 0.2.5g which needs version <=41 headers; agents write version 42
if command -v pico8 &>/dev/null; then
    sed -i 's/^version 42$/version 41/' "$GAME_DIR/game.p8"
    pico8 "$GAME_DIR/game.p8" -export "$GAME_DIR/game.html"
fi

# Generate game library catalog
echo "Generating game library catalog..."
python3 tools/generate-library.py

# Generate daily intelligence report
echo "Generating daily intelligence report..."
python3 tools/daily-intelligence.py --date "$TODAY" || true

# Sync all games to pixel-dashboard
SYNC_SCRIPT="/home/pi/Development/pixel-dashboard/scripts/sync-games.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    echo "Syncing games to pixel-dashboard..."
    if "$SYNC_SCRIPT"; then
        echo "✅ Games synced successfully"
    else
        echo "⚠️  WARNING: Failed to sync games to pixel-dashboard"
        echo "   This may indicate issues with pixel-dashboard build or dependencies"
        echo "   Games will not be available on the web dashboard"
        # Don't exit on failure — game-a-day deployment should still succeed
    fi
else
    echo "⚠️  WARNING: pixel-dashboard sync script not found at $SYNC_SCRIPT"
    echo "   Games will not be synced to the web dashboard"
fi

# Build GitHub Pages site (exports all games to docs/)
echo "Building GitHub Pages site..."
scripts/build-site.sh

# Push to GitHub
git add -A
git commit -m "Game of the day: $TODAY" || true  # ok if nothing to commit
git push origin main
