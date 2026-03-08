#!/usr/bin/env python3
"""
Bootstrap tool for creating new PICO-8 games with required boilerplate.

Usage:
  python3 tools/bootstrap-game.py [YYYY-MM-DD]

If no date is provided, uses today's date.
"""

import sys
import os
from datetime import datetime, timedelta
import os.path


def parse_date(date_str=None):
    """Parse date string or return today's date."""
    if date_str is None:
        return datetime.now().date()

    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        print(f"Error: Invalid date format '{date_str}'. Use YYYY-MM-DD.", file=sys.stderr)
        sys.exit(1)


def generate_lua_boilerplate(game_title, game_date):
    """Generate the Lua boilerplate code for a PICO-8 game."""
    code = f"""-- {game_title}
-- {game_date}

testmode=false
test_log={{}}
test_inputs={{}}
test_input_idx=0

function _log(msg)
 if testmode then add(test_log,msg) end
end

function _capture()
 if testmode then add(test_log,"SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
 if testmode and test_input_idx<#test_inputs then
  test_input_idx+=1
  return test_inputs[test_input_idx] or 0
 end
 return btn()
end

state="menu"

function _init()
end

function _update()
 if state=="menu" then update_menu()
 elseif state=="play" then update_play()
 elseif state=="gameover" then update_gameover()
 end
end

function _draw()
 cls()
 if state=="menu" then draw_menu()
 elseif state=="play" then draw_play()
 elseif state=="gameover" then draw_gameover()
 end
end

function update_menu()
end

function draw_menu()
end

function update_play()
end

function draw_play()
end

function update_gameover()
end

function draw_gameover()
end
"""
    return code


def generate_label(game_title):
    """Generate a minimal 128x128 label section with game title."""
    # Create a label with border and title text in the center
    # 128 rows of 128 hex digits each
    lines = []

    # Top border/padding (mostly 1s)
    for i in range(50):
        lines.append("1" * 128)

    # Center area with title (approximate)
    title_hex = "".join(format(ord(c), 'x') for c in game_title[:20].ljust(20))
    title_display = "a" * 96 + "1" * 32

    for i in range(28):
        lines.append("1" * 12 + "a" * 104 + "1" * 12)

    # Bottom border/padding
    for i in range(50):
        lines.append("1" * 128)

    return "\n".join(lines)


def generate_gfx_section():
    """Generate blank sprite sheet section (128 rows of 128 hex 0s)."""
    # Each row is 128 hex digits (128 pixels wide)
    return "\n".join(["0" * 128 for _ in range(128)])


def generate_p8_file(game_title, game_date):
    """Generate complete .p8 cartridge file content."""
    lua_code = generate_lua_boilerplate(game_title, game_date)
    gfx_section = generate_gfx_section()
    label_section = generate_label(game_title)

    content = f"""pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
{lua_code}
__gfx__
{gfx_section}
__label__
{label_section}
__sfx__
"""
    return content


def generate_assessment_template():
    """Generate assessment.md template for tester notes."""
    return """# Assessment Notes

Date:
Tester:

## Gameplay
- [ ] Game launches without errors
- [ ] Main menu is functional
- [ ] Game state transitions work
- [ ] Game over state works

## Controls
- [ ] Button inputs are responsive
- [ ] Menu navigation works

## Performance
- [ ] Game runs at smooth framerate
- [ ] No lag or stuttering

## Code Quality
- [ ] Game compiles without syntax errors
- [ ] Token count is reasonable
- [ ] Code follows project style guide

## Notes
(Add any additional observations here)
"""


def bootstrap_game(date_str=None):
    """Bootstrap a new game directory and files."""
    game_date = parse_date(date_str)
    date_folder = game_date.strftime("%Y-%m-%d")
    game_title = f"untitled game"

    # Create game directory
    game_dir = os.path.join("games", date_folder)
    os.makedirs(game_dir, exist_ok=True)

    # Generate game.p8
    p8_path = os.path.join(game_dir, "game.p8")
    p8_content = generate_p8_file(game_title, date_folder)

    with open(p8_path, "w") as f:
        f.write(p8_content)

    # Generate assessment.md
    assessment_path = os.path.join(game_dir, "assessment.md")
    assessment_content = generate_assessment_template()

    with open(assessment_path, "w") as f:
        f.write(assessment_content)

    # Output success message
    print(f"✓ Created {game_dir}")
    print(f"  - {p8_path}")
    print(f"  - {assessment_path}")

    return game_dir


if __name__ == "__main__":
    date_arg = sys.argv[1] if len(sys.argv) > 1 else None
    result_dir = bootstrap_game(date_arg)
    sys.exit(0)
