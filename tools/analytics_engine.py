#!/usr/bin/env python3
"""Analytics engine for PICO-8 game sessions and test data.

Extracts gameplay metrics from recorded sessions and test reports to provide
insights on game difficulty, player engagement, and design patterns.

Metrics extracted:
- Per-session: duration, completion status, actions attempted, state distribution
- Per-game: completion rate, avg duration, difficulty curves, state transitions
- Cross-game: comparative metrics and rankings
"""

import os
import json
import re
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import statistics


def load_session(session_path):
    """Load and validate a session JSON file.

    Returns dict if valid, None if invalid/malformed.
    """
    try:
        with open(session_path, 'r') as f:
            session = json.load(f)
            # Validate basic structure
            if not isinstance(session, dict):
                return None
            if 'button_sequence' not in session or 'logs' not in session:
                return None
            return session
    except (json.JSONDecodeError, IOError, TypeError):
        return None


def load_test_report(game_dir):
    """Load test report for a game.

    Returns dict if found, None otherwise.
    """
    report_path = os.path.join(game_dir, 'test-report.json')
    if not os.path.exists(report_path):
        return None

    try:
        with open(report_path, 'r') as f:
            report = json.load(f)
            if isinstance(report, dict):
                return report
    except (json.JSONDecodeError, IOError, TypeError):
        pass
    return None


def find_sessions(game_dir):
    """Find all recorded sessions for a game.

    Returns list of (session_path, session_data, mtime) tuples, sorted by date.
    """
    sessions = []

    if not os.path.isdir(game_dir):
        return sessions

    for entry in os.listdir(game_dir):
        if entry.startswith('session_') and entry.endswith('.json'):
            session_path = os.path.join(game_dir, entry)
            session = load_session(session_path)
            if session:
                mtime = os.path.getmtime(session_path)
                sessions.append((session_path, session, mtime))

    # Sort by modification time (newest first)
    sessions.sort(key=lambda x: x[2], reverse=True)
    return sessions


def extract_state_transitions(logs):
    """Extract all state transitions from logs.

    Returns list of (state_name, frame_index) tuples.
    """
    transitions = []
    state_pattern = re.compile(r'^state:(\w+)$')

    for i, log in enumerate(logs):
        match = state_pattern.match(log)
        if match:
            state = match.group(1)
            transitions.append((state, i))

    return transitions


def extract_events(logs):
    """Extract game events from logs.

    Returns dict of event_type -> count mapping.
    """
    events = defaultdict(int)

    gameover_pattern = re.compile(r'^gameover:(\w+)$')
    state_pattern = re.compile(r'^state:(\w+)$')

    for log in logs:
        if gameover_pattern.match(log):
            match = gameover_pattern.match(log)
            events['gameover:' + match.group(1)] += 1
        elif state_pattern.match(log):
            # Count state transitions as events
            pass
        else:
            # Generic event
            events[log] += 1

    return dict(events)


def detect_completion_status(session):
    """Determine if session was completed based on exit state and logs.

    Returns one of: 'won', 'lost', 'quit', 'timeout'.
    """
    exit_state = session.get('exit_state', 'quit')
    logs = session.get('logs', [])

    # Check logs for explicit win/loss
    for log in logs:
        if 'gameover:win' in log or 'win' in log.lower():
            return 'won'
        if 'gameover:lose' in log or 'gameover:loss' in log:
            return 'lost'

    # Use exit state as fallback
    if exit_state == 'timeout':
        return 'timeout'

    return 'quit'


def calculate_session_metrics(session, date):
    """Calculate metrics for a single session.

    Returns dict of metrics.
    """
    duration_frames = session.get('duration_frames', 0)
    logs = session.get('logs', [])
    button_sequence = session.get('button_sequence', [])

    # Completion metrics
    completion_status = detect_completion_status(session)

    # State transitions
    state_transitions = extract_state_transitions(logs)
    unique_states = len(set(s[0] for s in state_transitions))

    # Events
    events = extract_events(logs)

    # Button input activity (how many frames had input)
    active_input_frames = sum(1 for btn in button_sequence if btn > 0)
    input_rate = active_input_frames / len(button_sequence) if button_sequence else 0

    # State distribution
    state_times = defaultdict(int)
    current_state = None
    last_state_frame = 0

    for state, frame in state_transitions:
        if current_state and frame > last_state_frame:
            state_times[current_state] += frame - last_state_frame
        current_state = state
        last_state_frame = frame

    # Account for remaining time in final state
    if current_state:
        state_times[current_state] += duration_frames - last_state_frame

    return {
        'duration_frames': duration_frames,
        'completion_status': completion_status,
        'state_transitions_count': len(state_transitions),
        'unique_states': unique_states,
        'states_visited': sorted(set(s[0] for s in state_transitions)),
        'state_distribution': dict(state_times),
        'events': events,
        'input_activity_rate': round(input_rate, 3),
        'logs_count': len(logs),
        'button_presses_total': active_input_frames,
        'date': date
    }


def find_difficulty_cliff(sessions_metrics, percentile=80):
    """Identify frame range where difficulty cliff occurs.

    Returns frame number where ~percentile% of players quit/fail.
    """
    if not sessions_metrics:
        return None

    # Track at what frame each session ended
    quit_frames = []

    for metrics in sessions_metrics:
        if metrics['completion_status'] in ['quit', 'lost']:
            quit_frames.append(metrics['duration_frames'])

    if not quit_frames:
        return None

    quit_frames.sort()
    # Find the frame where percentile% of failures occurred
    idx = int(len(quit_frames) * (percentile / 100.0))
    return quit_frames[min(idx, len(quit_frames) - 1)]


def calculate_game_metrics(game_dir, date):
    """Calculate aggregated metrics for a game.

    Returns dict of analytics data or None if no data available.
    """
    # Find all sessions
    sessions = find_sessions(game_dir)
    if not sessions:
        # No sessions, use test report only
        test_report = load_test_report(game_dir)
        if not test_report:
            return None

        return {
            'date': date,
            'has_sessions': False,
            'session_count': 0,
            'test_report': test_report,
            'metrics': {}
        }

    # Calculate per-session metrics
    session_metrics_list = []
    for session_path, session, mtime in sessions:
        metrics = calculate_session_metrics(session, date)
        session_metrics_list.append(metrics)

    # Aggregate metrics
    durations = [m['duration_frames'] for m in session_metrics_list]
    completions = Counter(m['completion_status'] for m in session_metrics_list)

    # Safe statistics (handle edge cases)
    avg_duration = statistics.mean(durations) if durations else 0
    median_duration = statistics.median(durations) if durations else 0
    max_duration = max(durations) if durations else 0

    completion_rate = (completions['won'] / len(session_metrics_list) * 100) if session_metrics_list else 0

    # Difficulty analysis
    difficulty_cliff = find_difficulty_cliff(session_metrics_list, percentile=80)

    # Aggregate state information
    all_states = defaultdict(list)
    for metrics in session_metrics_list:
        for state, time in metrics['state_distribution'].items():
            all_states[state].append(time)

    avg_state_times = {}
    for state, times in all_states.items():
        if times:
            avg_state_times[state] = round(statistics.mean(times), 1)

    # Load test report for additional context
    test_report = load_test_report(game_dir)

    return {
        'date': date,
        'has_sessions': True,
        'session_count': len(session_metrics_list),
        'metrics': {
            'completion_rate_pct': round(completion_rate, 1),
            'completion_breakdown': dict(completions),
            'avg_duration_frames': round(avg_duration, 1),
            'median_duration_frames': round(median_duration, 1),
            'max_duration_frames': max_duration,
            'difficulty_cliff_frame': difficulty_cliff,
            'avg_state_times': avg_state_times,
            'input_activity_rate': round(
                statistics.mean([m['input_activity_rate'] for m in session_metrics_list]),
                3
            ) if session_metrics_list else 0,
        },
        'test_report': test_report,
        'session_samples': [
            {
                'duration_frames': m['duration_frames'],
                'completion_status': m['completion_status'],
                'unique_states': m['unique_states'],
                'logs_count': m['logs_count']
            }
            for m in session_metrics_list[:5]  # First 5 samples
        ]
    }


def generate_cross_game_analytics(games_data):
    """Generate cross-game comparison metrics.

    Returns dict with comparative metrics and rankings.
    """
    if not games_data:
        return {}

    # Filter games with sessions
    games_with_metrics = [
        (date, data) for date, data in games_data.items()
        if data and data.get('has_sessions', False)
    ]

    if not games_with_metrics:
        return {}

    completion_rates = [
        (date, data['metrics']['completion_rate_pct'])
        for date, data in games_with_metrics
    ]

    durations = [
        (date, data['metrics']['avg_duration_frames'])
        for date, data in games_with_metrics
    ]

    # Sort by metric
    completion_rates.sort(key=lambda x: x[1], reverse=True)
    durations.sort(key=lambda x: x[1], reverse=True)

    return {
        'completion_rate_ranking': completion_rates,
        'duration_ranking': durations,
        'total_games_analyzed': len(games_data),
        'games_with_sessions': len(games_with_metrics),
        'avg_completion_rate': round(
            statistics.mean([rate for _, rate in completion_rates]),
            1
        ) if completion_rates else 0,
        'avg_session_duration': round(
            statistics.mean([dur for _, dur in durations]),
            1
        ) if durations else 0,
    }


def find_all_games():
    """Find all game directories.

    Returns list of (date, game_dir) tuples.
    """
    games = []
    games_dir = 'games'

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        game_dir = os.path.join(games_dir, entry)
        if os.path.isdir(game_dir) and os.path.exists(os.path.join(game_dir, 'game.p8')):
            games.append((entry, game_dir))

    return games


def generate_analytics_report(output_dir='games'):
    """Generate comprehensive analytics report for all games.

    Returns dict with per-game and cross-game analytics.
    """
    games = find_all_games()

    # Per-game analytics
    games_data = {}
    for date, game_dir in games:
        analytics = calculate_game_metrics(game_dir, date)
        if analytics:
            games_data[date] = analytics
            # Save per-game report
            report_path = os.path.join(game_dir, 'analytics-report.json')
            try:
                with open(report_path, 'w') as f:
                    json.dump(analytics, f, indent=2)
            except IOError:
                pass

    # Cross-game analytics
    cross_game = generate_cross_game_analytics(games_data)

    # Generate summary report
    summary = {
        'generated_at': datetime.now().isoformat(),
        'total_games': len(games),
        'games_analyzed': len(games_data),
        'cross_game_metrics': cross_game,
        'per_game_summaries': {
            date: {
                'date': data.get('date'),
                'has_sessions': data.get('has_sessions', False),
                'session_count': data.get('session_count', 0),
                'metrics': data.get('metrics', {}),
                'test_status': data.get('test_report', {}).get('status') if data.get('test_report') else None
            }
            for date, data in games_data.items()
        }
    }

    # Save master report
    report_path = os.path.join(output_dir, 'analytics-report.json')
    try:
        with open(report_path, 'w') as f:
            json.dump(summary, f, indent=2)
    except IOError as e:
        print(f"Error writing analytics report: {e}", flush=True)

    return summary


if __name__ == '__main__':
    report = generate_analytics_report()
    print(json.dumps(report, indent=2))
