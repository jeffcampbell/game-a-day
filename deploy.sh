#!/bin/bash
# Deploy game-a-day: export to HTML/JS and push to GitHub
set -e

cd /home/pi/Development/game-a-day

TODAY=$(date +%Y-%m-%d)
GAME_DIR="games/$TODAY"

if [ ! -f "$GAME_DIR/game.p8" ]; then
    echo "No game found at $GAME_DIR/game.p8"
    exit 0  # Not an error — game may not be ready yet
fi

# Export to HTML (requires PICO-8)
if command -v pico8 &>/dev/null; then
    pico8 -x "$GAME_DIR/game.p8" -export "$GAME_DIR/game.html"
fi

# Push to GitHub
git add -A
git commit -m "Game of the day: $TODAY" || true  # ok if nothing to commit
git push origin main
