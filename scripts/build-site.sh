#!/bin/bash
# Build GitHub Pages site from exported games
# Copies game.html + game.js into docs/ and generates an index page
set -e

cd "$(dirname "$0")/.."
DOCS_DIR="docs"
GAMES_DIR="games"

# Clean and rebuild
rm -rf "$DOCS_DIR"
mkdir -p "$DOCS_DIR"

# Collect dates with valid exports
dates=()
for day_dir in "$GAMES_DIR"/*/; do
  date=$(basename "$day_dir")
  if [ -f "$day_dir/game.html" ] && [ -f "$day_dir/game.js" ]; then
    mkdir -p "$DOCS_DIR/$date"
    cp "$day_dir/game.html" "$day_dir/game.js" "$DOCS_DIR/$date/"
    # Also create an index.html that redirects to game.html for clean URLs
    cat > "$DOCS_DIR/$date/index.html" <<'REDIRECT'
<!DOCTYPE html>
<html><head><meta http-equiv="refresh" content="0;url=game.html"></head></html>
REDIRECT
    dates+=("$date")
  fi
done

# Read metadata for each game
get_title() {
  local meta="$GAMES_DIR/$1/metadata.json"
  if [ -f "$meta" ]; then
    python3 -c "import json; print(json.load(open('$meta')).get('title','Untitled'))" 2>/dev/null || echo "Untitled"
  else
    echo "Untitled"
  fi
}

get_desc() {
  local meta="$GAMES_DIR/$1/metadata.json"
  if [ -f "$meta" ]; then
    python3 -c "import json; print(json.load(open('$meta')).get('description',''))" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

get_genres() {
  local meta="$GAMES_DIR/$1/metadata.json"
  if [ -f "$meta" ]; then
    python3 -c "import json; g=json.load(open('$meta')).get('genres',[]); print(', '.join(g))" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Generate index.html
cat > "$DOCS_DIR/index.html" <<'HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Game a Day - Daily PICO-8 Games</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    background: #1a1a2e;
    color: #e0e0e0;
    min-height: 100vh;
  }
  header {
    text-align: center;
    padding: 2rem 1rem;
    background: linear-gradient(135deg, #16213e, #0f3460);
    border-bottom: 2px solid #e94560;
  }
  h1 { color: #e94560; font-size: 2rem; margin-bottom: 0.3rem; }
  header p { color: #a0a0b0; font-size: 0.95rem; }
  .games {
    max-width: 800px;
    margin: 2rem auto;
    padding: 0 1rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .game-card {
    background: #16213e;
    border-radius: 8px;
    padding: 1.2rem;
    border: 1px solid #2a2a4a;
    transition: border-color 0.2s;
    text-decoration: none;
    color: inherit;
    display: block;
  }
  .game-card:hover { border-color: #e94560; }
  .game-card .date { color: #e94560; font-size: 0.85rem; font-weight: 600; }
  .game-card .title { font-size: 1.3rem; margin: 0.3rem 0; color: #fff; }
  .game-card .desc { color: #a0a0b0; font-size: 0.9rem; margin-bottom: 0.4rem; }
  .game-card .genres { color: #7b68ee; font-size: 0.8rem; }
  .play-btn {
    display: inline-block;
    margin-top: 0.5rem;
    padding: 0.4rem 1rem;
    background: #e94560;
    color: #fff;
    border-radius: 4px;
    font-size: 0.85rem;
    font-weight: 600;
  }
</style>
</head>
<body>
<header>
  <h1>Game a Day</h1>
  <p>A new PICO-8 game every day. Built by AI agents on a Raspberry Pi.</p>
</header>
<div class="games">
HEADER

# Add game cards (newest first)
for (( i=${#dates[@]}-1; i>=0; i-- )); do
  date="${dates[$i]}"
  title=$(get_title "$date")
  desc=$(get_desc "$date")
  genres=$(get_genres "$date")

  cat >> "$DOCS_DIR/index.html" <<CARD
<a href="$date/" class="game-card">
  <div class="date">$date</div>
  <div class="title">$title</div>
  <div class="desc">$desc</div>
  <div class="genres">$genres</div>
  <span class="play-btn">Play</span>
</a>
CARD
done

cat >> "$DOCS_DIR/index.html" <<'FOOTER'
</div>
</body>
</html>
FOOTER

echo "Built site with ${#dates[@]} games in $DOCS_DIR/"
