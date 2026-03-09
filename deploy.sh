#!/bin/bash
# Deploy game-a-day: run tests, export to HTML/JS, and push to GitHub
set -e

cd /home/pi/Development/game-a-day

# Initialize deployment log for error diagnostics
DEPLOY_LOG="deploy.log"
{
  echo "=== Game-a-Day Deployment ==="
  echo "Start: $(date -Iseconds)"
  echo "Working directory: $(pwd)"
  echo "Git branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
  echo ""
} > "$DEPLOY_LOG"

# Trap errors and log them
trap 'echo "DEPLOY ERROR at line $LINENO: $BASH_COMMAND" | tee -a "$DEPLOY_LOG"; exit 1' ERR

TODAY=$(date +%Y-%m-%d)
GAME_DIR="games/$TODAY"

# Auto-initialize today's game if missing (idempotent)
echo "Initializing today's game..." | tee -a "$DEPLOY_LOG"
python3 tools/auto-init-daily-game.py "$TODAY" >> "$DEPLOY_LOG" 2>&1 || true

if [ ! -f "$GAME_DIR/game.p8" ]; then
    echo "No game found at $GAME_DIR/game.p8" | tee -a "$DEPLOY_LOG"
    exit 0  # Not an error — game may not be ready yet
fi

# Run tests on all games
echo "Running game tests..." | tee -a "$DEPLOY_LOG"
if python3 tools/run-game-tests.py >> "$DEPLOY_LOG" 2>&1; then
    echo "✅ All tests passed" | tee -a "$DEPLOY_LOG"
else
    if [ "$1" != "--ignore-failures" ]; then
        echo "❌ Test failures detected. Use --ignore-failures to skip." | tee -a "$DEPLOY_LOG"
        exit 1
    fi
    echo "⚠️  Test failures detected, but --ignore-failures flag used" | tee -a "$DEPLOY_LOG"
fi

# Export to HTML (requires PICO-8)
# pico8 is 0.2.5g which needs version <=41 headers; agents write version 42
if command -v pico8 &>/dev/null; then
    echo "Exporting to HTML..." | tee -a "$DEPLOY_LOG"
    sed -i 's/^version 42$/version 41/' "$GAME_DIR/game.p8"
    pico8 "$GAME_DIR/game.p8" -export "$GAME_DIR/game.html" >> "$DEPLOY_LOG" 2>&1
fi

# Generate game library catalog
echo "Generating game library catalog..." | tee -a "$DEPLOY_LOG"
python3 tools/generate-library.py >> "$DEPLOY_LOG" 2>&1

# Generate daily intelligence report
echo "Generating daily intelligence report..." | tee -a "$DEPLOY_LOG"
python3 tools/daily-intelligence.py --date "$TODAY" >> "$DEPLOY_LOG" 2>&1 || true

# Sync all games to pixel-dashboard
SYNC_SCRIPT="/home/pi/Development/pixel-dashboard/scripts/sync-games.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    echo "Syncing games to pixel-dashboard..." | tee -a "$DEPLOY_LOG"
    if "$SYNC_SCRIPT" >> "$DEPLOY_LOG" 2>&1; then
        echo "✅ Games synced successfully" | tee -a "$DEPLOY_LOG"
    else
        echo "⚠️  WARNING: Failed to sync games to pixel-dashboard" | tee -a "$DEPLOY_LOG"
        echo "   This may indicate issues with pixel-dashboard build or dependencies" | tee -a "$DEPLOY_LOG"
        echo "   Games will not be available on the web dashboard" | tee -a "$DEPLOY_LOG"
        # Don't exit on failure — game-a-day deployment should still succeed
    fi
else
    echo "⚠️  WARNING: pixel-dashboard sync script not found at $SYNC_SCRIPT" | tee -a "$DEPLOY_LOG"
    echo "   Games will not be synced to the web dashboard" | tee -a "$DEPLOY_LOG"
fi

# Build GitHub Pages site (exports all games to docs/)
echo "Building GitHub Pages site..." | tee -a "$DEPLOY_LOG"
scripts/build-site.sh >> "$DEPLOY_LOG" 2>&1

# Push to GitHub
echo "Pushing to GitHub..." | tee -a "$DEPLOY_LOG"
git add -A >> "$DEPLOY_LOG" 2>&1
git commit -m "Game of the day: $TODAY" >> "$DEPLOY_LOG" 2>&1 || true  # ok if nothing to commit
git push origin main >> "$DEPLOY_LOG" 2>&1

# Log successful completion
{
  echo ""
  echo "=== Deployment Complete ==="
  echo "End: $(date -Iseconds)"
  echo "Status: SUCCESS"
} >> "$DEPLOY_LOG"

# Output final status
echo "✅ Deployment completed successfully"
