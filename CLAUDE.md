# game-a-day: Daily PICO-8 Game Project

## Goal

Build one new PICO-8 game every day. Each game is a complete, playable experience
stored in `games/YYYY-MM-DD/`.

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
