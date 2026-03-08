#!/usr/bin/env python3
"""Playtest session analyzer and report generator.

Discovers all session_*.json files in game directories and generates human-readable
reports showing session metadata, state transitions, event frequency, and anomalies.

Usage:
  python3 tools/generate-playtest-report.py [--game DATE] [--since DATE] [--until DATE]

Examples:
  # Generate reports for all games with sessions
  python3 tools/generate-playtest-report.py

  # Generate report for a specific game
  python3 tools/generate-playtest-report.py --game 2026-03-07

  # Generate reports for games added after a certain date
  python3 tools/generate-playtest-report.py --since 2026-03-01

  # Generate reports for a date range
  python3 tools/generate-playtest-report.py --since 2026-03-01 --until 2026-03-07

Generates:
  - games/YYYY-MM-DD/playtest-report.md (for each game with sessions)
  - games/playtest-summary.md (master report)
"""

import os
import sys
import json
import argparse
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict


def parse_date_arg(date_str):
    """Parse and validate a date string in YYYY-MM-DD format.

    Returns datetime object or None if invalid.
    """
    if not date_str:
        return None
    try:
        return datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return None


def find_all_games():
    """Find all game directories (YYYY-MM-DD format).

    Returns list of (date_str, game_dir) tuples sorted by date.
    """
    games = []
    games_dir = 'games'

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        if re.match(r'^\d{4}-\d{2}-\d{2}$', entry):
            game_path = os.path.join(games_dir, entry)
            if os.path.isdir(game_path):
                games.append((entry, game_path))

    return games


def find_sessions(game_dir):
    """Find all recorded sessions for a game.

    Returns list of (filename, session_dict) tuples sorted by timestamp.
    """
    sessions = []

    if not os.path.isdir(game_dir):
        return sessions

    for entry in sorted(os.listdir(game_dir)):
        if entry.startswith('session_') and entry.endswith('.json'):
            session_path = os.path.join(game_dir, entry)
            try:
                with open(session_path, 'r') as f:
                    session = json.load(f)
                    if isinstance(session, dict):
                        sessions.append((entry, session))
            except (json.JSONDecodeError, IOError, TypeError):
                pass

    return sessions


def load_metadata(game_dir):
    """Load metadata.json for a game if it exists.

    Returns dict or None if missing or invalid.
    """
    metadata_path = os.path.join(game_dir, 'metadata.json')

    if not os.path.exists(metadata_path):
        return None

    try:
        with open(metadata_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError, TypeError):
        return None


def extract_state_transitions(logs):
    """Extract state transition sequence from logs.

    Returns list of states in order of appearance, or empty list.
    """
    states = []
    if not logs or not isinstance(logs, list):
        return states

    state_pattern = re.compile(r'^state:(\w+)$')

    for log in logs:
        if not isinstance(log, str):
            continue
        match = state_pattern.match(log)
        if match:
            state = match.group(1)
            # Only add if different from last state (avoid duplicates)
            if not states or states[-1] != state:
                states.append(state)

    return states


def extract_game_events(logs):
    """Extract game events from logs.

    Analyzes logs to find event patterns and count occurrences.
    Returns dict with event_type: count.
    """
    events = defaultdict(int)

    if not logs or not isinstance(logs, list):
        return {}

    # Pattern for state:* transitions
    state_pattern = re.compile(r'^state:\w+$')

    # Pattern for gameover events
    gameover_pattern = re.compile(r'^gameover:(\w+)$')

    # Pattern for generic events like jump, shoot, score, etc.
    event_pattern = re.compile(r'^([a-z_]+)(?::(.+))?$')

    for log in logs:
        if not isinstance(log, str):
            continue

        # Skip state transitions (handled separately)
        if state_pattern.match(log):
            continue

        # Check for gameover
        gameover_match = gameover_pattern.match(log)
        if gameover_match:
            outcome = gameover_match.group(1)
            events[f'gameover:{outcome}'] += 1
            continue

        # Extract generic event type
        match = event_pattern.match(log)
        if match:
            event_type = match.group(1)
            events[event_type] += 1

    return dict(sorted(events.items(), key=lambda x: x[1], reverse=True))


def detect_anomalies(session, logs, states):
    """Detect potential bugs or anomalies in a session.

    Returns list of anomaly descriptions.
    """
    anomalies = []

    # Detect state loops (same state appearing multiple times in a row after transitions)
    consecutive_same_state = 0
    looped_state = None
    for i, state in enumerate(states):
        if i > 0 and states[i] == states[i-1]:
            if looped_state is None:
                looped_state = states[i]
            consecutive_same_state += 1
        else:
            if consecutive_same_state > 2:
                anomalies.append(f"State loop detected: '{looped_state}' repeated {consecutive_same_state+1} times")
            consecutive_same_state = 0
            looped_state = None

    # Check for state loop at the end of the list
    if consecutive_same_state > 2:
        anomalies.append(f"State loop detected: '{looped_state}' repeated {consecutive_same_state+1} times")

    # Detect immediate gameover (gameover within first few frames)
    if 'gameover' in states and len(states) <= 2:
        anomalies.append("⚠️  Game reached gameover immediately (possible bug)")

    # Detect abrupt session end (session ends without reaching gameover)
    if states and states[-1] != 'gameover':
        duration = session.get('duration_frames', 0)
        if duration < 60:  # Less than 1 second at 60fps
            anomalies.append(f"⚠️  Session ended abruptly after {duration} frames")

    # Detect missing state transitions
    if not states:
        anomalies.append("⚠️  No state transitions logged (game may not have test infrastructure)")

    # Detect empty logs
    if not logs:
        anomalies.append("⚠️  No logs captured (game may not have _log() calls)")

    return anomalies


def format_session_report(game_date, session_filename, session, metadata):
    """Generate a formatted markdown report for a single session.

    Returns markdown string.
    """
    game_title = 'Unknown Game'
    if metadata:
        game_title = metadata.get('title', game_date)

    timestamp = session.get('timestamp', 'unknown')
    duration_frames = session.get('duration_frames', 0)
    duration_seconds = duration_frames / 60.0  # PICO-8 runs at 60fps

    # Safely extract and validate button_sequence and logs
    button_sequence = session.get('button_sequence', [])
    if not isinstance(button_sequence, list):
        button_sequence = []

    logs = session.get('logs', [])
    if not isinstance(logs, list):
        logs = []

    exit_state = session.get('exit_state', 'unknown')

    # Extract analysis
    state_transitions = extract_state_transitions(logs)
    events = extract_game_events(logs)
    anomalies = detect_anomalies(session, logs, state_transitions)

    report = []
    report.append(f"## Session: {session_filename}\n")
    report.append(f"**Game**: {game_title}\n")
    report.append(f"**Timestamp**: {timestamp}\n")
    report.append(f"**Duration**: {duration_seconds:.1f}s ({duration_frames} frames)\n")
    report.append(f"**Exit State**: {exit_state}\n")
    report.append("")

    # State transitions
    report.append("### State Transitions\n")
    if state_transitions:
        report.append(f"`{' → '.join(state_transitions)}`\n")
    else:
        report.append("*(no state transitions logged)*\n")
    report.append("")

    # Game events
    report.append("### Game Events\n")
    if events:
        for event, count in events.items():
            report.append(f"- **{event}**: {count}\n")
    else:
        report.append("*(no game events logged)*\n")
    report.append("")

    # Input statistics
    report.append("### Input Statistics\n")
    report.append(f"- **Total frames recorded**: {len(button_sequence)}\n")
    if len(button_sequence) > 0:
        input_count = sum(1 for b in button_sequence if b > 0)
        input_percentage = 100 * input_count / len(button_sequence)
        report.append(f"- **Frames with input**: {input_count} ({input_percentage:.1f}%)\n")
    else:
        report.append(f"- **Frames with input**: 0 (0.0%)\n")
    report.append(f"- **Logs captured**: {len(logs)}\n")
    report.append("")

    # Anomalies
    if anomalies:
        report.append("### ⚠️  Anomalies Detected\n")
        for anomaly in anomalies:
            report.append(f"- {anomaly}\n")
        report.append("")

    return "".join(report)


def generate_game_report(game_date, game_dir):
    """Generate a playtest report for a game with sessions.

    Returns (report_content, num_sessions) or (None, 0) if no sessions.
    """
    sessions = find_sessions(game_dir)
    if not sessions:
        return None, 0

    metadata = load_metadata(game_dir)

    report = []
    report.append(f"# Playtest Report: {game_date}\n\n")

    if metadata:
        title = metadata.get('title', game_date)
        report.append(f"**Game**: {title}\n")
        if metadata.get('description'):
            report.append(f"**Description**: {metadata['description']}\n")
        report.append("")

    report.append(f"**Total Sessions**: {len(sessions)}\n\n")

    # Generate report for each session
    for session_filename, session in sessions:
        session_report = format_session_report(game_date, session_filename, session, metadata)
        report.append(session_report)
        report.append("---\n\n")

    return "".join(report), len(sessions)


def generate_summary_report(games_with_sessions):
    """Generate a master playtest summary report.

    Args:
        games_with_sessions: list of (game_date, game_dir, sessions_count, metadata) tuples

    Returns markdown string.
    """
    report = []
    report.append("# Playtest Summary\n\n")
    report.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

    # Overall statistics
    total_sessions = sum(count for _, _, count, _ in games_with_sessions)
    total_games_with_sessions = len(games_with_sessions)

    report.append("## Statistics\n\n")
    report.append(f"- **Total games with sessions**: {total_games_with_sessions}\n")
    report.append(f"- **Total sessions recorded**: {total_sessions}\n")
    if total_games_with_sessions > 0:
        avg_sessions = total_sessions / total_games_with_sessions
        report.append(f"- **Average sessions per game**: {avg_sessions:.1f}\n")
    report.append("\n")

    # Games with most coverage
    if games_with_sessions:
        report.append("## Games by Playtest Coverage\n\n")
        sorted_games = sorted(games_with_sessions, key=lambda x: x[2], reverse=True)
        for game_date, _, count, metadata in sorted_games:
            title = game_date
            if metadata:
                title = metadata.get('title', game_date)
            report.append(f"- **{title}** ({game_date}): {count} session{'s' if count != 1 else ''}\n")
        report.append("\n")

    # Games without sessions
    all_games = find_all_games()
    games_needing_tests = []
    tested_dates = {game_date for game_date, _, _, _ in games_with_sessions}

    for game_date, game_dir in all_games:
        if game_date not in tested_dates:
            metadata = load_metadata(game_dir)
            games_needing_tests.append((game_date, metadata))

    if games_needing_tests:
        report.append("## Games Needing Playtest Coverage\n\n")
        report.append(f"**{len(games_needing_tests)} game(s) with no sessions recorded**\n\n")
        for game_date, metadata in games_needing_tests:
            title = game_date
            if metadata:
                title = metadata.get('title', game_date)
            report.append(f"- {title} ({game_date})\n")
        report.append("\n")

    return "".join(report)


def main():
    parser = argparse.ArgumentParser(
        description='Generate playtest session reports',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('--game', metavar='DATE', help='Generate report for specific game (YYYY-MM-DD)')
    parser.add_argument('--since', metavar='DATE', help='Include games added on/after this date (YYYY-MM-DD)')
    parser.add_argument('--until', metavar='DATE', help='Include games added on/before this date (YYYY-MM-DD)')

    args = parser.parse_args()

    # Validate date arguments
    since_date = parse_date_arg(args.since) if args.since else None
    until_date = parse_date_arg(args.until) if args.until else None

    if args.since and not since_date:
        print(f"❌ Invalid --since date format: {args.since}", file=sys.stderr)
        sys.exit(1)

    if args.until and not until_date:
        print(f"❌ Invalid --until date format: {args.until}", file=sys.stderr)
        sys.exit(1)

    # Find all games
    all_games = find_all_games()
    if not all_games:
        print("❌ No games found in games/ directory", file=sys.stderr)
        sys.exit(1)

    # Filter games based on arguments
    games_to_process = []

    if args.game:
        # Validate game date format
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', args.game):
            print(f"❌ Invalid game date format: {args.game}", file=sys.stderr)
            sys.exit(1)

        # Process specific game
        game_dir = os.path.join('games', args.game)
        if os.path.isdir(game_dir):
            games_to_process = [(args.game, game_dir)]
        else:
            print(f"❌ Game directory not found: {game_dir}", file=sys.stderr)
            sys.exit(1)
    else:
        # Process all games, optionally filtering by date range
        for game_date, game_dir in all_games:
            try:
                game_date_obj = datetime.strptime(game_date, '%Y-%m-%d')
            except ValueError:
                continue

            if since_date and game_date_obj < since_date:
                continue
            if until_date and game_date_obj > until_date:
                continue

            games_to_process.append((game_date, game_dir))

    # Generate reports for games with sessions
    print(f"Processing {len(games_to_process)} game(s)...", flush=True)
    games_with_sessions = []
    total_reports_generated = 0

    for game_date, game_dir in games_to_process:
        report_content, num_sessions = generate_game_report(game_date, game_dir)

        if report_content:
            # Write report to file
            report_path = os.path.join(game_dir, 'playtest-report.md')
            try:
                with open(report_path, 'w') as f:
                    f.write(report_content)
                print(f"✓ {game_date}: {num_sessions} session(s)", flush=True)

                metadata = load_metadata(game_dir)
                games_with_sessions.append((game_date, game_dir, num_sessions, metadata))
                total_reports_generated += 1
            except IOError as e:
                print(f"❌ Failed to write report for {game_date}: {e}", file=sys.stderr)

    # Generate summary report
    if games_with_sessions:
        summary_path = 'games/playtest-summary.md'
        summary_content = generate_summary_report(games_with_sessions)
        try:
            os.makedirs('games', exist_ok=True)
            with open(summary_path, 'w') as f:
                f.write(summary_content)
            print(f"\n✓ Generated {summary_path}", flush=True)
        except IOError as e:
            print(f"❌ Failed to write summary: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print("\n⚠️  No sessions found in selected games", flush=True)
        if args.game:
            print(f"   Game {args.game} has no recorded sessions", file=sys.stderr)
        sys.exit(0)

    print(f"\n✓ Generated {total_reports_generated} report(s)", flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
