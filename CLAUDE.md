# game-a-day: Daily PICO-8 Game Project

## Goal

Build one new PICO-8 game every day. Each game is a complete, playable experience
stored in `games/YYYY-MM-DD/`.

## Daily Game Convention — THIS IS THE #1 PRIORITY

**The game is the product. Everything else is secondary.**

Check `date +%Y-%m-%d` to get today's date, then look for `games/YYYY-MM-DD/`.

- If today's directory does **not** exist → create a new game for today. Pick a fresh
  game concept (don't repeat recent genres — check the last few days' games for
  variety). Create the directory, write `game.p8`, export HTML, and sync to
  pixel-dashboard.
- If today's directory **exists but has no `game.p8`** → build the game.
- If today's directory **exists with `game.p8` that is a skeleton/template** (e.g.
  "Untitled Game", minimal code, no real gameplay) → flesh it out into a real,
  playable, fun game with actual mechanics, sprites, and a win/lose condition.
- If today's directory **exists with a complete game** → check `metadata.json`:
  - If `completion_status` is `"complete"` → the game is done for the day. Do NOT generate
    feature or polish specs. Only accept specs for critical bug fixes and token optimizations.
    At midnight, move on to tomorrow's game.
  - If `completion_status` is `"in-progress"` → improve, fix bugs, or polish the game.
    There is always more polish to do: better sprites, sound effects, difficulty tuning,
    smoother animations, more levels.
- **Never create games for future dates.** Only work on today's game (`date +%Y-%m-%d`).
  A new game starts at midnight, not before.
- **Never modify previous days' games** unless explicitly asked. **Exception:** Token limit
  violations (games exceeding 8192 tokens) and other functionality-blocking bugs are justified
  exceptions. These make a game non-shippable and should be fixed immediately.
- **Never propose tooling, infrastructure, library systems, or meta-features.**
  The game comes first — always. If you run out of ideas, polish the game more.

## Sharing Games

**Always push to GitHub after merging.** Part of the fun is sharing games with others.
The orchestrator handles this automatically via the `push_after_merge` flag in
projects.json, but if you're working manually, always `git push origin main` after
committing a game.

## Directory Structure

```
games/
  2026-02-25/
    game.p8          # PICO-8 source cartridge
    assessment.md    # Tester's notes (persists across iterations)
    game.html        # Exported HTML player (committed alongside .p8)
    game.js          # Exported JS runtime (committed alongside .p8)
  2026-02-26/
    ...
```

## PICO-8 Constraints

- **Display**: 128x128 pixels
- **Colors**: 16 fixed palette (0-15)
- **Language**: Lua (PICO-8 dialect)
- **Token limit**: 8192 tokens (use `python3 tools/p8tokens.py <game.p8>` to count)
- **Sprite sheet**: 128 8x8 sprites (shared with map)
- **Map**: 128x32 tiles (shares memory with bottom half of sprite sheet)
- **Sound**: 64 SFX slots, 64 music patterns
- **Input**: 6 buttons per player (see below)

## Button Reference

| Button | Player 1 Key | Bitmask | btn() index |
|--------|-------------|---------|-------------|
| Left   | Arrow Left  | 1       | 0           |
| Right  | Arrow Right | 2       | 1           |
| Up     | Arrow Up    | 4       | 2           |
| Down   | Arrow Down  | 8       | 3           |
| O      | Z / C       | 16      | 4           |
| X      | X / V       | 32      | 5           |

## Required: Cartridge Sections

Every .p8 file MUST include these sections for valid cartridge format and HTML export:

```
pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- game code here
__gfx__
-- sprite data (can be minimal/empty rows of 0s)
__label__
-- 128x128 label image (required for HTML export)
-- minimum: 128 rows of 128 hex digits (0-f), one per pixel
```

The `__label__` section is CRITICAL — without it, `pico8 -export` will fail.
A minimal label can be generated programmatically (e.g., fill with the game title).

## HTML Export

After writing game.p8, always export to HTML/JS:
```bash
pico8 games/YYYY-MM-DD/game.p8 -export games/YYYY-MM-DD/game.html
```
This creates `game.html` + `game.js`. Both must be committed alongside `game.p8`.

**Note on Headless Environments**: The `pico8 -export` command requires X11 (display server).
In headless Linux environments (e.g., CI/CD systems, Raspberry Pi without display):
- The game.p8 is fully functional and correct
- game.html/game.js will be stubs/placeholders if export fails due to missing X11
- The game can still be tested interactively via `tools/run-interactive-test.py`
- Full HTML export should be performed on a system with X11 display available
- Alternatively, use Docker with X11 forwarding: `docker run --display=host pico8 games/YYYY-MM-DD/game.p8 -export ...`

After exporting (or when export is not available), sync games to the pixel-dashboard for embedding:
```bash
/home/pi/Development/pixel-dashboard/scripts/sync-games.sh
```
This copies all exported games into `pixel-dashboard/public/game/YYYY-MM-DD/` and
generates a `manifest.json` for the dashboard's Game panel.

## Required Architecture: State Machine

Every game MUST use the state machine pattern:

```lua
state = "menu"  -- menu -> play -> gameover

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  cls()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end
```

## Required: Test Infrastructure

Every game MUST include the test infrastructure at the top of the file:

```lua
-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end
```

Then use `test_input()` instead of `btn()` for all input reads, and add `_log()` calls
at every state transition and significant game event.

## Logging Guidelines

Add `_log()` calls for:
- State transitions: `_log("state:play")`
- Score changes: `_log("score:"..score)`
- Player actions: `_log("jump"), _log("shoot")`
- Game events: `_log("enemy_spawn"), _log("level_up")`
- Win/lose: `_log("gameover:win"), _log("gameover:lose")`

## Code Style

- Keep logic and rendering separated (update functions vs draw functions)
- Use meaningful variable names
- Keep functions focused and short
- Comment non-obvious game mechanics

## PICO-8 API Quick Reference

### Drawing
- `cls(col)` — clear screen
- `pset(x,y,col)` — set pixel
- `line(x0,y0,x1,y1,col)` — draw line
- `rect(x0,y0,x1,y1,col)` / `rectfill(...)` — rectangle
- `circ(x,y,r,col)` / `circfill(...)` — circle
- `spr(n,x,y,[w,h],[flip_x],[flip_y])` — draw sprite
- `sspr(sx,sy,sw,sh,dx,dy,[dw,dh],[flip_x],[flip_y])` — stretch sprite
- `map(cel_x,cel_y,sx,sy,cel_w,cel_h)` — draw map
- `print(str,x,y,col)` — print text
- `camera(x,y)` — set camera offset

### Input
- `btn(i,[p])` — button state (bitfield or indexed)
- `btnp(i,[p])` — button pressed this frame

### Math
- `rnd(x)` — random 0 to x (exclusive)
- `flr(x)` — floor
- `ceil(x)` — ceiling
- `abs(x)`, `sgn(x)`, `min(a,b)`, `max(a,b)`, `mid(a,b,c)`
- `sin(x)`, `cos(x)`, `atan2(dx,dy)` — PICO-8 uses turns (0-1), not radians
- `sqrt(x)`

### Memory / State
- `mget(x,y)` / `mset(x,y,v)` — map tile get/set
- `fget(n,[f])` / `fset(n,[f],v)` — sprite flag get/set
- `peek(addr)` / `poke(addr,val)` — memory access

### Sound
- `sfx(n,[channel],[offset])` — play sound effect
- `music(n,[fade],[mask])` — play music pattern

### System
- `t()` / `time()` — seconds since game start
- `stat(n)` — system stats

## Game Library System

The game library system provides comprehensive discovery, indexing, and visualization
of all PICO-8 games created in the project.

### Library Components

1. **Game Catalog (`catalog.json`)**
   - Master index of all games with aggregated metadata
   - Generated automatically by deploy script
   - Located at project root
   - Contains: title, description, genres, difficulty, playtime, completion rates, analytics

2. **Library Generator (`tools/generate-library.py`)**
   ```bash
   python3 tools/generate-library.py
   ```
   - Scans all `games/YYYY-MM-DD/` directories
   - Aggregates metadata.json, test-report.json, session data
   - Generates catalog.json with complete game index
   - Validates all data before output

3. **Web Discovery Interface (`tools/library-web-server.py`)**
   ```bash
   python3 tools/library-web-server.py [--port 8000]
   ```
   - Launches interactive web browser for game discovery
   - Supports filtering by genre, difficulty, date range, status
   - Provides sorting by date, title, difficulty, completion rate, sessions
   - Shows game statistics dashboard with charts and metrics
   - Available at: `http://127.0.0.1:8000/`

### Catalog.json Format

The `catalog.json` file contains all indexed games in this format:

```json
{
  "generated": "ISO8601_timestamp",
  "version": "1.0",
  "total_games": 42,
  "statistics": {
    "total_games": 42,
    "total_sessions_recorded": 250,
    "average_completion_rate": 0.65,
    "difficulty_stats": {
      "min": 1,
      "max": 5,
      "average": 3.2
    },
    "playtime_stats": {
      "min": 2,
      "max": 15,
      "average": 5.5,
      "median": 5
    },
    "genre_distribution": {
      "action": 12,
      "puzzle": 15,
      "adventure": 8
    },
    "completion_status_breakdown": {
      "in-progress": 20,
      "complete": 15,
      "polished": 7
    }
  },
  "games": [
    {
      "date": "2026-03-07",
      "title": "Game Title",
      "description": "Game description...",
      "genres": ["action", "arcade"],
      "difficulty": 3,
      "playtime_minutes": 5,
      "completion_status": "in-progress",
      "test_status": "PASS",
      "state_transitions": ["menu", "play", "gameover"],
      "logs_captured": 127,
      "sessions_recorded": 12,
      "completion_rate": 0.75,
      "assessment_status": "active",
      "target_audience": "general",
      "token_count": 7500,
      "sprite_count": 15,
      "sound_count": 8
    }
  ]
}
```

### Data Sources

The library system integrates data from multiple sources:

- **Metadata** (`metadata.json`): Title, description, genres, difficulty, playtime
- **Test Reports** (`test-report.json`): Test status, state transitions, logs captured
- **Sessions** (`session_*.json`): Recorded gameplay data for analytics
- **Assessment** (`assessment.md`): Assessment status and notes

### Integration with Deploy Pipeline

The deploy.sh automatically generates catalog.json after exporting games:
```bash
python3 tools/generate-library.py
```

This ensures the catalog is always up-to-date with the latest games.

### Statistics Dashboard

The web interface provides comprehensive statistics:
- Total games created and sessions recorded
- Genre distribution (pie chart)
- Difficulty distribution (bar chart)
- Completion status breakdown
- Playtime statistics (min, max, average, median)

### Usage Examples

**Generate/update catalog:**
```bash
python3 tools/generate-library.py
```

**Launch discovery interface:**
```bash
python3 tools/library-web-server.py --port 8000
# Open http://127.0.0.1:8000/ in browser
```

**Query catalog via API:**
```bash
# Get all games
curl http://127.0.0.1:8000/api/catalog

# Filter by genre
curl "http://127.0.0.1:8000/api/catalog?genre=action"

# Filter by difficulty
curl "http://127.0.0.1:8000/api/catalog?difficulty_min=3&difficulty_max=5"

# Sort by completion rate
curl "http://127.0.0.1:8000/api/catalog?sort=completion_rate&reverse=true"
```

## Batch Metadata Initializer

The batch metadata initializer tool automatically generates metadata.json files for all games
that lack them, by analyzing game.p8 files and intelligently inferring metadata.

### Usage

```bash
# Preview suggested metadata (dry-run, no files created)
python3 tools/init-game-metadata.py --dry-run

# Create metadata with user confirmation
python3 tools/init-game-metadata.py

# Create metadata automatically without confirmation
python3 tools/init-game-metadata.py --auto
```

### How It Works

1. **Game Discovery**: Scans all `games/YYYY-MM-DD/` directories and finds games without `metadata.json`
2. **Code Analysis**:
   - Extracts title from first comment in game code (or uses date fallback)
   - Detects genres by analyzing code for keywords (jump, dodge, puzzle, etc.)
   - Estimates difficulty based on token count, sprite usage, and advanced features
   - Counts tokens, sprites, and sounds using existing analysis tools
3. **Description Generation**: Creates game description from detected mechanics and genres
4. **Validation**: Ensures all generated metadata passes schema validation
5. **Creation**: Writes metadata.json files for all valid games
6. **Catalog Generation**: Runs `generate-library.py` to create/update `catalog.json`

### Detected Genres

The tool recognizes these keywords to auto-detect genres:

- **action**: jump, dodge, enemy, shoot, attack, collision, hit, damage
- **puzzle**: match, piece, block, grid, solve, logic, rotate
- **adventure**: explore, map, world, quest, discover, item, inventory
- **strategy**: turn, ai, bot, pathfind, move, plan
- **rhythm**: beat, music, tempo, sync, dance
- **rpg**: player, level, exp, stat, character, hp, equip
- **sports**: ball, game, score, race, compete, team
- **educational**: learn, teach, quiz, count, letter

### Output

The tool generates metadata with:

- **title**: Extracted from first code comment, or game date
- **description**: Generated from detected mechanics and genres
- **genres**: Auto-detected from code analysis (1-2 genres)
- **difficulty**: Estimated from code complexity (1-5 scale)
- **token_count**: Extracted via p8tokens.py
- **sprite_count**: Count of non-zero sprites in __gfx__
- **sound_count**: Count of non-zero sounds in __sfx__
- **completion_status**: Default "in-progress"
- **target_audience**: Default "general"
- **playtime_minutes**: Default 5 minutes

All metadata is validated against the schema before creation.

## Synthetic Session Data & Analytics

### Important: Distinction Between Real and Synthetic Sessions

The analytics system distinguishes between two types of sessions:

1. **Real Sessions** (from interactive testing)
   - Created via `run-interactive-test.py --record`
   - Contain actual user/tester interactions
   - Are NOT marked with `is_synthetic: true`
   - Should be used in production analytics

2. **Synthetic Sessions** (from `collect-playtests.py`)
   - Artificially generated with predefined button patterns
   - Simulated logs and gameplay events
   - Marked with `is_synthetic: true` in JSON
   - Useful for testing/demo purposes only

### Synthetic Session Handling in Analytics

The `analytics_engine.py` by default **EXCLUDES synthetic sessions** from all metrics calculations.
This is intentional to prevent artificially generated data from contaminating real game metrics.

**Key behaviors:**
- `find_sessions()` filters out synthetic sessions by default
- A game with only synthetic sessions will have `has_sessions: false`
- Only games with real sessions (is_synthetic: false or missing) contribute to metrics
- To include synthetic sessions for testing, use `find_sessions(game_dir, include_synthetic=True)`

**Frame Rate Calculation:**
- Expected playtime is calculated at 60fps: `playtime_minutes * 60 * 60`
- For a 5-minute game: 5 * 60 * 60 = 18,000 frames
- Duration metrics compare actual session length to this expected playtime

### Using Synthetic Data for Testing

The `collect-playtests.py` tool is useful for:
- Testing the analytics pipeline without real playtesting
- Generating sample catalog entries for UI testing
- Demonstrating game metrics in development

**NEVER** mix synthetic sessions with real playtest data in production.
Real analytics must be based only on genuine user interactions.
