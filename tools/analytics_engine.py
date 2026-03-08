#!/usr/bin/env python3
"""Analytics engine for PICO-8 game sessions and test data.

Extracts gameplay metrics from recorded sessions and test reports to provide
insights on game difficulty, player engagement, and design patterns.

IMPORTANT: By default, this engine EXCLUDES synthetic sessions (marked with
is_synthetic: true) from analytics calculations. Synthetic sessions are
artificially generated test data and should not influence real game metrics.

If a game has only synthetic sessions and no real sessions, the game will have
no analytics (has_sessions: false). This is intentional - it prevents synthetic
data from being misrepresented as real playtest results.

To work with synthetic data for testing, use the analytics output directly
but be aware that metrics_source will be marked as 'synthetic'.

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


def find_sessions(game_dir, include_synthetic=False):
    """Find all recorded sessions for a game.

    By default, EXCLUDES synthetic sessions (is_synthetic: true) to prevent
    artificially generated data from contaminating real playtest analytics.

    Args:
        game_dir: Path to game directory
        include_synthetic: If True, include synthetic sessions in results

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
                # Filter out synthetic sessions unless explicitly requested
                is_synthetic = session.get('is_synthetic', False)
                if is_synthetic and not include_synthetic:
                    continue

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


def calculate_engagement_score(game_metrics, metadata=None):
    """Calculate engagement score for a game (0.0-1.0).

    Weights:
    - Completion rate: 50%
    - Session duration match: 30%
    - Action variety: 20%

    Returns float between 0.0 and 1.0.
    """
    if not game_metrics or not game_metrics.get('has_sessions'):
        return 0.0

    metrics = game_metrics.get('metrics', {})
    completion_rate = metrics.get('completion_rate_pct', 0) / 100.0  # Normalize to 0-1
    avg_duration = metrics.get('avg_duration_frames', 0)
    input_rate = metrics.get('input_activity_rate', 0)

    # Expected playtime from metadata (in frames, assuming 60fps)
    # Default 5 minutes = 5 * 60 seconds * 60 fps = 18,000 frames
    expected_frames = 5 * 60 * 60  # 5 minutes at 60fps = 18,000 frames
    if metadata:
        playtime_minutes = metadata.get('playtime_minutes', 5)
        expected_frames = playtime_minutes * 60 * 60  # Convert minutes to frames at 60fps

    # Calculate duration match (1.0 if matches expected, decreases for deviations)
    # Score should reward games that play close to intended playtime
    if expected_frames > 0:
        ratio = avg_duration / expected_frames
        # Clamp ratio between 0.5 and 2.0 (0.5x to 2x playtime is reasonable)
        # Beyond that gets capped to avoid extreme penalties/rewards
        clamped_ratio = max(0.5, min(2.0, ratio))
        # Score decreases as we deviate from 1.0 (perfect match)
        # At ratio=1.0: score=1.0, at 0.5 or 2.0: score=0.75
        duration_match = 1 - abs(clamped_ratio - 1.0) * 0.5
    else:
        duration_match = 0.5

    # Input activity as action variety proxy
    action_variety = min(1.0, input_rate * 3)  # Normalize to 0-1

    # Weighted engagement score
    engagement = (
        completion_rate * 0.5 +
        duration_match * 0.3 +
        action_variety * 0.2
    )

    return round(min(1.0, engagement), 3)


def assess_difficulty(game_metrics):
    """Assess game difficulty based on completion rate.

    Returns dict with difficulty assessment and reasoning.
    """
    if not game_metrics or not game_metrics.get('has_sessions'):
        return {
            'assessment': 'unknown',
            'reasoning': 'No session data available'
        }

    metrics = game_metrics.get('metrics', {})
    completion_rate = metrics.get('completion_rate_pct', 0) / 100.0

    if completion_rate > 0.7:
        assessment = 'too_easy'
        reasoning = f'High completion rate ({completion_rate*100:.0f}%) suggests game is too easy'
    elif completion_rate < 0.3:
        assessment = 'too_hard'
        reasoning = f'Low completion rate ({completion_rate*100:.0f}%) suggests game is too hard'
    else:
        assessment = 'balanced'
        reasoning = f'Moderate completion rate ({completion_rate*100:.0f}%) indicates balanced difficulty'

    return {
        'assessment': assessment,
        'reasoning': reasoning,
        'completion_rate_pct': round(completion_rate * 100, 1),
        'session_count': game_metrics.get('session_count', 0)
    }


def identify_design_issues(game_metrics):
    """Identify potential design issues from gameplay data.

    Returns list of issue descriptions.
    """
    issues = []
    if not game_metrics or not game_metrics.get('has_sessions'):
        return issues

    metrics = game_metrics.get('metrics', {})
    completion_rate = metrics.get('completion_rate_pct', 0) / 100.0
    difficulty_cliff = metrics.get('difficulty_cliff_frame', None)
    avg_input_rate = metrics.get('input_activity_rate', 0)

    # Issue 1: High abandon rate
    if completion_rate < 0.2:
        issues.append(
            'Critical: Very few players complete the game. Check early-game pacing and onboarding.'
        )

    # Issue 2: Difficulty cliff
    if difficulty_cliff and difficulty_cliff < 600:  # Within first 10 seconds at 60fps
        issues.append(
            f'Critical: Difficulty spike very early (frame {difficulty_cliff}). Tutorial or early challenge too hard.'
        )

    # Issue 3: Low engagement
    if avg_input_rate < 0.05:
        issues.append(
            'Warning: Players are not engaging with controls. Game may be too passive or unclear.'
        )

    # Issue 4: Too easy
    if completion_rate > 0.9:
        issues.append(
            'Suggestion: Very high completion rate suggests game lacks challenge.'
        )

    # Issue 5: Moderate engagement issues
    if 0.2 < completion_rate <= 0.4:
        issues.append(
            'Warning: Lower-than-ideal completion rate suggests difficulty balancing needed.'
        )

    return issues


def generate_recommendations(game_metrics, metadata=None):
    """Generate actionable improvement recommendations.

    Returns list of recommendation strings.
    """
    recommendations = []
    if not game_metrics or not game_metrics.get('has_sessions'):
        return recommendations

    metrics = game_metrics.get('metrics', {})
    completion_rate = metrics.get('completion_rate_pct', 0) / 100.0
    difficulty_cliff = metrics.get('difficulty_cliff_frame', None)
    avg_duration = metrics.get('avg_duration_frames', 0)
    input_rate = metrics.get('input_activity_rate', 0)
    completion_breakdown = metrics.get('completion_breakdown', {})

    # Recommendation 1: High quit rate
    quit_rate = completion_breakdown.get('quit', 0) / game_metrics.get('session_count', 1)
    if quit_rate > 0.5:
        recommendations.append(
            'Add clearer objectives or feedback when player quits early'
        )

    # Recommendation 2: Difficulty progression
    if difficulty_cliff:
        recommendations.append(
            f'Add difficulty ramp-up before frame {difficulty_cliff} or add tutorial hints'
        )

    # Recommendation 3: Player engagement
    if input_rate < 0.1:
        recommendations.append(
            'Increase interactive elements: add more frequent decision points or actions'
        )

    # Recommendation 4: Session length optimization
    # Expected frames at 60fps: playtime_minutes * 60 seconds * 60 fps
    expected_frames = 5 * 60 * 60  # 5 minutes default = 18,000 frames
    if metadata:
        playtime_minutes = metadata.get('playtime_minutes', 5)
        expected_frames = playtime_minutes * 60 * 60  # Convert minutes to frames

    if avg_duration < expected_frames * 0.5:
        recommendations.append(
            'Game ends too quickly: consider extending content or reducing difficulty'
        )
    elif avg_duration > expected_frames * 2:
        recommendations.append(
            'Game takes too long: consider pacing improvements or streamlining content'
        )

    # Recommendation 5: Win condition clarity
    wins = completion_breakdown.get('won', 0)
    if wins > 0 and completion_rate < 0.5:
        recommendations.append(
            'Clarify win conditions: some players succeed but many do not'
        )

    if not recommendations:
        recommendations.append(
            'Game appears well-balanced. Consider playtesting for polish opportunities.'
        )

    return recommendations


def extract_player_behavior_patterns(game_metrics):
    """Extract patterns from player behavior.

    Returns dict with behavior insights.
    """
    patterns = {
        'most_common_playstyle': 'unknown',
        'average_session_duration_seconds': 0,
        'active_frames_percentage': 0,
        'primary_states': []
    }

    if not game_metrics or not game_metrics.get('has_sessions'):
        return patterns

    metrics = game_metrics.get('metrics', {})
    avg_duration = metrics.get('avg_duration_frames', 0)
    input_rate = metrics.get('input_activity_rate', 0)
    state_dist = metrics.get('avg_state_times', {})

    # Duration in seconds (estimate 60fps)
    patterns['average_session_duration_seconds'] = round(avg_duration / 60, 1)

    # Input percentage
    patterns['active_frames_percentage'] = round(input_rate * 100, 1)

    # Primary states
    if state_dist:
        sorted_states = sorted(state_dist.items(), key=lambda x: x[1], reverse=True)
        patterns['primary_states'] = [state for state, _ in sorted_states[:3]]

    # Playstyle classification
    if input_rate > 0.2:
        patterns['most_common_playstyle'] = 'action-heavy'
    elif input_rate > 0.1:
        patterns['most_common_playstyle'] = 'moderate'
    else:
        patterns['most_common_playstyle'] = 'passive'

    return patterns


def generate_insights(game_date, game_dir):
    """Generate comprehensive insights for a single game.

    Returns dict with insights, or None if no data available.
    """
    game_metrics = calculate_game_metrics(game_dir, game_date)
    if not game_metrics:
        return None

    metadata = load_metadata(game_dir)

    insights = {
        'date': game_date,
        'generated_at': datetime.now().isoformat(),
        'has_sessions': game_metrics.get('has_sessions', False),
        'session_count': game_metrics.get('session_count', 0),
    }

    if not game_metrics.get('has_sessions'):
        return insights

    # Core insights
    insights['difficulty_assessment'] = assess_difficulty(game_metrics)
    insights['engagement_score'] = calculate_engagement_score(game_metrics, metadata)
    insights['player_behavior_patterns'] = extract_player_behavior_patterns(game_metrics)
    insights['design_issues'] = identify_design_issues(game_metrics)
    insights['recommendations'] = generate_recommendations(game_metrics, metadata)

    # Aggregate metrics from game_metrics
    insights['metrics'] = game_metrics.get('metrics', {})

    return insights


def load_metadata(game_dir):
    """Load metadata.json for a game.

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
