#!/usr/bin/env python3
"""Session Insight Summarizer - Extract actionable feedback from recorded playtest sessions.

Analyzes recorded session_*.json files and generates concise, prioritized feedback for
rapid game iteration. Focuses on what to fix next, not detailed analysis.

Features:
- Completion summary (win rate, playtime)
- Critical failure points (states where 50%+ players quit)
- Input heatmap (button usage frequency)
- State flow visualization (player progression paths)
- Actionable next steps (1-3 specific recommendations with impact)

Usage:
  python3 tools/session-insight-summarizer.py 2026-03-08              # Single game
  python3 tools/session-insight-summarizer.py --all                   # All games with sessions
  python3 tools/session-insight-summarizer.py 2026-03-08 --append-assessment
"""

import os
import sys
import json
import argparse
import re
from pathlib import Path
from datetime import datetime
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


def find_sessions(game_dir, include_synthetic=False):
    """Find all recorded sessions for a game.

    By default, excludes synthetic sessions to prevent artificially generated
    data from contaminating real playtest insights.

    Args:
        game_dir: Path to game directory
        include_synthetic: If True, include synthetic sessions

    Returns list of (session_path, session_data) tuples.
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

                sessions.append((session_path, session))

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


def detect_completion_status(session):
    """Determine if session was completed based on logs and exit state.

    Returns one of: 'won', 'lost', 'quit'.
    """
    logs = session.get('logs', [])

    # Check logs for explicit win/loss
    for log in logs:
        if 'gameover:win' in log or 'win' in log.lower():
            return 'won'
        if 'gameover:lose' in log or 'gameover:loss' in log:
            return 'lost'

    return 'quit'


def extract_button_heatmap(button_sequence):
    """Extract button press counts from button sequence.

    Button encoding: bit 0=left, bit 1=right, bit 2=up, bit 3=down, bit 4=o, bit 5=x

    Returns dict of button_name -> count.
    """
    buttons = {
        'left': 0,
        'right': 0,
        'up': 0,
        'down': 0,
        'o_button': 0,
        'x_button': 0,
    }

    for btn_state in button_sequence:
        if not isinstance(btn_state, int):
            continue

        if btn_state & 1:  # bit 0 = left
            buttons['left'] += 1
        if btn_state & 2:  # bit 1 = right
            buttons['right'] += 1
        if btn_state & 4:  # bit 2 = up
            buttons['up'] += 1
        if btn_state & 8:  # bit 3 = down
            buttons['down'] += 1
        if btn_state & 16:  # bit 4 = o button
            buttons['o_button'] += 1
        if btn_state & 32:  # bit 5 = x button
            buttons['x_button'] += 1

    return buttons


def find_critical_failure_points(all_sessions):
    """Identify states where 50%+ of players quit or fail.

    Returns list of (state, failure_rate, frequency) tuples.
    """
    if not all_sessions:
        return []

    # Track which states players entered, and where they quit/failed
    state_entries = defaultdict(int)
    state_quits = defaultdict(int)

    for session in all_sessions:
        logs = session.get('logs', [])
        transitions = extract_state_transitions(logs)

        # Track state progression
        for i, (state, frame) in enumerate(transitions):
            state_entries[state] += 1

            # Check if this was the last state before quit/loss
            completion = detect_completion_status(session)

            # If this is the last state and completion is quit/lost, mark it
            if i == len(transitions) - 1 and completion in ['quit', 'lost']:
                state_quits[state] += 1

    # Calculate failure rates
    failures = []
    for state, entries in state_entries.items():
        if entries > 0:
            failure_rate = state_quits[state] / entries
            if failure_rate >= 0.5:  # 50%+ quit rate
                frequency = f"{state_quits[state]} of {entries} sessions"
                failures.append({
                    'location': f"state:{state}",
                    'failure_rate': round(failure_rate, 2),
                    'frequency': frequency,
                    'likely_cause': f"Player retention issue at {state}",
                })

    return sorted(failures, key=lambda x: x['failure_rate'], reverse=True)


def build_state_flow(all_sessions):
    """Generate a string representation of player progression paths.

    Returns string like "menu(3) → play(3) → gameover(2) / quit(1) + won(1)"
    """
    if not all_sessions:
        return ""

    # Track complete progressions
    progressions = []
    completion_counter = Counter()

    for session in all_sessions:
        logs = session.get('logs', [])
        transitions = extract_state_transitions(logs)

        if transitions:
            progression = " → ".join([state for state, _ in transitions])
            completion = detect_completion_status(session)
            progressions.append((progression, completion))
            completion_counter[completion] += 1

    # Find most common progression
    if progressions:
        prog_counter = Counter([p[0] for p in progressions])
        most_common_prog = prog_counter.most_common(1)[0][0]

        # Build outcome summary
        outcomes = []
        for status, count in completion_counter.most_common():
            outcomes.append(f"{status}({count})")

        outcome_str = " + ".join(outcomes) if outcomes else ""
        if outcome_str:
            return f"{most_common_prog} / {outcome_str}"
        else:
            return most_common_prog

    return ""


def generate_next_steps(game_dir, all_sessions, critical_failures, button_heatmap, state_flow):
    """Generate 1-3 actionable next steps based on session analysis.

    Returns list of recommendation dicts with priority, recommendation, estimated_impact, tokens.
    """
    recommendations = []

    if not all_sessions:
        return recommendations

    # Recommendation 1: Address critical failure points
    if critical_failures:
        worst_failure = critical_failures[0]
        state_name = worst_failure['location'].replace('state:', '')
        recommendations.append({
            'priority': 1,
            'recommendation': f"Critical failure point at '{state_name}' (50%+ quit rate) - check difficulty, clarity, or fairness",
            'estimated_impact': 'high',
            'estimated_tokens_to_fix': 30,
        })

    # Recommendation 2: Check input heatmap for unused controls
    unused_buttons = [btn for btn, count in button_heatmap.items()
                      if count == 0 and btn in ['x_button', 'down']]
    if unused_buttons and len(recommendations) < 3:
        btn_names = ', '.join(unused_buttons)
        recommendations.append({
            'priority': len(recommendations) + 1,
            'recommendation': f"Controls not used: {btn_names} - consider removing from tutorial or assigning functions",
            'estimated_impact': 'low',
            'estimated_tokens_to_fix': 5,
        })

    # Recommendation 3: Improve completion rate if low
    completions = Counter([detect_completion_status(s) for s in all_sessions])
    total = len(all_sessions)
    win_rate = completions.get('won', 0) / total if total > 0 else 0

    if win_rate < 0.5 and len(recommendations) < 3:
        recommendations.append({
            'priority': len(recommendations) + 1,
            'recommendation': f"Low completion rate ({int(win_rate*100)}% wins) - consider adding hints, reducing difficulty, or clarifying objectives",
            'estimated_impact': 'high' if win_rate < 0.33 else 'medium',
            'estimated_tokens_to_fix': 40,
        })

    return recommendations


def generate_report(game_date, game_dir):
    """Generate session summary report for a game.

    Returns dict with all insight data, or None if no sessions found.
    """
    sessions = find_sessions(game_dir)

    if not sessions:
        return None

    all_sessions = [s[1] for s in sessions]

    # Completion summary
    completions = Counter([detect_completion_status(s) for s in all_sessions])
    total_sessions = len(all_sessions)
    completion_rate = completions.get('won', 0) / total_sessions if total_sessions > 0 else 0

    # Playtime stats (in seconds, assuming 60fps)
    durations_seconds = [s.get('duration_frames', 0) / 60.0 for s in all_sessions]
    avg_playtime = statistics.mean(durations_seconds) if durations_seconds else 0

    # Button heatmap (aggregate across all sessions)
    combined_buttons = Counter()
    for session in all_sessions:
        heatmap = extract_button_heatmap(session.get('button_sequence', []))
        for btn, count in heatmap.items():
            combined_buttons[btn] += count

    button_heatmap = dict(combined_buttons)

    # State flow
    state_flow = build_state_flow(all_sessions)

    # Critical failure points
    critical_failures = find_critical_failure_points(all_sessions)

    # Next steps
    next_steps = generate_next_steps(game_dir, all_sessions, critical_failures, button_heatmap, state_flow)

    return {
        'game_date': game_date,
        'sessions_analyzed': total_sessions,
        'completion_summary': {
            'completion_rate': round(completion_rate, 2),
            'avg_playtime_seconds': round(avg_playtime, 1),
            'wins': completions.get('won', 0),
            'losses': completions.get('lost', 0),
            'quits': completions.get('quit', 0),
        },
        'critical_failure_points': critical_failures,
        'input_heatmap': button_heatmap,
        'state_flow': state_flow,
        'next_steps': next_steps,
    }


def append_to_assessment(game_dir, report):
    """Append session insights to assessment.md.

    Creates assessment.md if it doesn't exist, or appends to existing file.
    """
    assessment_path = os.path.join(game_dir, 'assessment.md')

    # Generate markdown
    lines = ['## Session Insights', '']

    # Completion summary
    completion = report['completion_summary']
    lines.append(f"**Sessions analyzed**: {report['sessions_analyzed']}")
    lines.append(f"**Completion rate**: {int(completion['completion_rate']*100)}%")
    lines.append(f"**Average playtime**: {completion['avg_playtime_seconds']:.0f}s")
    lines.append(f"**Outcomes**: {completion['wins']} wins, {completion['losses']} losses, {completion['quits']} quits")
    lines.append('')

    # State flow
    if report['state_flow']:
        lines.append(f"**Player flow**: {report['state_flow']}")
        lines.append('')

    # Critical failures
    if report['critical_failure_points']:
        lines.append('**Critical failure points**:')
        for failure in report['critical_failure_points']:
            lines.append(f"- {failure['location']}: {failure['failure_rate']*100:.0f}% quit rate ({failure['frequency']})")
        lines.append('')

    # Input usage
    heatmap = report['input_heatmap']
    used_buttons = [btn for btn, count in heatmap.items() if count > 0]
    if used_buttons:
        lines.append(f"**Input usage**: {', '.join(used_buttons)}")
        lines.append('')

    # Next steps
    if report['next_steps']:
        lines.append('**Next steps** (prioritized):')
        for step in report['next_steps']:
            lines.append(f"{step['priority']}. {step['recommendation']} ({step['estimated_impact']} impact, ~{step['estimated_tokens_to_fix']} tokens)")
        lines.append('')

    # Append to file
    content = '\n'.join(lines)

    if os.path.exists(assessment_path):
        # Append to existing file
        with open(assessment_path, 'a') as f:
            f.write('\n' + content)
    else:
        # Create new file
        with open(assessment_path, 'w') as f:
            f.write(content)


def find_all_games_with_sessions():
    """Find all game directories that have sessions.

    Returns list of (date, game_dir) tuples.
    """
    games = []
    games_dir = 'games'

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        game_dir = os.path.join(games_dir, entry)
        if os.path.isdir(game_dir) and os.path.exists(os.path.join(game_dir, 'game.p8')):
            # Check if game has sessions
            sessions = find_sessions(game_dir)
            if sessions:
                games.append((entry, game_dir))

    return games


def main():
    parser = argparse.ArgumentParser(
        description='Extract actionable insights from recorded playtest sessions'
    )
    parser.add_argument(
        'game_date',
        nargs='?',
        help='Game date (YYYY-MM-DD) to analyze. If omitted with --all, analyzes all games.'
    )
    parser.add_argument(
        '--all',
        action='store_true',
        help='Analyze all games with sessions instead of a single game'
    )
    parser.add_argument(
        '--append-assessment',
        action='store_true',
        help='Append insights to game assessment.md'
    )

    args = parser.parse_args()

    if args.all:
        # Analyze all games with sessions
        games = find_all_games_with_sessions()
        if not games:
            print("No games with sessions found.")
            return

        print(f"Analyzing {len(games)} games with sessions...\n")

        for game_date, game_dir in games:
            report = generate_report(game_date, game_dir)
            if report:
                # Save report
                report_path = os.path.join(game_dir, 'session-summary.json')
                with open(report_path, 'w') as f:
                    json.dump(report, f, indent=2)

                # Optionally append to assessment
                if args.append_assessment:
                    append_to_assessment(game_dir, report)

                print(f"✓ {game_date}: {report['sessions_analyzed']} sessions, "
                      f"{int(report['completion_summary']['completion_rate']*100)}% completion")

    elif args.game_date:
        # Analyze single game
        game_dir = os.path.join('games', args.game_date)

        if not os.path.isdir(game_dir):
            print(f"Game directory not found: {game_dir}")
            sys.exit(1)

        report = generate_report(args.game_date, game_dir)

        if not report:
            print(f"No sessions found for {args.game_date}")
            sys.exit(1)

        # Save report
        report_path = os.path.join(game_dir, 'session-summary.json')
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"Session summary saved to {report_path}")

        # Print summary to stdout
        completion = report['completion_summary']
        print(f"\nSessions analyzed: {report['sessions_analyzed']}")
        print(f"Completion rate: {int(completion['completion_rate']*100)}%")
        print(f"Average playtime: {completion['avg_playtime_seconds']:.0f}s")
        print(f"Outcomes: {completion['wins']} wins, {completion['losses']} losses, {completion['quits']} quits")

        if report['state_flow']:
            print(f"Player flow: {report['state_flow']}")

        if report['critical_failure_points']:
            print("\nCritical failure points:")
            for failure in report['critical_failure_points']:
                print(f"  - {failure['location']}: {failure['failure_rate']*100:.0f}% quit rate")

        if report['next_steps']:
            print("\nNext steps (prioritized):")
            for step in report['next_steps']:
                print(f"  {step['priority']}. {step['recommendation']}")
                print(f"     Impact: {step['estimated_impact']}, Tokens: ~{step['estimated_tokens_to_fix']}")

        # Optionally append to assessment
        if args.append_assessment:
            append_to_assessment(game_dir, report)
            print(f"\nAppended insights to assessment.md")

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
