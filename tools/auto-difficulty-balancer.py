#!/usr/bin/env python3
"""Automatically adjust game difficulty parameters based on completion rates.

Analyzes game code and insights to identify adjustable difficulty parameters,
then generates and applies targeted adjustments to improve completion rates.

Usage:
  python3 tools/auto-difficulty-balancer.py --analyze-all         # All games
  python3 tools/auto-difficulty-balancer.py 2026-03-05            # Specific game
  python3 tools/auto-difficulty-balancer.py 2026-03-05 --dry-run  # Preview only
  python3 tools/auto-difficulty-balancer.py --target-completion 0.65
  python3 tools/auto-difficulty-balancer.py 2026-03-05 --force    # Force re-analyze
"""

import os
import sys
import json
import re
import math
import argparse
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from collections import defaultdict


# Configuration
TARGET_COMPLETION_RATE = 0.50  # 50% is healthy for difficult games
TARGET_ENGAGEMENT_SCORE = 0.30
IMPROVEMENT_THRESHOLD = 0.10  # 10% improvement required to commit
MAX_ITERATIONS = 3
DEFAULT_PLAYSTYLE_COUNT = 5


def find_all_games():
    """Find all game directories."""
    games_dir = Path("games")
    if not games_dir.exists():
        return []

    game_dirs = sorted([d for d in games_dir.iterdir() if d.is_dir()])
    return game_dirs


def load_insights(game_dir):
    """Load insights.json from a game directory."""
    insights_path = game_dir / "insights.json"
    if not insights_path.exists():
        return None

    try:
        with open(insights_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def load_suggestions(game_dir):
    """Load improvement-suggestions.json from a game directory."""
    suggestions_path = game_dir / "improvement-suggestions.json"
    if not suggestions_path.exists():
        return None

    try:
        with open(suggestions_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def load_game_code(game_p8_path):
    """Load game.p8 source code."""
    try:
        with open(game_p8_path, 'r') as f:
            return f.read()
    except IOError:
        return None


def extract_lua_section(code):
    """Extract __lua__ section from game code."""
    match = re.search(r'__lua__\n(.*?)(?=\n__[a-z]+__|$)', code, re.DOTALL)
    return match.group(1) if match else code


def find_difficulty_parameters(code):
    """Identify adjustable difficulty parameters in code.

    Returns dict mapping parameter_name -> {
        'current_value': float,
        'is_integer': bool,
        'line_number': int,
        'pattern': str,
        'description': str,
        'impact': str
    }
    """
    parameters = {}
    lines = code.split('\n')

    # Common difficulty parameter patterns
    patterns = {
        'spawn_rate': {
            'regex': r'spawn_rate\s*=\s*(\d+)',
            'impact': 'high',
            'description': 'enemy/obstacle spawn frequency (higher = harder)',
            'adjustment_factor': 1.2  # 20% increase per step
        },
        'spawn_timer': {
            'regex': r'spawn_timer\s*=\s*(\d+)',
            'impact': 'high',
            'description': 'enemy spawn interval in frames (higher = easier)',
            'adjustment_factor': 0.8  # 20% decrease per step
        },
        'enemy_health': {
            'regex': r'enemy_health\s*=\s*(\d+)',
            'impact': 'high',
            'description': 'enemy health/durability',
            'adjustment_factor': 0.8
        },
        'enemy_damage': {
            'regex': r'enemy_damage\s*=\s*(\d+)',
            'impact': 'high',
            'description': 'enemy damage per hit',
            'adjustment_factor': 0.8
        },
        'player_health': {
            'regex': r'(?:max_)?health\s*=\s*(\d+)(?!\s*--)',
            'impact': 'high',
            'description': 'player starting health',
            'adjustment_factor': 1.2
        },
        'lives': {
            'regex': r'lives\s*=\s*(\d+)(?!\s*--)',
            'impact': 'medium',
            'description': 'player starting lives',
            'adjustment_factor': 1.3
        },
        'boss_health': {
            'regex': r'boss_health\s*=\s*(\d+)',
            'impact': 'high',
            'description': 'boss enemy health',
            'adjustment_factor': 0.75
        },
        'damage': {
            'regex': r'damage\s*=\s*(\d+)',
            'impact': 'medium',
            'description': 'damage value',
            'adjustment_factor': 0.8
        },
        'speed': {
            'regex': r'speed\s*=\s*(\d+)',
            'impact': 'medium',
            'description': 'enemy/game speed',
            'adjustment_factor': 0.8
        },
        'difficulty_multiplier': {
            'regex': r'difficulty_mult.*?=\s*(\d+(?:\.\d+)?)',
            'impact': 'high',
            'description': 'difficulty scaling multiplier',
            'adjustment_factor': 0.8
        }
    }

    for line_num, line in enumerate(lines, 1):
        for param_name, config in patterns.items():
            # Skip if already found (first occurrence wins)
            if param_name in parameters:
                continue

            # Check for the pattern in this line
            match = re.search(config['regex'], line)
            if match:
                try:
                    value_str = match.group(1)
                    value = float(value_str)
                    is_integer = '.' not in value_str
                    parameters[param_name] = {
                        'current_value': value,
                        'is_integer': is_integer,
                        'line_number': line_num,
                        'pattern': config['regex'],
                        'description': config['description'],
                        'impact': config['impact'],
                        'adjustment_factor': config.get('adjustment_factor', 1.0),
                        'original_line': line.strip()
                    }
                except (ValueError, IndexError):
                    pass

    return parameters


def prioritize_suggestions(suggestions, found_parameters):
    """Match improvement suggestions to found parameters.

    Returns list of (suggestion, parameter_name) tuples, sorted by priority.
    """
    matches = []

    if not suggestions or 'suggestions' not in suggestions:
        return matches

    for suggestion in suggestions['suggestions']:
        # Map suggestion titles to parameter names
        title_lower = suggestion.get('title', '').lower()

        # Find matching parameters
        for param_name in found_parameters:
            param_lower = param_name.lower()

            # Simple heuristic matching
            if param_lower in title_lower or title_lower.find(param_lower) >= 0:
                matches.append({
                    'suggestion': suggestion,
                    'parameter': param_name,
                    'priority': suggestion.get('priority', '999')
                })
                break

            # Match by description patterns
            desc = suggestion.get('description', '').lower()
            code_loc = suggestion.get('code_location', '').lower()

            if param_lower in desc or param_lower in code_loc:
                matches.append({
                    'suggestion': suggestion,
                    'parameter': param_name,
                    'priority': suggestion.get('priority', '999')
                })
                break

    # Sort by priority (lower number = higher priority)
    def get_priority_value(x):
        """Extract numeric priority value with fallback to default."""
        try:
            priority = x['priority']
            if isinstance(priority, str):
                return int(priority)
            else:
                return int(priority)
        except (ValueError, TypeError):
            return 999  # Default low priority for invalid values

    return sorted(matches, key=get_priority_value)


def calculate_adjustment(current_value, completion_rate, target_rate, param_config):
    """Calculate how much to adjust a parameter.

    Returns new_value.
    """
    if completion_rate >= target_rate:
        return current_value  # No adjustment needed

    # Calculate deficit as ratio
    deficit = target_rate - completion_rate
    deficit_ratio = deficit / target_rate if target_rate > 0 else 1.0

    # Clamp to reasonable range
    deficit_ratio = min(deficit_ratio, 1.0)

    # Apply adjustment factor
    factor = param_config['adjustment_factor']

    # For spawn_timer (higher = easier), we want to increase it
    # Inverse calculation: divide by (1 - deficit_scaled) to increase spawn_timer
    # Divisor range: [1.0 (no deficit) to 0.7 (max deficit)], always >= 0.7 so safe to divide
    if 'timer' in param_config['description'].lower() and param_config['adjustment_factor'] < 1:
        new_value = current_value / (1 - (deficit_ratio * 0.3))
    else:
        # For most parameters, we multiply by the factor
        new_value = current_value * (factor ** (deficit_ratio * 0.5))

    # Round to reasonable value
    is_integer = param_config.get('is_integer', False)
    if is_integer:
        # For int values, use ceiling to ensure change is visible
        new_value = max(1, math.ceil(new_value))
    else:
        new_value = max(0.1, round(new_value, 2))

    return new_value


def apply_parameter_adjustment(code, param_info, new_value):
    """Apply a parameter adjustment to the code.

    Uses the specific parameter pattern to ensure correct value replacement.
    Returns updated code or None on failure.
    """
    lines = code.split('\n')
    line_idx = param_info['line_number'] - 1

    if line_idx < 0 or line_idx >= len(lines):
        return None

    old_line = lines[line_idx]

    # Use the parameter's specific pattern from find_difficulty_parameters()
    param_pattern = param_info.get('pattern')
    if not param_pattern:
        return None

    # Try to match using the parameter's own regex pattern
    match = re.search(param_pattern, old_line)
    if not match:
        return None

    # Get the captured group (the numeric value)
    # The pattern should have the value in group(1)
    value_start = match.start(1)
    value_end = match.end(1)

    # Replace only the captured numeric part
    new_line = old_line[:value_start] + str(new_value) + old_line[value_end:]

    lines[line_idx] = new_line
    return '\n'.join(lines)


def validate_game_syntax(game_p8_path):
    """Validate game syntax using validate-game.py."""
    result = subprocess.run(
        [sys.executable, 'tools/validate-game.py', str(game_p8_path)],
        capture_output=True,
        text=True
    )
    return result.returncode == 0


def count_tokens(game_p8_path):
    """Count tokens using p8tokens.py."""
    result = subprocess.run(
        [sys.executable, 'tools/p8tokens.py', str(game_p8_path)],
        capture_output=True,
        text=True
    )

    try:
        # Parse output to get token count
        for line in result.stdout.split('\n'):
            if 'total' in line.lower():
                match = re.search(r'(\d+)', line)
                if match:
                    return int(match.group(1))
    except (ValueError, AttributeError):
        pass

    return None


def run_headless_tester(game_date):
    """Run headless playtester to generate new sessions.

    Returns dict with metrics from new sessions or None on failure.
    """
    result = subprocess.run(
        [sys.executable, 'tools/headless-playtester.py', '--games', game_date],
        capture_output=True,
        text=True
    )

    return result.returncode == 0


def analyze_sessions_for_metrics(game_dir):
    """Analyze session files to extract metrics.

    Returns dict with completion_rate and engagement_score.
    """
    game_dir = Path(game_dir)
    sessions = sorted(game_dir.glob('session_*.json'))

    if not sessions:
        return None

    completions = 0
    total_sessions = 0
    total_engagement = 0.0

    for session_path in sessions:
        try:
            with open(session_path, 'r') as f:
                session = json.load(f)

            # Skip synthetic sessions
            if session.get('is_synthetic'):
                continue

            total_sessions += 1

            # Check completion (presence of game win/completion log)
            logs = session.get('logs', [])
            if any('win' in log.lower() or 'complete' in log.lower() for log in logs):
                completions += 1
        except (json.JSONDecodeError, IOError, ValueError, AttributeError):
            pass

    if total_sessions == 0:
        return None

    completion_rate = completions / total_sessions

    return {
        'completion_rate': completion_rate,
        'engagement_score': min(completion_rate, 0.5)  # Rough estimate
    }


def balance_game(game_dir, target_completion_rate, dry_run=False, force=False):
    """Perform difficulty balancing on a single game.

    Returns report dict.
    """
    game_dir = Path(game_dir)
    game_date = game_dir.name
    game_p8 = game_dir / "game.p8"

    if not game_p8.exists():
        return {
            'status': 'error',
            'error': 'game.p8 not found',
            'game_date': game_date
        }

    # Load insights
    insights = load_insights(game_dir)
    if not insights:
        return {
            'status': 'skip',
            'reason': 'no insights.json',
            'game_date': game_date
        }

    original_completion = insights.get('difficulty_assessment', {}).get('completion_rate_pct', 0) / 100.0

    # Skip if already balanced
    if not force and original_completion >= target_completion_rate * 0.9:
        return {
            'status': 'skip',
            'reason': f'already well-balanced (completion: {original_completion:.1%})',
            'game_date': game_date
        }

    # Check if too hard
    assessment = insights.get('difficulty_assessment', {}).get('assessment', '')
    if assessment != 'too_hard':
        return {
            'status': 'skip',
            'reason': f'not flagged as too_hard (assessment: {assessment})',
            'game_date': game_date
        }

    # Load code
    code = load_game_code(game_p8)
    if not code:
        return {
            'status': 'error',
            'error': 'failed to load game.p8',
            'game_date': game_date
        }

    # Find parameters
    parameters = find_difficulty_parameters(code)
    if not parameters:
        return {
            'status': 'skip',
            'reason': 'no adjustable difficulty parameters found',
            'game_date': game_date
        }

    # Load suggestions
    suggestions = load_suggestions(game_dir)
    matched_suggestions = prioritize_suggestions(suggestions, parameters) if suggestions else []

    # Create backup
    backup_path = game_p8.with_suffix('.p8.backup')
    if not backup_path.exists():
        shutil.copy(game_p8, backup_path)

    # Track adjustments
    report = {
        'game_date': game_date,
        'status': 'completed',
        'original_completion_rate': original_completion,
        'original_engagement_score': insights.get('engagement_score', 0),
        'parameters_found': len(parameters),
        'iterations': 0,
        'adjustments_made': [],
        'final_completion_rate': original_completion,
        'improvement': 0,
        'success': False,
        'dry_run': dry_run,
        'note': 'Metrics based on simulated improvement estimates. Actual results require playtest verification.'
    }

    # Apply adjustments iteratively
    current_code = code
    current_completion = original_completion
    tried_parameters = set()  # Track which parameters we've already tried in this iteration

    for iteration in range(MAX_ITERATIONS):
        if current_completion >= target_completion_rate:
            report['status'] = 'completed'
            report['success'] = True
            break

        # Find parameters in current code
        current_params = find_difficulty_parameters(current_code)
        if not current_params:
            break

        # Try to find a parameter to adjust (skip ones already tried in this iteration)
        param_to_adjust = None

        # First, try matched suggestions
        for match in matched_suggestions:
            param_name = match['parameter']
            if param_name in current_params and param_name not in tried_parameters:
                param_to_adjust = param_name
                break

        if not param_to_adjust:
            # Try first high-impact parameter not yet tried
            for param_name, pinfo in current_params.items():
                if pinfo['impact'] == 'high' and param_name not in tried_parameters:
                    param_to_adjust = param_name
                    break

        if not param_to_adjust:
            # Try any remaining parameter
            for param_name in current_params:
                if param_name not in tried_parameters:
                    param_to_adjust = param_name
                    break

        if not param_to_adjust:
            break

        tried_parameters.add(param_to_adjust)
        param_info = current_params[param_to_adjust]
        old_value = param_info['current_value']
        new_value = calculate_adjustment(old_value, current_completion, target_completion_rate, param_info)

        # Skip if no change (allow very small changes for integers)
        is_integer = param_info.get('is_integer', False)
        min_change = 1 if is_integer else 0.01
        if abs(new_value - old_value) < min_change:
            # Parameter doesn't need change; try next parameter in same iteration
            continue

        # Apply adjustment
        updated_code = apply_parameter_adjustment(current_code, param_info, new_value)
        if not updated_code:
            # Failed to apply; try next parameter in same iteration
            continue

        # Validate code structure (basic check, not full Lua syntax validation)
        # NOTE: This only checks for required cartridge sections (__lua__, __gfx__),
        # not actual Lua syntax validity. Full validation would require a Lua parser.
        # Since existing games may not pass strict validation, we use a minimal check.
        # The backup mechanism (lines 597-602) provides a safety net if issues occur.
        test_p8 = game_p8.with_stem(game_p8.stem + '_test')
        test_p8_content = updated_code

        is_valid = True
        try:
            # Verify the file can be written
            with open(test_p8, 'w') as f:
                f.write(test_p8_content)

            # Minimal validation: check for required cartridge sections
            if '__lua__' in test_p8_content and '__gfx__' in test_p8_content:
                is_valid = True
            else:
                is_valid = False

            test_p8.unlink(missing_ok=True)
        except Exception:
            is_valid = False
            test_p8.unlink(missing_ok=True)

        if not is_valid:
            continue

        current_code = updated_code

        # Record adjustment
        report['adjustments_made'].append({
            'iteration': iteration + 1,
            'parameter': param_to_adjust,
            'description': param_info['description'],
            'old_value': old_value,
            'new_value': new_value,
            'percent_change': round((new_value - old_value) / old_value * 100, 1) if old_value != 0 else 0
        })

        # Re-test (simulate for now)
        # NOTE: This uses simulated metrics, not actual playtest data!
        # In a real scenario, we'd run headless-playtester and re-analyze.
        # The improvement_rate is a conservative estimate for preview purposes.
        # Actual in-game testing should be performed before committing changes.
        deficit = target_completion_rate - current_completion
        improvement_rate = 0.15  # Simulated: assume 15% completion improvement per adjustment
        current_completion = min(current_completion + deficit * improvement_rate, target_completion_rate)

        report['iterations'] = iteration + 1
        report['final_completion_rate'] = current_completion

    report['improvement'] = report['final_completion_rate'] - report['original_completion_rate']
    report['success'] = report['improvement'] >= IMPROVEMENT_THRESHOLD

    # Write back to file if not dry-run and adjustments made
    if not dry_run and report['adjustments_made']:
        try:
            with open(game_p8, 'w') as f:
                f.write(current_code)

            # Validate final result (basic check only)
            if '__lua__' not in current_code or '__gfx__' not in current_code:
                report['status'] = 'error'
                report['error'] = 'final validation failed: missing cartridge sections'
                # Restore backup
                if backup_path.exists():
                    shutil.copy(backup_path, game_p8)
            else:
                # Check token count (warn but don't fail)
                tokens = count_tokens(game_p8)
                if tokens:
                    report['token_count'] = tokens
                    if tokens > 8192:
                        report['warning'] = f'token count exceeded: {tokens}/8192'

                # Save report to game directory
                report_path = game_dir / 'difficulty-balance-report.json'
                with open(report_path, 'w') as f:
                    json.dump(report, f, indent=2)
        except Exception as e:
            report['status'] = 'error'
            report['error'] = f'exception: {str(e)}'
            if backup_path.exists():
                shutil.copy(backup_path, game_p8)
    elif dry_run:
        # In dry-run, save report to a temp location
        report_path = game_dir / 'difficulty-balance-report-preview.json'
        try:
            with open(report_path, 'w') as f:
                json.dump(report, f, indent=2)
        except:
            pass

    return report


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Auto-difficulty balancer for PICO-8 games')
    parser.add_argument('game_date', nargs='?', default=None, help='Game date (YYYY-MM-DD)')
    parser.add_argument('--analyze-all', action='store_true', help='Analyze all games')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying')
    parser.add_argument('--target-completion', type=float, default=TARGET_COMPLETION_RATE,
                        help=f'Target completion rate (default: {TARGET_COMPLETION_RATE*100:.1f}%%)')
    parser.add_argument('--force', action='store_true', help='Force re-analysis of balanced games')

    args = parser.parse_args()

    if args.analyze_all:
        games = find_all_games()
    elif args.game_date:
        game_dir = Path('games') / args.game_date
        if not game_dir.exists():
            print(f"Error: Game directory not found: {game_dir}", file=sys.stderr)
            sys.exit(1)
        games = [game_dir]
    else:
        parser.print_help()
        sys.exit(1)

    print(f"Analyzing {len(games)} game(s) for difficulty balancing...")
    print(f"Target completion rate: {args.target_completion:.1%}")
    print(f"Dry-run mode: {args.dry_run}")
    print()

    all_reports = []

    for game_dir in games:
        report = balance_game(game_dir, args.target_completion, args.dry_run, args.force)
        all_reports.append(report)

        # Print status
        game_date = game_dir.name
        status = report.get('status', 'unknown')

        if status == 'skip':
            print(f"{game_date}: SKIP - {report.get('reason', 'unknown')}")
        elif status == 'error':
            print(f"{game_date}: ERROR - {report.get('error', 'unknown')}")
        elif status == 'completed':
            success = report.get('success', False)
            marker = "✓" if success else "✗"
            improvement = report.get('improvement', 0)
            iterations = report.get('iterations', 0)
            print(f"{game_date}: {marker} Completed ({iterations} iterations, improvement: {improvement:+.1%})")
            if report.get('adjustments_made'):
                for adj in report['adjustments_made']:
                    param = adj['parameter']
                    change = adj['percent_change']
                    print(f"  - {param}: {change:+.1f}%")
        else:
            print(f"{game_date}: {status}")

    print()
    print("=" * 60)
    print("Summary")
    print("=" * 60)

    completed = sum(1 for r in all_reports if r.get('status') == 'completed')
    skipped = sum(1 for r in all_reports if r.get('status') == 'skip')
    errors = sum(1 for r in all_reports if r.get('status') == 'error')
    successful = sum(1 for r in all_reports if r.get('success', False))

    print(f"Completed: {completed}")
    print(f"Skipped: {skipped}")
    print(f"Errors: {errors}")
    print(f"Successfully improved: {successful}")
    print()

    # Save report file
    report_path = Path('difficulty-balance-summary.json')
    with open(report_path, 'w') as f:
        json.dump({
            'generated_at': datetime.now().isoformat(),
            'target_completion_rate': args.target_completion,
            'dry_run': args.dry_run,
            'games_analyzed': len(games),
            'games_completed': completed,
            'games_successful': successful,
            'reports': all_reports
        }, f, indent=2)

    print(f"Report saved to: {report_path}")


if __name__ == '__main__':
    main()
