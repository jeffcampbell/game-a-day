#!/usr/bin/env python3
"""Synthetic game playtester for PICO-8 games.

Generates synthetic gameplay sessions with different playstyles for testing and
metrics generation. These sessions use deterministic button sequences and simulated
logs, NOT real game execution. Sessions are marked with is_synthetic: true and
excluded from production analytics by default.

For real gameplay data, use run-interactive-test.py --record.

Usage:
  python3 tools/headless-playtester.py                    # Run all games
  python3 tools/headless-playtester.py --games 2026-03-08  # Specific game
  python3 tools/headless-playtester.py --playstyle aggressive --sessions 3
  python3 tools/headless-playtester.py --skip-existing     # Only new games
"""

import os
import sys
import json
import re
import subprocess
import argparse
from datetime import datetime
import random
import logging


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def generate_button_sequence(playstyle, length=1200, seed=0):
    """Generate button sequence for a playstyle.

    Args:
        playstyle: 'aggressive', 'careful', 'strategic', 'random', or 'passive'
        length: Number of frames
        seed: Random seed

    Returns:
        List of button states (0-63 bitmask)
    """
    random.seed(seed)
    buttons = []

    if playstyle == 'aggressive':
        # Rapid, chaotic input
        for _ in range(length):
            if random.random() < 0.6:
                buttons.append(random.choice([1, 2, 4, 8, 16, 32]))
            else:
                buttons.append(0)

    elif playstyle == 'careful':
        # Deliberate input with pauses
        for _ in range(length):
            if random.random() < 0.2:
                buttons.append(random.choice([1, 2, 4, 8, 16, 32]))
            else:
                buttons.append(0)

    elif playstyle == 'strategic':
        # Balanced input, some patterns
        phase = 0
        for i in range(length):
            if i % 60 == 0:
                phase = (phase + 1) % 4

            if phase == 0:
                buttons.append(random.choice([1, 2]) if random.random() < 0.3 else 0)
            elif phase == 1:
                buttons.append(random.choice([4, 8]) if random.random() < 0.3 else 0)
            elif phase == 2:
                buttons.append(random.choice([16, 32]) if random.random() < 0.3 else 0)
            else:
                buttons.append(0)

    elif playstyle == 'random':
        # Pure randomness
        for _ in range(length):
            if random.random() < 0.3:
                buttons.append(random.randint(0, 63))
            else:
                buttons.append(0)

    elif playstyle == 'passive':
        # Minimal input, mostly idle
        for _ in range(length):
            if random.random() < 0.05:
                buttons.append(random.choice([16, 32]))
            else:
                buttons.append(0)

    return buttons[:length]


def generate_synthetic_logs(playstyle, frame_count, seed=0):
    """Generate synthetic gameplay logs based on playstyle.

    Creates realistic-looking event sequences including state transitions
    and completion events. These are not real game data, but plausible
    sequences for testing analytics.

    Args:
        playstyle: 'aggressive', 'careful', 'strategic', 'random', 'passive'
        frame_count: Total frames in session
        seed: Random seed for reproducibility

    Returns:
        List of log strings
    """
    random.seed(seed)
    logs = []

    # Initial state
    logs.append('state:menu')

    # Game start
    logs.append('state:play')

    # Add some game events based on playstyle
    # Estimate events based on frame count and playstyle
    event_density = {
        'aggressive': 0.15,  # More events from active play
        'careful': 0.08,      # Fewer events from cautious play
        'strategic': 0.12,    # Moderate events
        'random': 0.10,       # Some chaotic events
        'passive': 0.05       # Few events from idle play
    }

    density = event_density.get(playstyle, 0.10)
    num_events = max(1, int(frame_count * density / 60))

    events = [
        'score:100', 'score:200', 'enemy_spawn', 'item_pickup',
        'level_up', 'player_hit', 'jump', 'shoot', 'dash',
        'collision', 'puzzle_solve', 'zone_enter'
    ]

    for _ in range(num_events):
        if random.random() < 0.7:  # 70% chance to add an event
            logs.append(random.choice(events))

    # Completion status based on playstyle
    # More active playstyles have better completion rates
    completion_chance = {
        'aggressive': 0.65,
        'careful': 0.50,
        'strategic': 0.70,
        'random': 0.35,
        'passive': 0.30
    }

    chance = completion_chance.get(playstyle, 0.50)
    if random.random() < chance:
        logs.append('gameover:win')
    else:
        logs.append('gameover:lose')

    return logs


def run_game_headless(game_dir, game_date, playstyle):
    """Generate a synthetic gameplay session.

    Creates a synthetic session with:
    - Deterministic button sequence for reproducibility
    - Simulated logs based on playstyle characteristics
    - Session marked as synthetic (is_synthetic: true)

    This is NOT real game execution. For actual gameplay recording,
    use run-interactive-test.py --record.

    Returns dict with session data or None on error.
    """
    game_html = os.path.join(game_dir, 'game.html')
    if not os.path.exists(game_html):
        logger.error(f"Game HTML not found: {game_html}")
        return None

    # Determine game duration from metadata
    metadata_path = os.path.join(game_dir, 'metadata.json')
    duration = 5  # Default 5 minutes
    try:
        if os.path.exists(metadata_path):
            with open(metadata_path) as f:
                metadata = json.load(f)
                duration = metadata.get('playtime_minutes', 5)
    except (IOError, json.JSONDecodeError):
        pass

    # Generate button sequence (5 min = 18000 frames at 60fps)
    session_length = int(duration * 60 * 60)
    seed = hash((game_date, playstyle)) % (2**31)
    button_sequence = generate_button_sequence(playstyle, session_length, seed)

    # Generate synthetic logs based on playstyle
    logs = generate_synthetic_logs(playstyle, session_length, seed)

    # Create synthetic session marked for filtering in analytics
    return {
        'date': game_date,
        'timestamp': datetime.now().isoformat(),
        'duration_frames': len(button_sequence),
        'button_sequence': button_sequence,
        'logs': logs,
        'playstyle': playstyle,
        'exit_state': 'recorded',
        'is_synthetic': True,  # Critical: Mark as synthetic to prevent analytics contamination
        'execution_notes': 'Synthetic session from automated playtester (not real gameplay)'
    }


def find_all_games():
    """Find all PICO-8 games."""
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


def game_has_sessions(game_dir):
    """Check if game already has real sessions."""
    if not os.path.isdir(game_dir):
        return False

    for entry in os.listdir(game_dir):
        if entry.startswith('session_') and entry.endswith('.json'):
            try:
                with open(os.path.join(game_dir, entry)) as f:
                    session = json.load(f)
                    # Only count non-synthetic sessions
                    if not session.get('is_synthetic', False):
                        return True
            except:
                pass

    return False


def export_game_if_needed(game_p8, game_dir):
    """Export game to HTML if not already done."""
    game_html = os.path.join(game_dir, 'game.html')
    if os.path.exists(game_html):
        return True

    logger.info(f"Exporting {os.path.basename(game_dir)} to HTML...")

    try:
        result = subprocess.run(
            ['pico8', game_p8, '-export', game_html],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0 and os.path.exists(game_html):
            logger.info(f"  ✓ Exported successfully")
            return True
        else:
            logger.error(f"  ✗ Export failed: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        logger.error(f"  ✗ Export timeout")
        return False
    except FileNotFoundError:
        logger.error(f"  ✗ pico8 command not found")
        return False


def playtest_game(game_date, game_dir, playstyles, sessions_per_style=1):
    """Generate synthetic playtests for a single game.

    Returns count of successfully created sessions.
    """
    game_p8 = os.path.join(game_dir, 'game.p8')

    # Export if needed (validates game.html exists)
    if not export_game_if_needed(game_p8, game_dir):
        logger.error(f"✗ {game_date}: Could not export game")
        return 0

    created = 0
    for playstyle in playstyles:
        for session_num in range(sessions_per_style):
            logger.info(f"  Generating {game_date} ({playstyle})...")

            session_data = run_game_headless(
                game_dir,
                game_date,
                playstyle
            )

            if session_data:
                # Save session file
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                session_file = os.path.join(
                    game_dir,
                    f'session_{timestamp}_{playstyle[0]}.json'
                )

                try:
                    with open(session_file, 'w') as f:
                        json.dump(session_data, f, indent=2)
                    logger.info(f"  ✓ Session saved: {session_file}")
                    created += 1
                except IOError as e:
                    logger.error(f"  ✗ Failed to save session: {e}")
            else:
                logger.error(f"  ✗ Session generation failed for {playstyle}")

    return created


def main():
    parser = argparse.ArgumentParser(description='Headless PICO-8 game playtester')
    parser.add_argument('--games', help='Comma-separated game dates (e.g. 2026-03-08,2026-03-09)')
    parser.add_argument('--playstyle', help='Specific playstyle (aggressive, careful, strategic, random, passive)')
    parser.add_argument('--sessions', type=int, default=1, help='Sessions per playstyle (default 1)')
    parser.add_argument('--skip-existing', action='store_true', help='Skip games with existing sessions')

    args = parser.parse_args()

    # Determine games to test
    all_games = find_all_games()

    if args.games:
        requested_dates = set(args.games.split(','))
        games = [(d, p) for d, p in all_games if d in requested_dates]
        if len(games) != len(requested_dates):
            missing = requested_dates - {d for d, _ in games}
            logger.warning(f"Games not found: {', '.join(missing)}")
    else:
        games = all_games

    # Filter by --skip-existing
    if args.skip_existing:
        games = [(d, p) for d, p in games if not game_has_sessions(p)]

    # Determine playstyles
    playstyles = [args.playstyle] if args.playstyle else [
        'aggressive', 'careful', 'strategic', 'random', 'passive'
    ]

    if not games:
        logger.info("No games to test")
        return 0

    logger.info(f"Testing {len(games)} games with {len(playstyles)} playstyles")
    logger.info(f"  Playstyles: {', '.join(playstyles)}")

    total_sessions = 0
    total_errors = 0

    for game_date, game_dir in games:
        try:
            sessions = playtest_game(
                game_date,
                game_dir,
                playstyles,
                args.sessions
            )
            total_sessions += sessions

            if sessions == 0:
                total_errors += 1
                logger.warning(f"✗ {game_date}: 0 sessions created")
            else:
                logger.info(f"✓ {game_date}: {sessions} session(s)")

        except KeyboardInterrupt:
            logger.info("Interrupted by user")
            break
        except Exception as e:
            logger.error(f"✗ {game_date}: {e}")
            total_errors += 1

    # Summary
    logger.info("")
    logger.info("=" * 50)
    logger.info(f"Total games: {len(games)}")
    logger.info(f"Total sessions: {total_sessions}")
    logger.info(f"Errors: {total_errors}")
    logger.info("=" * 50)

    if total_sessions > 0:
        logger.info("✓ Success: Sessions recorded")
        return 0
    else:
        logger.error("✗ Failed: No sessions recorded")
        return 1


if __name__ == '__main__':
    sys.exit(main())
