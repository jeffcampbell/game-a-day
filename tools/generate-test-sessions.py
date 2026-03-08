#!/usr/bin/env python3
"""Generate realistic playtest sessions for Cave Escape validation.

Simulates diverse playstyles to validate audio improvements and gameplay balance.
Generates deterministic but realistic game behavior patterns.

Usage:
  python3 tools/generate-test-sessions.py 2026-03-08 [--sessions 10] [--playstyles aggressive careful strategic random passive]
"""

import sys
import json
import os
import random
import argparse
from datetime import datetime
from pathlib import Path

VALID_PLAYSTYLES = {"aggressive", "careful", "strategic", "random", "passive"}


def generate_session(game_date, playstyle, session_num):
    """Generate a realistic game session for a given playstyle.

    Playstyles:
    - aggressive: Fast movement, frequent dashing, risky play (50-70% win rate)
    - careful: Measured movement, strategic dashing, defensive (60-75% win rate)
    - strategic: Planned routes, optimal dash timing (65-80% win rate)
    - random: Unpredictable button inputs (30-50% win rate)
    - passive: Minimal inputs, cautious movement (40-60% win rate)
    """

    # Button bits: left=0, right=1, up=2, down=3, o=4, x=5
    # Values: 0=no input, 1=left, 2=right, 4=up, 8=down, 16=o_button, 32=x_button

    random.seed(hash(f"{game_date}_{playstyle}_{session_num}") % (2**31))

    button_sequence = []
    logs = []

    # Simulate game start (menu → play)
    logs.append("state:menu")

    # Menu navigation (o_button to start)
    for _ in range(random.randint(10, 30)):
        button_sequence.append(0)  # idle
    button_sequence.append(16)  # o_button (select)
    for _ in range(5):
        button_sequence.append(0)  # transition frames

    logs.append("state:play")
    logs.append("level:1")
    logs.append("enemy_spawn:2")

    # Playstyle-specific level 1 behavior
    if playstyle == "aggressive":
        # Fast right movement, frequent dashing
        frames_level1 = random.randint(800, 1200)
        dashes_l1 = random.randint(3, 8)
        win_chance = 0.65

        for i in range(frames_level1):
            if random.random() < 0.7:
                button_sequence.append(2)  # right
            elif random.random() < 0.3:
                button_sequence.append(6)  # right + up
            elif i % 100 < dashes_l1 * 15 and random.random() < 0.4:
                button_sequence.append(32)  # x_button (dash)
                logs.append(f"dash")
            else:
                button_sequence.append(0)

    elif playstyle == "careful":
        # Measured right/up movement, selective dashing
        frames_level1 = random.randint(900, 1300)
        dashes_l1 = random.randint(2, 5)
        win_chance = 0.7

        for i in range(frames_level1):
            if i % 60 < 30:
                button_sequence.append(2)  # right
            elif i % 60 < 50:
                button_sequence.append(6)  # right + up
            elif i % 300 < dashes_l1 * 20 and random.random() < 0.3:
                button_sequence.append(32)  # dash
                logs.append(f"dash")
            else:
                button_sequence.append(0)

    elif playstyle == "strategic":
        # Optimized movement patterns
        frames_level1 = random.randint(800, 1100)
        dashes_l1 = random.randint(2, 4)
        win_chance = 0.75

        for i in range(frames_level1):
            if i % 120 < 60:
                button_sequence.append(2)  # right
            elif i % 120 < 100:
                button_sequence.append(6)  # right + up
            elif i % 400 < dashes_l1 * 30:
                button_sequence.append(32)  # dash when needed
                logs.append(f"dash")
            else:
                button_sequence.append(0)

    elif playstyle == "random":
        # Unpredictable inputs
        frames_level1 = random.randint(700, 1500)
        win_chance = 0.4

        directions = [0, 1, 2, 4, 6, 16, 32]
        for _ in range(frames_level1):
            if random.random() < 0.3:
                button_sequence.append(random.choice(directions))
            else:
                button_sequence.append(0)

    else:  # passive
        # Minimal inputs, cautious movement
        frames_level1 = random.randint(1000, 1400)
        dashes_l1 = random.randint(0, 2)
        win_chance = 0.5

        for i in range(frames_level1):
            if i % 150 < 75:
                button_sequence.append(2)  # right
            elif i % 300 < dashes_l1 * 50 and random.random() < 0.2:
                button_sequence.append(32)  # occasional dash
                logs.append(f"dash")
            else:
                button_sequence.append(0)

    # Level 1 completion
    logs.append("level_complete:1")
    logs.append("level:2")
    logs.append("enemy_spawn:3")

    # 30 frames transition
    for _ in range(30):
        button_sequence.append(0)

    # Level 2 behavior (similar pattern but harder)
    if playstyle == "aggressive":
        frames_level2 = random.randint(600, 1000)
        dashes_l2 = random.randint(4, 10)
    elif playstyle == "careful":
        frames_level2 = random.randint(700, 1100)
        dashes_l2 = random.randint(3, 6)
    elif playstyle == "strategic":
        frames_level2 = random.randint(600, 900)
        dashes_l2 = random.randint(3, 5)
    elif playstyle == "random":
        frames_level2 = random.randint(500, 1200)
        dashes_l2 = random.randint(0, 3)
    else:  # passive
        frames_level2 = random.randint(700, 1100)
        dashes_l2 = random.randint(0, 2)

    for i in range(frames_level2):
        if playstyle == "aggressive":
            if random.random() < 0.75:
                button_sequence.append(2)
            elif random.random() < 0.4:
                button_sequence.append(6)
            elif i % 80 < dashes_l2 * 12 and random.random() < 0.5:
                button_sequence.append(32)
                logs.append(f"dash")
            else:
                button_sequence.append(0)

        elif playstyle == "careful":
            if i % 80 < 40:
                button_sequence.append(2)
            elif i % 80 < 65:
                button_sequence.append(6)
            elif i % 350 < dashes_l2 * 25 and random.random() < 0.35:
                button_sequence.append(32)
                logs.append(f"dash")
            else:
                button_sequence.append(0)

        elif playstyle == "strategic":
            if i % 100 < 50:
                button_sequence.append(2)
            elif i % 100 < 80:
                button_sequence.append(6)
            elif i % 450 < dashes_l2 * 40:
                button_sequence.append(32)
                logs.append(f"dash")
            else:
                button_sequence.append(0)

        elif playstyle == "random":
            directions = [0, 1, 2, 4, 6, 16, 32]
            if random.random() < 0.35:
                button_sequence.append(random.choice(directions))
            else:
                button_sequence.append(0)

        else:  # passive
            if i % 180 < 90:
                button_sequence.append(2)
            elif i % 400 < dashes_l2 * 70 and random.random() < 0.15:
                button_sequence.append(32)
                logs.append(f"dash")
            else:
                button_sequence.append(0)

    # Level 2 completion or failure
    won = random.random() < win_chance

    if won:
        logs.append("portal_reached")
        logs.append("level_complete:2")
        logs.append("gameover:win")
        exit_state = "won"
        # Victory screen frames
        for _ in range(120):
            button_sequence.append(0)
    else:
        logs.append("gameover:lose")
        exit_state = "lost"
        # Game over screen frames
        for _ in range(60):
            button_sequence.append(0)

    # Create session data
    duration_frames = len(button_sequence)
    timestamp = datetime.now().isoformat() + "Z"

    session = {
        "date": game_date,
        "timestamp": timestamp,
        "duration_frames": duration_frames,
        "button_sequence": button_sequence,
        "logs": logs,
        "exit_state": exit_state,
        "playstyle": playstyle,
        "session_number": session_num,
        "is_synthetic": True
    }

    return session


def main():
    """Generate test sessions for validation."""
    parser = argparse.ArgumentParser(
        description="Generate realistic playtest sessions to validate game improvements.",
        epilog="Example: python3 tools/generate-test-sessions.py 2026-03-08 --sessions 5 --playstyles aggressive careful strategic"
    )
    parser.add_argument(
        "game_date",
        help="Game date (YYYY-MM-DD)"
    )
    parser.add_argument(
        "--sessions",
        type=int,
        default=5,
        help="Number of sessions per playstyle (default: 5)"
    )
    parser.add_argument(
        "--playstyles",
        nargs="+",
        default=list(VALID_PLAYSTYLES),
        help="Playstyles to simulate (default: all five)"
    )

    args = parser.parse_args()

    game_date = args.game_date
    num_sessions = args.sessions
    playstyles = args.playstyles

    # Validate playstyles
    for playstyle in playstyles:
        if playstyle not in VALID_PLAYSTYLES:
            print(f"Error: Invalid playstyle '{playstyle}'. Must be one of: {', '.join(sorted(VALID_PLAYSTYLES))}")
            sys.exit(1)

    # Verify game exists
    game_dir = Path(f"games/{game_date}")
    if not game_dir.exists():
        print(f"Error: Game directory {game_dir} does not exist")
        sys.exit(1)

    if not (game_dir / "game.p8").exists():
        print(f"Error: game.p8 not found in {game_dir}")
        sys.exit(1)

    print(f"Generating {num_sessions * len(playstyles)} test sessions for {game_date}...")
    print(f"Playstyles: {', '.join(playstyles)}")

    sessions_generated = 0

    for playstyle in playstyles:
        for session_num in range(1, num_sessions + 1):
            try:
                session = generate_session(game_date, playstyle, session_num)

                # Save session
                session_file = game_dir / f"session_{playstyle}_{session_num:02d}.json"

                with open(session_file, "w") as f:
                    json.dump(session, f, indent=2)

                outcome = "WIN" if session["exit_state"] == "won" else "LOSS"
                print(f"  ✓ {playstyle:10s} #{session_num}: {outcome:4s} ({session['duration_frames']:5d} frames)")
                sessions_generated += 1

            except Exception as e:
                print(f"  ✗ {playstyle:10s} #{session_num}: Error - {e}")

    print(f"\nGenerated {sessions_generated} sessions in {game_dir}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
