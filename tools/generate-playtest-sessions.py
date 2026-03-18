#!/usr/bin/env python3
"""
Generate synthetic playtest sessions for PICO-8 games.

This tool creates SYNTHETIC session files with predefined button sequences representing
different playstyles: aggressive, careful, boss_attempter, quitter, and casual.
Each represents a realistic way a human player would approach the game.

IMPORTANT: These are SYNTHETIC sessions with simulated logs, not recordings from
actual game execution. They are marked with is_synthetic: true to prevent artificial
data from contaminating production analytics. Use run-interactive-test.py to record
REAL playtest sessions.
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def generate_aggressive_playtest(game_date):
    """
    Fast, aggressive playstyle: spam buttons, try to win quickly.
    Likely to lose balls early and fail.
    """
    # Start game, move paddle aggressively, try to clear level fast
    buttons = [
        0,      # Wait in menu
        16,     # Press O to start
        0, 0, 0,  # Wait for level to load
    ]

    # Aggressive left-right movement
    for i in range(30):
        buttons.append([1, 1, 0, 2, 2][i % 5])  # Erratic paddle movement

    # Try to progress through levels
    for level in range(3):
        # Random mashing
        for i in range(40):
            buttons.append([1, 2, 0, 1, 2, 16][i % 6])

    # Expected to fail or barely win - let's say fails after ~180 frames
    buttons = buttons[:180]

    return {
        "date": game_date,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'),
        "duration_frames": len(buttons),
        "button_sequence": buttons,
        "logs": [
            "state:menu",
            "state:play",
            "score:0",
            "ball_loss",
            "score:200",
            "ball_loss",
            "gameover:lose"
        ],
        "exit_state": "completed",
        "is_synthetic": True
    }


def generate_careful_playtest(game_date):
    """
    Careful, methodical playstyle: moves slowly, tries to keep ball in play.
    More likely to survive longer and win.
    """
    buttons = [
        0,      # Wait in menu
        16,     # Press O to start
        0, 0, 0,  # Wait for level to load
    ]

    # Careful measured movements
    for round_num in range(5):
        # Move left carefully
        for _ in range(10):
            buttons.append(1)
        # Wait
        for _ in range(15):
            buttons.append(0)
        # Move right carefully
        for _ in range(10):
            buttons.append(2)
        # Wait
        for _ in range(15):
            buttons.append(0)

    # Try to progress through levels with more patience
    for level in range(4):
        for i in range(60):
            if i % 20 < 5:
                buttons.append(1 if i % 40 < 20 else 2)
            else:
                buttons.append(0)

    buttons = buttons[:300]  # Longer session

    return {
        "date": game_date,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'),
        "duration_frames": len(buttons),
        "button_sequence": buttons,
        "logs": [
            "state:menu",
            "state:play",
            "score:0",
            "score:500",
            "power_up:expand",
            "score:1000",
            "score:1500",
            "level_complete:1",
            "state:play",
            "score:2000",
            "score:2500",
            "level_complete:2",
            "state:play",
            "score:3000",
            "ball_loss",
            "score:3500",
            "level_complete:3",
            "state:play",
            "score:4000",
            "gameover:win"
        ],
        "exit_state": "completed",
        "is_synthetic": True
    }


def generate_boss_attempter(game_date):
    """
    Player who makes it to boss level and attempts it.
    May succeed or fail depending on luck.
    """
    buttons = [
        0,      # Wait in menu
        16,     # Press O to start
        0, 0, 0,  # Load
    ]

    # Get through first 5 levels quickly but successfully
    for level in range(5):
        for i in range(80):
            if i % 25 < 10:
                buttons.append(1 if i % 50 < 25 else 2)
            else:
                buttons.append(0)

    # Boss battle - lots of movement trying to avoid boss attacks
    for round_num in range(3):
        for i in range(40):
            if i % 10 < 4:
                buttons.append(1 if i % 20 < 10 else 2)
            elif i % 10 == 5:
                buttons.append(16)  # Try shooting/power attacks
            else:
                buttons.append(0)

    buttons = buttons[:420]  # Long session

    return {
        "date": game_date,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'),
        "duration_frames": len(buttons),
        "button_sequence": buttons,
        "logs": [
            "state:menu",
            "state:play",
            "score:0",
            "score:1000",
            "level_complete:1",
            "state:play",
            "score:2000",
            "level_complete:2",
            "state:play",
            "score:3000",
            "level_complete:3",
            "state:play",
            "score:4000",
            "level_complete:4",
            "state:play",
            "score:5000",
            "level_complete:5",
            "state:play",
            "boss_entered",
            "score:5500",
            "boss_hit:1",
            "score:6000",
            "boss_hit:2",
            "score:6500",
            "gameover:win"
        ],
        "exit_state": "completed",
        "is_synthetic": True
    }


def generate_quitter(game_date):
    """
    Player who quits early - tries for a bit then gives up.
    Represents player frustration point.
    """
    buttons = [
        0,      # Wait in menu
        16,     # Press O to start
        0, 0, 0,  # Load
    ]

    # Play for a bit
    for i in range(60):
        if i % 15 < 5:
            buttons.append(1 if i % 30 < 15 else 2)
        else:
            buttons.append(0)

    # Get frustrated and quit
    buttons.append(27)  # Some combination that exits
    buttons = buttons[:80]

    return {
        "date": game_date,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'),
        "duration_frames": len(buttons),
        "button_sequence": buttons,
        "logs": [
            "state:menu",
            "state:play",
            "score:0",
            "ball_loss",
            "score:100",
            "ball_loss",
            "ball_loss",
            "gameover:lose"
        ],
        "exit_state": "completed",
        "is_synthetic": True
    }


def generate_casual_player(game_date):
    """
    Casual player - moderate pace, some success.
    Completes a couple levels.
    """
    buttons = [
        0,      # Wait in menu
        16,     # Press O to start
        0, 0, 0,  # Load
    ]

    # Casual play through 2-3 levels
    for level in range(3):
        for i in range(100):
            if i % 30 < 12:
                buttons.append(1 if i % 60 < 30 else 2)
            elif i % 30 == 15:
                buttons.append(16)
            else:
                buttons.append(0)

    buttons = buttons[:250]

    return {
        "date": game_date,
        "timestamp": datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'),
        "duration_frames": len(buttons),
        "button_sequence": buttons,
        "logs": [
            "state:menu",
            "state:play",
            "score:0",
            "score:300",
            "power_up:expand",
            "score:800",
            "level_complete:1",
            "state:play",
            "score:1200",
            "score:1500",
            "level_complete:2",
            "state:play",
            "score:2000",
            "ball_loss",
            "score:2200",
            "gameover:lose"
        ],
        "exit_state": "completed",
        "is_synthetic": True
    }


def save_session(game_dir, session_data, index=0):
    """Save a session to a JSON file."""
    os.makedirs(game_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    session_file = os.path.join(game_dir, f"session_{timestamp}_{1000 + index}.json")

    with open(session_file, 'w') as f:
        json.dump(session_data, f, indent=2)

    return session_file


def main():
    """Generate playtest sessions for a game."""
    if len(sys.argv) < 2:
        print("Usage: python3 generate-playtest-sessions.py <game_date>")
        print("Example: python3 generate-playtest-sessions.py 2026-03-18")
        sys.exit(1)

    game_date = sys.argv[1]
    game_dir = os.path.join("games", game_date)

    if not os.path.exists(os.path.join(game_dir, "game.p8")):
        print(f"Error: Game not found at {game_dir}")
        sys.exit(1)

    print(f"Generating synthetic playtest sessions for {game_date}...")
    print("  (These are synthetic sessions with simulated logs, marked as is_synthetic: true)")

    # Generate diverse playstyles
    sessions = [
        ("aggressive", generate_aggressive_playtest(game_date)),
        ("careful", generate_careful_playtest(game_date)),
        ("boss_attempter", generate_boss_attempter(game_date)),
        ("quitter", generate_quitter(game_date)),
        ("casual", generate_casual_player(game_date)),
    ]

    saved_files = []
    for idx, (name, session_data) in enumerate(sessions):
        session_file = save_session(game_dir, session_data, idx)
        saved_files.append(session_file)
        print(f"  ✓ Saved {name:20} -> {os.path.basename(session_file)}")

    print(f"\n✓ Generated {len(saved_files)} playtest sessions")
    print(f"  Sessions saved to: {game_dir}/")

    return 0


if __name__ == "__main__":
    sys.exit(main())
