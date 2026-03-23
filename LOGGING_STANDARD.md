# PICO-8 Game Logging Standard

## Purpose

Establish consistent logging standards across all PICO-8 games to ensure reliable test coverage, session analysis, and performance tracking. This standard enables automated testing, analytics generation, and rapid iteration feedback.

## Minimum Requirements

Every PICO-8 game MUST include:

1. **Test Infrastructure** (required in every game)
   - `testmode` flag for test execution mode
   - `test_log` array to capture logs
   - `test_inputs` array for input replay
   - `_log(msg)` function to emit logs
   - `_capture()` function for screen captures
   - `test_input(b)` function for input handling

2. **Logging Requirements**
   - **Minimum**: 3+ unique log types per game
   - **Recommended**: 5+ unique log types
   - All games must log state transitions
   - All games must log game-over (win/lose/quit)

3. **Standard Log Message Format**
   - Format: `"type:value"` (colon-separated prefix and data)
   - Examples:
     - `"state:menu"` — state transition to menu
     - `"state:play"` — state transition to play
     - `"gameover:win"` — game ended with win
     - `"gameover:lose"` — game ended with loss
     - `"score:1000"` — score changed to 1000
     - `"enemy_spawn:5"` — enemy spawned at position 5
     - `"collision:player_enemy"` — collision event

## Events That MUST Be Logged

### 1. State Transitions (REQUIRED)
Log every state change at the moment it occurs:
```lua
state = "menu"
function update_menu()
  if btnp(4) then
    state = "play"
    _log("state:play")
  end
end
```

### 2. Game Over / Win Condition (REQUIRED)
Log when game ends with specific outcome:
```lua
if score >= winning_score then
  _log("gameover:win")
  state = "gameover"
elseif lives <= 0 then
  _log("gameover:lose")
  state = "gameover"
end
```

### 3. Score Changes (RECOMMENDED)
Log significant score updates:
```lua
if collision_detected then
  score += points
  _log("score:"..score)
end
```

### 4. Player Actions (RECOMMENDED)
Log meaningful player inputs:
```lua
if btnp(4) then
  _log("jump")
  player.vy = -4
end

if btnp(5) then
  _log("shoot")
  spawn_projectile()
end
```

### 5. Game Events (RECOMMENDED)
Log important game mechanics:
```lua
-- Enemy spawn
_log("enemy_spawn")
add(enemies, new_enemy())

-- Collision
if collision(player, enemy) then
  _log("collision:enemy")
  player.health -= 1
end

-- Level progression
if level_complete() then
  _log("level_complete:"..level)
  level += 1
end
```

## Log Type Categories

| Category | Examples | Format |
|----------|----------|--------|
| State Changes | menu, play, pause, gameover, tutorial | `state:<name>` |
| Game Over Reasons | win, lose, quit, time_up | `gameover:<reason>` |
| Score Events | collected, points, money, streak | `<event>:<value>` |
| Player Actions | jump, shoot, dash, attack | `<action>` (or `<action>:<data>`) |
| Collisions | enemy_hit, wall_hit, item_collected | `collision:<type>` or `<event>:<data>` |
| Spawns | enemy_spawn, item_spawn, obstacle | `<event>_spawn` or `<event>:<count>` |
| Progression | level_up, wave_start, boss_encounter | `<event>:<data>` |

## Implementation Examples

### Minimal Game (3 unique log types)
```lua
-- Star Collector: minimal logging
function update_play()
  if collision then
    score += 10
    _log("score:"..score)           -- score change
  end
  if time_left <= 0 then
    _log("gameover:lose")            -- game over
    state = "gameover"
  end
end

-- Sample logs captured: ["state:menu", "state:play", "score:10", "score:20", "gameover:lose"]
-- Unique types: state, score, gameover
```

### Rich Game (7+ unique log types)
```lua
-- Space Shooter: comprehensive logging
if btnp(4) then
  _log("shoot")                     -- action
  spawn_projectile()
end

if collision(projectile, enemy) then
  _log("collision:enemy")           -- collision
  _log("enemy_defeated:"..total_kills)  -- progression
  score += 100
  _log("score:"..score)            -- score change
end

if boss_spawned then
  _log("boss_encounter")            -- game event
end

if time_up then
  _log("gameover:time_up")         -- specific game over reason
end
```

## Testing and Validation

Games are tested using static analysis:

1. **Infrastructure Check**: Verify test functions exist
2. **State Machine Check**: Verify state transitions are logged
3. **Minimum Log Count**: Confirm game produces at least 3+ unique log types
4. **Event Logging**: Verify key game events are captured

Run test suite:
```bash
python3 tools/run-game-tests.py
```

View test report for specific game:
```bash
cat games/YYYY-MM-DD/test-report.json
```

## Token Budget Considerations

Logging is minimal overhead:
- `_log()` call: 2-5 tokens depending on message
- Total logging per game: typically 50-150 tokens (1.5-2% of 8192 limit)

Even games near token limit should have room for essential logging.

## Future Game Template

All new games should follow this pattern:

```lua
pico-8 cartridge
version 42
__lua__

-- Test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- Game code
state = "menu"

function _init()
  _log("state:menu")
end

function _update()
  if state == "menu" then
    if btnp(4) then
      state = "play"
      _log("state:play")
    end
  elseif state == "play" then
    -- game logic here
    -- log key events!
  elseif state == "gameover" then
    if btnp(4) then
      state = "menu"
      _log("state:menu")
    end
  end
end

function _draw()
  cls()
  -- render code
end
```

## Audit Checklist

Before shipping a game, verify:

- [ ] Test infrastructure present (_log, test_input, test_log)
- [ ] State transitions logged (menu → play → gameover)
- [ ] Game over condition logged (win/lose/quit)
- [ ] 3+ unique log types captured
- [ ] No syntax errors in _log() calls
- [ ] All _log() calls use consistent format
- [ ] Token count acceptable (< 8192)

## Compliance Status

As of 2026-03-23:
- **Total Games**: 23
- **Compliant (3+ types)**: 19 games
- **Needs Update (< 3 types)**: 4 games
  - 2026-03-01: 2 types (crash, state)
  - 2026-03-02: 1 type (state only)
  - 2026-03-03: 1 type (state only)
  - 2026-03-06: 2 types (gameover, state)

See `LOGGING_AUDIT.md` for detailed per-game analysis.

## References

- PICO-8 API: `_log()` and test infrastructure in CLAUDE.md
- Test Infrastructure: See required test infrastructure in CLAUDE.md
- Analytics: `tools/analytics_engine.py` uses captured logs for metrics
