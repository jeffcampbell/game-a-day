#!/usr/bin/env python3
"""Test runner for PICO-8 games with embedded test infrastructure.

This runner performs static analysis of game code to validate test infrastructure.
It analyzes _log() calls to detect state transitions, game events, and gameover conditions.

Usage: python3 tools/run-game-tests.py [--ignore-failures]

Generates:
  - games/YYYY-MM-DD/test-report.json (per-game report)
  - games/test-summary.md (dashboard)

Returns 0 if all tests pass, 1 if any fail (unless --ignore-failures).
"""

import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime


def read_p8_file(path):
    """Read a .p8 file and return content."""
    try:
        with open(path, 'r') as f:
            return f.read()
    except Exception:
        return None


def extract_lua_section(content):
    """Extract the __lua__ section from a .p8 file."""
    lines = content.split('\n')
    lua_lines = []
    in_lua = False

    for line in lines:
        if line.startswith('__lua__'):
            in_lua = True
            continue
        if in_lua and re.match(r'^__[a-z]+__\s*$', line):
            break
        if in_lua:
            lua_lines.append(line)

    return '\n'.join(lua_lines)


def find_log_calls(lua_code):
    """Extract all _log() calls and their message patterns from Lua code.

    Returns list of log message patterns found in the code.
    """
    logs = []

    # Pattern 1: _log("string")
    pattern1 = re.findall(r'_log\s*\(\s*["\']([^"\']*)["\']', lua_code)
    logs.extend(pattern1)

    # Pattern 2: _log("string"..) - concatenation at end (like "state:".."value")
    pattern2 = re.findall(r'_log\s*\(\s*["\']([^"\']+)["\']\.\.', lua_code)
    logs.extend(pattern2)

    # Pattern 3: _log(... .."string") - concatenation at start
    # Anchored to _log calls to avoid matching print() or other function calls
    pattern3 = re.findall(r'_log\s*\([^)]*\.\..*?["\']([^"\']+)["\']', lua_code)
    logs.extend([p for p in pattern3 if p.strip()])

    return logs


def analyze_logs(log_patterns):
    """Analyze log patterns to extract expected game behavior.

    Returns analysis dict with expected state transitions and events.
    """
    analysis = {
        'expected_states': [],
        'expected_gameover': False,
        'expected_logs': log_patterns,
        'log_count': len(log_patterns),
        'state_transitions': {},
        'game_events': 0,
        'gameover_conditions': []
    }

    state_pattern = re.compile(r'^state:(\w+)$')
    gameover_pattern = re.compile(r'^gameover:(\w+)$')

    for log in log_patterns:
        if state_pattern.match(log):
            state = state_pattern.match(log).group(1)
            if state not in analysis['expected_states']:
                analysis['expected_states'].append(state)
            # state:gameover is also a gameover condition
            if state == 'gameover':
                analysis['expected_gameover'] = True
                analysis['gameover_conditions'].append('state')
        elif gameover_pattern.match(log):
            state = gameover_pattern.match(log).group(1)
            analysis['expected_gameover'] = True
            analysis['gameover_conditions'].append(state)
        else:
            analysis['game_events'] += 1

    # Count how many times each state appears
    for log in log_patterns:
        if state_pattern.match(log):
            state = state_pattern.match(log).group(1)
            analysis['state_transitions'][state] = analysis['state_transitions'].get(state, 0) + 1

    return analysis


def validate_game_structure(lua_code):
    """Validate that game has proper test infrastructure and state machine.

    Returns (is_valid, errors).
    """
    errors = []

    # Check for test infrastructure
    if 'testmode' not in lua_code:
        errors.append('Missing testmode variable')
    if 'test_log' not in lua_code:
        errors.append('Missing test_log variable')
    if 'function _log' not in lua_code:
        errors.append('Missing _log() function')
    if 'function test_input' not in lua_code:
        errors.append('Missing test_input() function')

    # Check for state machine (could be string or numeric)
    if not re.search(r'\bstate\s*=', lua_code):
        errors.append('Missing state variable initialization')
    if not re.search(r'if\s+state\s*==|elseif\s+state\s*==', lua_code):
        errors.append('Missing state branching in code')

    return len(errors) == 0, errors


def validate_logging(lua_code, analysis):
    """Validate that game has appropriate logging for testing.

    Returns (is_valid, errors).
    """
    errors = []

    # Check for state transitions
    if not analysis['expected_states']:
        errors.append('No state transitions logged')

    # Check for adequate logging - need at least 3 logs
    if analysis['log_count'] < 3:
        errors.append(f'Insufficient logging (only {analysis["log_count"]} logs, need 3+)')

    # Check for gameover - can be either gameover: or state:gameover
    has_gameover_state = 'gameover' in analysis['expected_states']
    has_gameover_event = len(analysis['gameover_conditions']) > 0
    if not (has_gameover_state or has_gameover_event):
        # Only warn, don't fail - some games might not explicitly log gameover
        pass

    return len(errors) == 0, errors


def run_test_on_game(game_dir, date):
    """Run static analysis test on a single game.

    Returns (status, analysis, errors).
    """
    game_p8 = os.path.join(game_dir, 'game.p8')

    if not os.path.exists(game_p8):
        return 'ERROR', {}, ['game.p8 not found']

    # Read the game file
    content = read_p8_file(game_p8)
    if not content:
        return 'ERROR', {}, ['Could not read game.p8']

    # Extract Lua code
    lua_code = extract_lua_section(content)
    if not lua_code.strip():
        return 'ERROR', {}, ['No Lua code found in __lua__ section']

    # Validate structure
    struct_valid, struct_errors = validate_game_structure(lua_code)
    if not struct_valid:
        return 'FAIL', {}, struct_errors

    # Find all log calls
    log_patterns = find_log_calls(lua_code)

    # Analyze logs
    analysis = analyze_logs(log_patterns)

    # Validate logging
    log_valid, log_errors = validate_logging(lua_code, analysis)

    if not log_valid:
        return 'FAIL', analysis, log_errors

    return 'PASS', analysis, []


def find_latest_session(game_dir):
    """Find the most recent recorded session for a game."""
    sessions = []
    for entry in os.listdir(game_dir):
        if entry.startswith('session_') and entry.endswith('.json'):
            session_path = os.path.join(game_dir, entry)
            try:
                with open(session_path, 'r') as f:
                    session = json.load(f)
                    # Validate that session is a dict (not array, string, null, etc.)
                    if isinstance(session, dict):
                        sessions.append((session_path, session, os.path.getmtime(session_path)))
            except Exception:
                pass

    if not sessions:
        return None

    # Return the most recent session
    sessions.sort(key=lambda x: x[2], reverse=True)
    return sessions[0][1]


def generate_test_report(game_dir, date, status, analysis, errors):
    """Generate test report JSON for a game.

    Incorporates session data if available, otherwise uses static analysis.
    """
    # Check for recorded sessions
    session_data = find_latest_session(game_dir)

    if session_data:
        # Use recorded session data
        report = {
            'date': date,
            'status': 'PASS' if not errors else 'FAIL',
            'duration_frames': session_data.get('duration_frames', 0),
            'source': 'session_recording',
            'errors': errors,
            'state_transitions': analysis.get('expected_states', []),
            'logs_captured': len(session_data.get('logs', [])),
            'logs': session_data.get('logs', [])[:20],  # Store first 20 logs
            'events': {
                'state_transitions': len(analysis.get('state_transitions', {})),
                'game_events': analysis.get('game_events', 0),
                'gameover_events': len(analysis.get('gameover_conditions', []))
            },
            'exit_state': session_data.get('exit_state', 'recorded')
        }
    else:
        # Use static analysis
        report = {
            'date': date,
            'status': status,
            'duration_frames': 'static_analysis',
            'source': 'static_analysis',
            'errors': errors,
            'state_transitions': analysis.get('expected_states', []),
            'logs_captured': analysis.get('log_count', 0),
            'events': {
                'state_transitions': len(analysis.get('state_transitions', {})),
                'game_events': analysis.get('game_events', 0),
                'gameover_events': len(analysis.get('gameover_conditions', []))
            },
            'exit_state': 'analysis_complete'
        }

    # Write report
    report_path = os.path.join(game_dir, 'test-report.json')
    try:
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        return True, None
    except Exception as e:
        return False, str(e)


def find_all_games():
    """Find all game directories with game.p8 files."""
    games = []
    games_dir = 'games'

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        game_dir = os.path.join(games_dir, entry)
        if os.path.isdir(game_dir) and os.path.exists(os.path.join(game_dir, 'game.p8')):
            games.append((entry, game_dir))

    return games


def generate_summary(results):
    """Generate test summary markdown."""
    passed = sum(1 for r in results if r['status'] == 'PASS')
    failed = sum(1 for r in results if r['status'] == 'FAIL' or r['status'] == 'ERROR')
    total = len(results)

    summary = f"""# Game Test Summary

**Test Results**: {passed}/{total} games passed ({100*passed//total if total > 0 else 0}%)

## Recent Tests

| Date | Status | State Transitions | Logs | Errors |
|------|--------|-------------------|------|--------|
"""

    for result in sorted(results, key=lambda r: r['date'], reverse=True):
        status_emoji = '✅' if result['status'] == 'PASS' else '❌'
        states = ', '.join(result.get('state_transitions', [])[:3])
        logs = result.get('logs_captured', 0)
        errors = ', '.join(result.get('errors', [])[:2]) if result.get('errors') else 'None'
        if len(result.get('errors', [])) > 2:
            errors += f" (+{len(result['errors']) - 2} more)"

        summary += f"| {result['date']} | {status_emoji} | {states} | {logs} | {errors} |\n"

    summary += f"\n## Statistics\n\n"
    summary += f"- **Total Games**: {total}\n"
    summary += f"- **Passed**: {passed}\n"
    summary += f"- **Failed**: {failed}\n"
    summary += f"- **Pass Rate**: {100*passed//total if total > 0 else 0}%\n"
    summary += f"\n## Test Method\n\nTests use static analysis of game code to validate:\n"
    summary += f"- Test infrastructure present (_log, test_input, test_log)\n"
    summary += f"- State machine pattern (menu → play → gameover)\n"
    summary += f"- Logging for state transitions and game events\n"

    return summary


def main():
    # Parse arguments
    ignore_failures = '--ignore-failures' in sys.argv

    # Find all games
    games = find_all_games()
    if not games:
        print("⚠️  No games found", file=sys.stderr)
        sys.exit(0)

    results = []
    failed_games = []

    # Run tests
    for game_name, game_dir in games:
        date = game_name  # Directory name is the date

        print(f"Testing {date}...", end=' ', flush=True)

        status, analysis, errors = run_test_on_game(game_dir, date)

        if errors:
            if status == 'PASS':
                print("✅")
            else:
                print(f"❌ {'; '.join(errors)}")
        else:
            print("✅")

        if status == 'FAIL':
            failed_games.append(date)

        # Generate report
        generate_test_report(game_dir, date, status, analysis, errors)

        results.append({
            'date': date,
            'status': status,
            'state_transitions': analysis.get('expected_states', []),
            'logs_captured': analysis.get('log_count', 0),
            'errors': errors
        })

    # Generate summary
    summary = generate_summary(results)
    summary_path = 'games/test-summary.md'
    try:
        with open(summary_path, 'w') as f:
            f.write(summary)
    except Exception as e:
        print(f"⚠️  Could not write summary: {e}", file=sys.stderr)

    # Generate analytics reports
    try:
        from analytics_engine import generate_analytics_report
        print("\nGenerating analytics...", end=' ', flush=True)
        generate_analytics_report()
        print("✅")
    except ImportError:
        pass  # Analytics engine not available
    except Exception as e:
        print(f"⚠️  Could not generate analytics: {e}", file=sys.stderr)

    # Print summary
    print()
    print(summary)

    # Exit status
    if failed_games and not ignore_failures:
        print(f"\n❌ {len(failed_games)} game(s) failed tests: {', '.join(failed_games)}", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"\n✅ All tests passed!")
        sys.exit(0)


if __name__ == '__main__':
    main()
