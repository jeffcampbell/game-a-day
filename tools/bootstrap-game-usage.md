# Bootstrap Game Tool

A command-line tool to bootstrap new PICO-8 games with required boilerplate code.

## Purpose

The `bootstrap-game.py` tool reduces setup friction when creating new games for the game-a-day project. It automatically generates:

- A valid PICO-8 cartridge file (`.p8`) with required boilerplate
- Test infrastructure for automated testing
- State machine pattern for game flow
- Assessment template for tester notes

## Usage

### Basic Usage

Bootstrap a game with today's date:

```bash
python3 tools/bootstrap-game.py
```

### With Specific Date

Bootstrap a game with a specific date:

```bash
python3 tools/bootstrap-game.py 2026-03-06
```

Date format: `YYYY-MM-DD`

## Generated Files

For a date like `2026-03-06`, the tool creates:

```
games/2026-03-06/
├── game.p8              # PICO-8 cartridge (main game file)
└── assessment.md        # Template for tester notes
```

### game.p8 Structure

The generated cartridge includes:

#### __lua__ Section
- **Test Infrastructure**: Functions for logging game events and simulating input
  - `testmode`: Boolean flag for test mode
  - `test_log`: Table to store logged messages
  - `test_inputs`: Table for simulating button presses in tests
  - `_log(msg)`: Log game events
  - `_capture()`: Capture screen state for debugging
  - `test_input(b)`: Get input for testing or live play

- **State Machine**: Default states for basic game flow
  - `state` variable tracking current state
  - `_init()`: Initialization hook
  - `_update()`: Dispatcher for state-specific updates
  - `_draw()`: Dispatcher for state-specific rendering
  - Three default states: `menu`, `play`, `gameover`
  - Update/draw functions for each state (ready to implement)

- **Game Title Comment**: Identifies the game and date

#### __gfx__ Section
- 128x128 sprite sheet filled with zeros (ready for sprite design)
- 128 rows × 128 pixels per row = 16,384 total sprite pixels

#### __label__ Section
- 128×128 pixel label image for the cartridge thumbnail
- Filled with appropriate colors ready for customization

## Token Count

The generated boilerplate uses approximately **137 tokens** out of PICO-8's 8192 limit, leaving **8,055 tokens** for actual game logic.

Token breakdown:
- Test infrastructure: ~40 tokens
- State machine pattern: ~80 tokens
- Default state functions: ~17 tokens

## Getting Started

After bootstrapping a new game:

1. **Open the cartridge**: Edit `games/YYYY-MM-DD/game.p8` in PICO-8
2. **Implement game logic**: Add code to the default state functions:
   - `update_menu()`: Handle menu input and transitions
   - `draw_menu()`: Render the menu screen
   - `update_play()`: Update game state during gameplay
   - `draw_play()`: Render the game screen
   - `update_gameover()`: Handle game-over state
   - `draw_gameover()`: Render game-over screen
3. **Add sprites**: Design sprites in the sprite editor
4. **Add sounds**: Create sound effects in the music editor
5. **Export to HTML**: Run `pico8 games/YYYY-MM-DD/game.p8 -export` to generate HTML/JS files
6. **Test with automation**: Use test infrastructure to verify game logic

## Test Infrastructure Example

To use the test infrastructure:

```lua
-- In your game code
_log("player:jumped")
_log("score:" .. score)

-- Run game in test mode
testmode = true
test_inputs = {16, 16, 0, 0}  -- Simulate button presses (O button = 16)
test_input_idx = 0

-- After test, check results
for msg in all(test_log) do
  print(msg)
end
```

## Requirements

- Python 3.6+
- No external dependencies (uses only Python stdlib)
- PICO-8 is NOT required to run the tool (pure Python generation)

## Cartridge Format

The generated `.p8` file is compatible with PICO-8 0.2.7+. To export to HTML/JS:

```bash
pico8 games/YYYY-MM-DD/game.p8 -export games/YYYY-MM-DD/game.html
```

This creates:
- `game.html`: Standalone HTML5 player
- `game.js`: JavaScript runtime

Both files should be committed alongside `game.p8`.

## Validation

The tool automatically:
- ✓ Creates valid PICO-8 cartridge format
- ✓ Generates exactly 128×128 sprite sheet
- ✓ Generates exactly 128×128 label image
- ✓ Includes required test infrastructure
- ✓ Implements state machine pattern
- ✓ Follows project code style
- ✓ Leaves minimal boilerplate token usage

## Notes

- The game title defaults to "untitled game" — update it in the comment at the top of `game.p8`
- Comments and blank lines do not count toward the token limit
- The state machine can be extended with additional states by following the existing pattern
- The test infrastructure is optional but recommended for game verification
