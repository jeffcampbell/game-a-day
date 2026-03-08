#!/usr/bin/env python3
"""Automated playtest session collection tool.

IMPORTANT: This tool generates SYNTHETIC/FAKE gameplay sessions with predefined
button input sequences for testing and demo purposes only. These are NOT real
user playtests.

Each synthetic session includes:
- is_synthetic: true flag to mark it as artificially generated
- Predefined button patterns (5 different play styles)
- Simulated logs and gameplay events
- Deterministic outcomes (seeded by game date + pattern)

These synthetic sessions should NOT be mixed with real playtest data in production
analytics. They are useful for:
- Testing the analytics pipeline
- Generating sample catalog entries
- Demonstrating game metrics without real playtesting

Usage:
  python3 tools/collect-playtests.py [--games <date>,<date>,...] [--sessions-per-game N]

Examples:
  # Collect playtests for all games
  python3 tools/collect-playtests.py

  # Collect for specific games
  python3 tools/collect-playtests.py --games 2026-03-07,2026-03-08

  # Collect 2 sessions per game instead of default 5
  python3 tools/collect-playtests.py --sessions-per-game 2
"""

import os
import json
import re
import sys
import random
import argparse
from pathlib import Path
from datetime import datetime
from collections import defaultdict


def find_all_games():
    """Find all game directories.

    Returns list of (date, game_dir) tuples sorted by date.
    """
    games = []
    games_dir = 'games'

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        if re.match(r'^\d{4}-\d{2}-\d{2}$', entry):
            game_path = os.path.join(games_dir, entry)
            if os.path.isdir(game_path) and os.path.exists(os.path.join(game_path, 'game.p8')):
                games.append((entry, game_path))

    return games


def load_game_metadata(game_dir):
    """Load metadata for a game.

    Returns dict if valid, None otherwise.
    """
    metadata_path = os.path.join(game_dir, 'metadata.json')

    if not os.path.exists(metadata_path):
        return None

    try:
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
            if isinstance(metadata, dict):
                return metadata
    except (json.JSONDecodeError, IOError, TypeError):
        pass

    return None


def generate_button_sequence(pattern_type, length=1200, seed=0):
    """Generate a predefined button sequence for playtesting.

    Args:
        pattern_type: 0-4 for different play styles
        length: Number of frames for the session
        seed: Random seed for reproducibility

    Returns list of button states (0-63 bitmask for each frame).
    """
    random.seed(seed)
    buttons = []

    if pattern_type == 0:
        # Pattern 0: Menu navigation + basic gameplay
        # Navigate menu: right, right, action
        # Play: random with pauses
        menu_buttons = [0] * 30 + [2] * 3 + [0] * 10 + [2] * 3 + [0] * 10 + [16] * 2 + [0] * 20
        buttons = menu_buttons

        # Gameplay: occasional movement and actions
        for i in range(length - len(menu_buttons)):
            if random.random() < 0.05:
                # Random action
                buttons.append(random.choice([1, 2, 4, 8, 16]))
            else:
                buttons.append(0)

    elif pattern_type == 1:
        # Pattern 1: Aggressive action play style
        # Lots of button presses, especially action buttons
        buttons = [0] * 50  # Menu navigation
        buttons.extend([16] * 2)  # Action
        buttons.extend([0] * 20)

        for i in range(length - len(buttons)):
            if random.random() < 0.2:
                buttons.append(random.choice([1, 2, 4, 8, 16, 32]))
            else:
                buttons.append(0)

    elif pattern_type == 2:
        # Pattern 2: Passive play style with minimal input
        buttons = [0] * 50  # Menu
        buttons.extend([16] * 2)
        buttons.extend([0] * 20)

        for i in range(length - len(buttons)):
            if random.random() < 0.02:
                buttons.append(random.choice([1, 2, 4, 8]))
            else:
                buttons.append(0)

    elif pattern_type == 3:
        # Pattern 3: Movement-focused play
        buttons = [0] * 50
        buttons.extend([16] * 2)
        buttons.extend([0] * 20)

        for i in range(length - len(buttons)):
            if random.random() < 0.15:
                buttons.append(random.choice([1, 2, 4, 8]))  # Movement only
            else:
                buttons.append(0)

    else:  # pattern_type == 4
        # Pattern 4: Rapid-fire style - jump around, lots of actions
        buttons = [0] * 50
        buttons.extend([16] * 2)
        buttons.extend([0] * 20)

        for i in range(length - len(buttons)):
            if random.random() < 0.3:
                buttons.append(random.choice([1, 2, 4, 8, 16, 32]))
            else:
                buttons.append(0)

    # Pad to exact length
    while len(buttons) < length:
        buttons.append(0)

    return buttons[:length]


def generate_logs_for_session(game_metadata, button_sequence, pattern_type):
    """Generate plausible logs for a session.

    Returns list of log strings.
    """
    logs = []

    # Infer game difficulty and mechanics from metadata
    difficulty = game_metadata.get('difficulty', 3) if game_metadata else 3
    genres = game_metadata.get('genres', []) if game_metadata else []
    playtime = game_metadata.get('playtime_minutes', 5) if game_metadata else 5

    # Expected duration for completion
    expected_frames = playtime * 60 * 60  # rough estimate (60fps)

    # Menu state
    logs.append("state:menu")

    # Determine session outcome based on pattern and difficulty
    input_count = sum(1 for b in button_sequence if b > 0)
    input_rate = input_count / len(button_sequence) if button_sequence else 0

    # Simulate state transitions and gameplay
    logs.append("state:play")

    # Add some gameplay events
    frames_played = len(button_sequence)

    # Generate events based on game mechanics
    if "action" in genres or "shooter" in genres:
        if input_rate > 0.15:
            logs.append("shoot")
            logs.append("score:10")

    if "puzzle" in genres:
        logs.append("piece_placed")

    if "adventure" in genres:
        logs.append("item_collected")

    # Determine completion status
    # Easier games with more input have higher completion rate
    completion_threshold = 0.3 + (difficulty * 0.1)  # Higher difficulty = lower chance to win
    completion_threshold = 1.0 - completion_threshold  # Invert logic

    is_won = (input_rate > 0.05) and (random.random() < completion_threshold)

    if is_won:
        logs.append("gameover:win")
        exit_state = "won"
    else:
        if random.random() < 0.3:
            logs.append("gameover:lose")
            exit_state = "lost"
        else:
            exit_state = "quit"

    return logs, exit_state


def session_exists_for_game(game_dir):
    """Check if game already has recorded sessions.

    Returns count of existing sessions.
    """
    count = 0
    if os.path.isdir(game_dir):
        for entry in os.listdir(game_dir):
            if entry.startswith('session_') and entry.endswith('.json'):
                count += 1
    return count


def create_session_file(game_date, game_dir, pattern_type, session_num):
    """Create and save a session file for a game.

    Returns path to created session, or None on error.
    """
    # Load metadata for better log generation
    metadata = load_game_metadata(game_dir)

    # Generate button sequence
    seed = hash((game_date, pattern_type, session_num)) % (2**31)
    random.seed(seed)  # Reset for deterministic output

    button_sequence = generate_button_sequence(
        pattern_type,
        length=random.randint(300, 3000),
        seed=seed
    )

    # Generate logs
    logs, exit_state = generate_logs_for_session(metadata, button_sequence, pattern_type)

    # Create session object
    session = {
        'date': game_date,
        'timestamp': datetime.now().isoformat(),
        'duration_frames': len(button_sequence),
        'button_sequence': button_sequence,
        'logs': logs,
        'exit_state': exit_state,
        'is_synthetic': True
    }

    # Generate session filename
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    # Add pattern/session number to ensure unique filenames
    session_file = os.path.join(
        game_dir,
        f'session_{timestamp}_{pattern_type:01d}{session_num:01d}.json'
    )

    # Ensure directory exists
    os.makedirs(game_dir, exist_ok=True)

    try:
        with open(session_file, 'w') as f:
            json.dump(session, f, indent=2)
        return session_file
    except IOError as e:
        print(f"Error creating session for {game_date}: {e}", flush=True)
        return None


def collect_playtests_for_game(game_date, game_dir, sessions_per_game=5, verbose=True):
    """Collect playtest sessions for a single game.

    Args:
        game_date: Date string (YYYY-MM-DD)
        game_dir: Path to game directory
        sessions_per_game: Number of sessions to create
        verbose: Print progress messages

    Returns count of successfully created sessions.
    """
    existing = session_exists_for_game(game_dir)
    if existing > 0 and verbose:
        print(f"  ⓘ {game_date}: Already has {existing} session(s), skipping", flush=True)
        return 0

    created = 0
    for i in range(sessions_per_game):
        pattern_type = i % 5  # Cycle through 5 different play styles
        session_file = create_session_file(game_date, game_dir, pattern_type, i)
        if session_file:
            created += 1
            if verbose:
                print(f"  ✓ {game_date}: Session {i+1}/{sessions_per_game}", flush=True)
        else:
            if verbose:
                print(f"  ✗ {game_date}: Failed to create session {i+1}/{sessions_per_game}", flush=True)

    return created


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Collect automated playtest sessions for games'
    )
    parser.add_argument(
        '--games',
        help='Comma-separated list of game dates to process (default: all games)',
        default=None
    )
    parser.add_argument(
        '--sessions-per-game',
        type=int,
        default=5,
        help='Number of sessions to create per game (default: 5)'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Recreate sessions even if they already exist'
    )

    args = parser.parse_args()

    # Find games
    all_games = find_all_games()
    if not all_games:
        print("No games found", file=sys.stderr, flush=True)
        return 1

    # Filter games if specified
    if args.games:
        requested_dates = set(args.games.split(','))
        games_to_process = [
            (date, path) for date, path in all_games
            if date in requested_dates
        ]
        if not games_to_process:
            print(f"No games found matching: {args.games}", file=sys.stderr, flush=True)
            return 1
    else:
        games_to_process = all_games

    print(f"Collecting playtests for {len(games_to_process)} game(s)", flush=True)
    print(f"Sessions per game: {args.sessions_per_game}", flush=True)
    print()

    total_sessions_created = 0
    games_with_sessions = 0

    for game_date, game_dir in games_to_process:
        if not args.force:
            existing = session_exists_for_game(game_dir)
            if existing >= args.sessions_per_game:
                print(f"{game_date}: Already has {existing} session(s), skipping", flush=True)
                continue

        sessions_created = collect_playtests_for_game(
            game_date,
            game_dir,
            sessions_per_game=args.sessions_per_game,
            verbose=True
        )

        if sessions_created > 0:
            games_with_sessions += 1
            total_sessions_created += sessions_created

    print()
    print(f"✓ Collected {total_sessions_created} total sessions across {games_with_sessions} games", flush=True)

    return 0


if __name__ == '__main__':
    sys.exit(main())
