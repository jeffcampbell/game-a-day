#!/usr/bin/env python3
"""Game improvement suggester - Analyzes metrics and generates actionable recommendations.

Reads game metrics from catalog.json, game code, and test data to identify problems
and suggest specific, data-driven improvements for each game.

OBJECTIVE:
Convert raw metrics (difficulty, completion_rate, quality_score, engagement_score)
into concrete, actionable improvement recommendations with estimated impact.

Usage:
  python3 tools/game-improvement-suggester.py                 # Analyze all games
  python3 tools/game-improvement-suggester.py 2026-03-05      # Single game
  python3 tools/game-improvement-suggester.py --priority high # Show high-priority games only
  python3 tools/game-improvement-suggester.py --summary       # Show summary report

Generates:
  - games/<date>/improvement-suggestions.json for each game
  - improvement-summary.json at project root (with --summary flag)
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# Target metrics for balanced games (based on catalog analysis)
TARGET_COMPLETION_RATE = 0.60  # 60% completion is healthy
TARGET_QUALITY_SCORE = 0.25    # Quality metric floor
TARGET_ENGAGEMENT_SCORE = 0.30  # Engagement metric floor
TARGET_DIFFICULTY = 3            # On 1-5 scale


def load_catalog():
    """Load catalog.json from project root.

    Returns dict with game list, or None if not found.
    """
    catalog_path = 'catalog.json'

    if not os.path.exists(catalog_path):
        print(f"Error: catalog.json not found at {catalog_path}", file=sys.stderr)
        return None

    try:
        with open(catalog_path, 'r') as f:
            catalog = json.load(f)
            if isinstance(catalog, dict) and 'games' in catalog:
                return catalog
    except (json.JSONDecodeError, IOError, TypeError) as e:
        print(f"Error loading catalog.json: {e}", file=sys.stderr)
        return None

    return None


def parse_game_code(game_p8_path):
    """Extract info from game.p8 source code.

    Returns dict with extracted metadata.
    """
    info = {
        'has_code': False,
        'has_spawning': False,
        'has_health': False,
        'has_scoring': False,
        'has_bosses': False,
        'has_difficulty_scaling': False,
        'estimated_complexity': 'low',
    }

    if not os.path.exists(game_p8_path):
        return info

    try:
        with open(game_p8_path, 'r') as f:
            code = f.read()
            info['has_code'] = True

            # Detect patterns in code
            if re.search(r'enemy|spawn|create', code, re.IGNORECASE):
                info['has_spawning'] = True

            if re.search(r'health|hp|lives|damage', code, re.IGNORECASE):
                info['has_health'] = True

            if re.search(r'score|points|counter', code, re.IGNORECASE):
                info['has_scoring'] = True

            if re.search(r'boss|final_enemy|big_enemy', code, re.IGNORECASE):
                info['has_bosses'] = True

            if re.search(r'difficulty|level_up|scaling', code, re.IGNORECASE):
                info['has_difficulty_scaling'] = True

            # Estimate complexity based on code length (rough heuristic)
            code_lines = len([l for l in code.split('\n') if l.strip() and not l.strip().startswith('--')])
            if code_lines > 500:
                info['estimated_complexity'] = 'high'
            elif code_lines > 300:
                info['estimated_complexity'] = 'medium'

    except (IOError, TypeError):
        pass

    return info


def load_insights(game_dir):
    """Load insights.json if available.

    Returns dict or None if not found/invalid.
    """
    insights_path = os.path.join(game_dir, 'insights.json')
    if not os.path.exists(insights_path):
        return None

    try:
        with open(insights_path, 'r') as f:
            insights = json.load(f)
            if isinstance(insights, dict):
                return insights
    except (json.JSONDecodeError, IOError, TypeError):
        pass

    return None


def analyze_difficulty_issue(game, code_info, insights):
    """Analyze if game difficulty is too high.

    Returns (has_issue, severity, evidence).
    """
    difficulty = game.get('difficulty', 3)
    difficulty_assessment = game.get('difficulty_assessment', '')
    completion_rate = game.get('completion_rate', 0.0)

    # Check multiple signals for difficulty issue
    signals = []

    if difficulty_assessment == 'too_hard':
        signals.append('difficulty_assessment=too_hard')

    if completion_rate < 0.3:
        signals.append(f'completion_rate={completion_rate:.1%} (very low)')

    if difficulty >= 4 and completion_rate < TARGET_COMPLETION_RATE:
        signals.append(f'difficulty={difficulty}/5 with low completion')

    if insights:
        design_issues = insights.get('design_issues', [])
        if any('hard' in issue.lower() or 'difficulty' in issue.lower() for issue in design_issues):
            signals.append('design_issues mention difficulty')

    if signals:
        # Determine severity
        if completion_rate == 0.0 or difficulty >= 5:
            severity = 'critical'
        elif completion_rate < 0.2:
            severity = 'high'
        else:
            severity = 'medium'

        return True, severity, ', '.join(signals)

    return False, None, None


def analyze_quality_issue(game, code_info, insights):
    """Analyze if game quality/polish is low.

    Returns (has_issue, severity, evidence).
    """
    quality_score = game.get('game_quality_score', 0.0)
    test_status = game.get('test_status', 'UNKNOWN')
    logs_captured = game.get('logs_captured', 0)
    token_count = game.get('token_count', 0)

    signals = []

    if quality_score < 0.20:
        signals.append(f'quality_score={quality_score:.3f} (bottom 10%)')

    if test_status == 'FAIL':
        signals.append('test_status=FAIL')

    if logs_captured == 0:
        signals.append('logs_captured=0 (no logging)')

    if token_count == 0:
        signals.append('token_count=0 (incomplete game)')

    if code_info and code_info.get('has_code'):
        # Code exists but minimal sprites/sounds
        sprite_count = game.get('sprite_count', 0)
        sound_count = game.get('sound_count', 0)
        if sprite_count < 3 and sound_count < 2:
            signals.append('minimal sprites/sounds (incomplete)')

    if signals:
        severity = 'high' if quality_score < 0.15 else 'medium'
        return True, severity, ', '.join(signals)

    return False, None, None


def analyze_engagement_issue(game, code_info, insights):
    """Analyze if game engagement is low.

    Returns (has_issue, severity, evidence).
    """
    engagement_score = game.get('engagement_score', 0.0)
    completion_rate = game.get('completion_rate', 0.0)

    signals = []

    if engagement_score < TARGET_ENGAGEMENT_SCORE:
        signals.append(f'engagement_score={engagement_score:.3f} (below target)')

    if completion_rate > 0.0 and completion_rate < 0.3:
        signals.append(f'completion_rate={completion_rate:.1%} (low engagement)')

    if insights:
        behavior = insights.get('player_behavior_patterns', {})
        duration = behavior.get('average_session_duration_seconds', 0)
        if duration < 10:
            signals.append(f'avg_session={duration}s (too short)')

    if signals:
        severity = 'medium' if engagement_score < 0.20 else 'low'
        return True, severity, ', '.join(signals)

    return False, None, None


def analyze_balancing_issue(game, code_info, insights):
    """Analyze if metadata difficulty matches actual gameplay difficulty.

    Returns (has_issue, severity, evidence).
    """
    difficulty_metadata = game.get('difficulty', 3)
    difficulty_assessment = game.get('difficulty_assessment', '')
    completion_rate = game.get('completion_rate', 0.0)

    # If metadata says one thing but assessment says another
    mismatch = False
    signals = []

    if difficulty_metadata >= 4 and difficulty_assessment != 'too_hard':
        if completion_rate > TARGET_COMPLETION_RATE:
            mismatch = True
            signals.append(f'difficulty={difficulty_metadata} but completion={completion_rate:.1%} suggests easier game')

    if difficulty_metadata <= 2 and difficulty_assessment == 'too_hard':
        mismatch = True
        signals.append(f'difficulty={difficulty_metadata} but assessment=too_hard mismatch')

    if mismatch:
        return True, 'low', ', '.join(signals)

    return False, None, None


def generate_suggestions(game, game_dir):
    """Generate improvement suggestions for a game.

    Returns dict with suggestions structure.
    """
    game_date = game.get('date', 'unknown')
    title = game.get('title', 'Untitled Game')

    # Load supporting data
    code_info = parse_game_code(os.path.join(game_dir, 'game.p8'))
    insights = load_insights(game_dir)

    # Analyze issues
    issues = []
    issue_type_to_suggestions = {}

    # Check difficulty
    has_difficulty, severity, evidence = analyze_difficulty_issue(game, code_info, insights)
    if has_difficulty:
        issues.append({
            'issue_type': 'difficulty_too_high',
            'severity': severity,
            'evidence': evidence,
        })
        issue_type_to_suggestions['difficulty_too_high'] = True

    # Check quality
    has_quality, severity, evidence = analyze_quality_issue(game, code_info, insights)
    if has_quality:
        issues.append({
            'issue_type': 'low_quality',
            'severity': severity,
            'evidence': evidence,
        })
        issue_type_to_suggestions['low_quality'] = True

    # Check engagement
    has_engagement, severity, evidence = analyze_engagement_issue(game, code_info, insights)
    if has_engagement:
        issues.append({
            'issue_type': 'low_engagement',
            'severity': severity,
            'evidence': evidence,
        })
        issue_type_to_suggestions['low_engagement'] = True

    # Check balancing
    has_balance, severity, evidence = analyze_balancing_issue(game, code_info, insights)
    if has_balance:
        issues.append({
            'issue_type': 'metadata_difficulty_mismatch',
            'severity': severity,
            'evidence': evidence,
        })
        issue_type_to_suggestions['metadata_difficulty_mismatch'] = True

    # Generate suggestions based on identified issues
    suggestions = []
    priority = 1

    # DIFFICULTY TOO HIGH suggestions
    if 'difficulty_too_high' in issue_type_to_suggestions:
        completion_rate = game.get('completion_rate', 0.0)
        difficulty = game.get('difficulty', 3)

        if completion_rate == 0.0:
            suggestions.append({
                'id': priority,
                'title': 'Reduce initial difficulty spike',
                'description': 'Game currently unplayable (0% completion). Reduce starting challenge significantly.',
                'impact': 'critical',
                'effort': 'low',
                'estimated_effect': 'completion_rate: 0% -> ~30-40% (immediate playability)',
                'code_location': 'Find spawn/difficulty initialization, reduce by 50%',
                'priority': str(priority),
                'implementation_steps': [
                    'Find initial spawn rate or enemy count',
                    'Reduce by 40-50%',
                    'Test with multiple playstyles',
                ],
            })
            priority += 1

        if code_info.get('has_bosses'):
            suggestions.append({
                'id': priority,
                'title': 'Reduce or remove boss difficulty',
                'description': 'Boss enemy is likely too difficult. Reduce health/damage or make optional.',
                'impact': 'high',
                'effort': 'low',
                'estimated_effect': 'completion_rate: +15-25%',
                'code_location': 'Find boss enemy stats (health/damage), reduce by 30-40%',
                'priority': str(priority),
                'implementation_steps': [
                    'Locate boss enemy code',
                    'Reduce health by 30-40%',
                    'Reduce damage by 20-30%',
                ],
            })
            priority += 1

        if code_info.get('has_difficulty_scaling'):
            suggestions.append({
                'id': priority,
                'title': 'Disable or soften difficulty scaling',
                'description': 'Game scaling makes it progressively harder. Remove or reduce scaling.',
                'impact': 'high',
                'effort': 'low',
                'estimated_effect': 'smoother difficulty curve, +10-20% completion',
                'code_location': 'Find difficulty_scaling or level_up logic, disable or reduce',
                'priority': str(priority),
                'implementation_steps': [
                    'Locate difficulty scaling logic',
                    'Either disable entirely or reduce scale factor by 50%',
                ],
            })
            priority += 1

        if code_info.get('has_health'):
            suggestions.append({
                'id': priority,
                'title': 'Increase starting health/lives',
                'description': 'Give player more starting health or lives to improve survivability.',
                'impact': 'medium',
                'effort': 'low',
                'estimated_effect': '+10-15% completion rate',
                'code_location': 'Find health/lives initialization, increase by 50-100%',
                'priority': str(priority),
                'implementation_steps': [
                    'Locate starting health variable',
                    'Increase by 50-100%',
                ],
            })
            priority += 1

        if code_info.get('has_spawning'):
            suggestions.append({
                'id': priority,
                'title': 'Reduce enemy spawn rate',
                'description': 'Too many enemies on screen. Reduce spawn frequency and/or count.',
                'impact': 'high',
                'effort': 'low',
                'estimated_effect': 'completion_rate: +20-30%',
                'code_location': 'Find spawn rate variable (likely a counter or interval)',
                'priority': str(priority),
                'implementation_steps': [
                    'Find spawn timer/counter',
                    'Increase spawn interval by 25-50%',
                    'Or reduce max enemies on screen',
                ],
            })
            priority += 1

    # LOW ENGAGEMENT suggestions
    if 'low_engagement' in issue_type_to_suggestions:
        if code_info.get('has_scoring'):
            suggestions.append({
                'id': priority,
                'title': 'Increase reward frequency',
                'description': 'Add more frequent rewards (points, items, visual feedback) to boost engagement.',
                'impact': 'medium',
                'effort': 'low',
                'estimated_effect': 'engagement_score: +0.05-0.10',
                'code_location': 'Scoring logic - reduce points needed for rewards',
                'priority': str(priority),
                'implementation_steps': [
                    'Find point thresholds for rewards',
                    'Reduce thresholds by 20-30%',
                    'Or add more frequent small rewards',
                ],
            })
            priority += 1

        suggestions.append({
            'id': priority,
            'title': 'Add visual/audio feedback for player actions',
            'description': 'Add sprite animations, particle effects, or sounds when player acts.',
            'impact': 'medium',
            'effort': 'medium',
            'estimated_effect': 'engagement_score: +0.03-0.08',
            'code_location': 'Add sound effects (sfx) or sprite animations in update functions',
            'priority': str(priority),
            'implementation_steps': [
                'Add sfx(n) calls in player action handlers',
                'Add simple sprite animation frames',
                'Test audio/visual responsiveness',
            ],
        })
        priority += 1

        suggestions.append({
            'id': priority,
            'title': 'Add progression milestones',
            'description': 'Create levels, waves, or difficulty stages to show progress.',
            'impact': 'medium',
            'effort': 'medium',
            'estimated_effect': 'engagement_score: +0.05-0.12',
            'code_location': 'Add level/wave counter, display progress to player',
            'priority': str(priority),
            'implementation_steps': [
                'Add level or wave counter',
                'Display current level/progress',
                'Adjust difficulty per level',
            ],
        })
        priority += 1

    # LOW QUALITY suggestions
    if 'low_quality' in issue_type_to_suggestions:
        token_count = game.get('token_count', 0)
        sprite_count = game.get('sprite_count', 0)
        sound_count = game.get('sound_count', 0)

        if token_count == 0:
            suggestions.append({
                'id': priority,
                'title': 'Implement core game loop',
                'description': 'Game appears mostly empty. Implement basic game mechanics.',
                'impact': 'critical',
                'effort': 'high',
                'estimated_effect': 'Create playable game from skeleton',
                'code_location': 'update_play() and draw_play() functions',
                'priority': str(priority),
                'implementation_steps': [
                    'Add player entity and movement',
                    'Add enemy/obstacle spawning',
                    'Add collision detection',
                    'Add game-over conditions',
                ],
            })
            priority += 1

        if sprite_count < 5:
            suggestions.append({
                'id': priority,
                'title': 'Add sprite animations',
                'description': 'Create visual sprites for player, enemies, and effects.',
                'impact': 'medium',
                'effort': 'medium',
                'estimated_effect': 'quality_score: +0.05-0.10',
                'code_location': 'Draw sprites in draw_play() and draw_gameover()',
                'priority': str(priority),
                'implementation_steps': [
                    'Design sprites in __gfx__ section',
                    'Add spr() calls in draw functions',
                    'Add animation frame logic',
                ],
            })
            priority += 1

        if sound_count < 3:
            suggestions.append({
                'id': priority,
                'title': 'Add sound effects and music',
                'description': 'Games with audio are more engaging. Add SFX and background music.',
                'impact': 'low',
                'effort': 'medium',
                'estimated_effect': 'quality_score: +0.02-0.05, engagement: +0.02',
                'code_location': 'Add sfx() and music() calls throughout gameplay',
                'priority': str(priority),
                'implementation_steps': [
                    'Add sound patterns in __sfx__ section',
                    'Add music patterns in __music__ section',
                    'Play SFX on key events (jump, score, hit)',
                    'Loop background music during play',
                ],
            })
            priority += 1

        test_status = game.get('test_status', 'UNKNOWN')
        if test_status == 'FAIL':
            suggestions.append({
                'id': priority,
                'title': 'Fix test failures',
                'description': 'Game has state machine or logging issues. Debug and fix.',
                'impact': 'high',
                'effort': 'medium',
                'estimated_effect': 'quality_score: +0.05-0.15',
                'code_location': 'Check test-report.json for specific errors',
                'priority': str(priority),
                'implementation_steps': [
                    'Run: python3 tools/run-game-tests.py <date>',
                    'Review test-report.json errors',
                    'Fix state transitions or logging calls',
                ],
            })
            priority += 1

    # METADATA DIFFICULTY MISMATCH suggestions
    if 'metadata_difficulty_mismatch' in issue_type_to_suggestions:
        completion_rate = game.get('completion_rate', 0.0)
        difficulty = game.get('difficulty', 3)
        difficulty_assessment = game.get('difficulty_assessment', '')

        if difficulty >= 4 and difficulty_assessment != 'too_hard' and completion_rate > 0.5:
            suggestions.append({
                'id': priority,
                'title': 'Reduce metadata difficulty rating',
                'description': f'Game metadata says difficulty={difficulty} but data suggests it\'s easier.',
                'impact': 'low',
                'effort': 'low',
                'estimated_effect': 'Better metadata alignment, improved filtering',
                'code_location': 'metadata.json difficulty field',
                'priority': str(priority),
                'implementation_steps': [
                    'Open metadata.json',
                    f'Change difficulty from {difficulty} to {TARGET_DIFFICULTY}',
                    'Save and regenerate catalog',
                ],
            })
            priority += 1

    # Build summary
    summary = ""
    if not issues:
        summary = "Game metrics look good. Continue playtesting and monitor engagement."
    else:
        worst_issue = max(issues, key=lambda i: {'critical': 3, 'high': 2, 'medium': 1, 'low': 0}.get(i.get('severity'), 0))
        issue_type = worst_issue.get('issue_type', 'unknown')

        if worst_issue.get('severity') == 'critical':
            if issue_type == 'difficulty_too_high':
                summary = f"CRITICAL: Game is unplayable (0% completion). Implement suggestion #1 immediately to reduce initial difficulty."
            else:
                summary = f"CRITICAL: Game has major quality issues. Implement core mechanics first (suggestion #1)."
        elif worst_issue.get('severity') == 'high':
            if suggestions:
                summary = f"Game has {len(issues)} issue(s). Start with suggestion #{suggestions[0]['id']} ({suggestions[0]['title']}) for highest impact."
            else:
                summary = "Game needs improvements. Review identified issues above."
        else:
            summary = f"Game could use polishing. {len(suggestions)} optional improvements available."

        if suggestions:
            summary += f"\nImplement suggestions in priority order. Retest after each change."

    result = {
        'game_date': game_date,
        'title': title,
        'generated_at': datetime.now().isoformat(),
        'current_metrics': {
            'difficulty': game.get('difficulty', 0),
            'difficulty_assessment': game.get('difficulty_assessment', 'unknown'),
            'quality_score': game.get('game_quality_score', 0.0),
            'engagement_score': game.get('engagement_score', 0.0),
            'completion_rate': game.get('completion_rate', 0.0),
        },
        'issues': issues,
        'suggestions': suggestions,
        'summary': summary,
    }

    return result


def calculate_priority_score(game, suggestions):
    """Calculate overall priority score for a game (higher = more urgent).

    Based on multiple factors:
    - Critical/high severity issues
    - Number of suggestions
    - Completion rate
    """
    score = 0

    # Issue severity weighting
    has_critical = any(issue.get('severity') == 'critical' for issue in game.get('issues', []))
    has_high = any(issue.get('severity') == 'high' for issue in game.get('issues', []))

    if has_critical:
        score += 100
    if has_high:
        score += 50

    # Completion rate (0% is worse than 50%)
    completion = game.get('current_metrics', {}).get('completion_rate', 0.0)
    if completion == 0.0:
        score += 75
    elif completion < 0.3:
        score += 40
    elif completion < 0.6:
        score += 20

    # Number of actionable suggestions
    score += len(suggestions) * 5

    return score


def save_suggestions(game_dir, suggestions_data):
    """Save suggestions to improvement-suggestions.json.

    Returns True on success, False on error.
    """
    if not suggestions_data:
        return False

    suggestions_path = os.path.join(game_dir, 'improvement-suggestions.json')
    try:
        os.makedirs(game_dir, exist_ok=True)
        with open(suggestions_path, 'w') as f:
            json.dump(suggestions_data, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving suggestions for {game_dir}: {e}", file=sys.stderr)
        return False


def find_all_games():
    """Find all game directories in games/.

    Returns list of (date, path) tuples, sorted by date descending.
    """
    games_dir = 'games'
    if not os.path.isdir(games_dir):
        return []

    games = []
    for entry in os.listdir(games_dir):
        path = os.path.join(games_dir, entry)
        if os.path.isdir(path) and len(entry) == 10 and entry[4] == '-' and entry[7] == '-':
            # Valid date format YYYY-MM-DD
            games.append((entry, path))

    return sorted(games, key=lambda x: x[0], reverse=True)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Generate improvement suggestions for PICO-8 games'
    )
    parser.add_argument(
        'date',
        nargs='?',
        help='Specific game date to analyze (YYYY-MM-DD), or omit for all games'
    )
    parser.add_argument(
        '--priority',
        choices=['critical', 'high', 'medium', 'low'],
        help='Show only games with this priority level'
    )
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Generate improvement-summary.json with overview of all games'
    )

    args = parser.parse_args()

    # Load catalog
    catalog = load_catalog()
    if not catalog:
        print("Cannot proceed without catalog.json", file=sys.stderr)
        return 1

    # Get games to process
    all_games = find_all_games()
    if not all_games:
        print("No games found in games/", file=sys.stderr)
        return 1

    # Filter by date if specified
    if args.date:
        games_to_process = [(d, p) for d, p in all_games if d == args.date]
        if not games_to_process:
            print(f"Game not found: {args.date}", file=sys.stderr)
            return 1
    else:
        games_to_process = all_games

    # Filter by priority if specified
    if args.priority:
        priority_mapping = {'critical': 3, 'high': 2, 'medium': 1, 'low': 0}
        min_priority = priority_mapping[args.priority]

    print(f"Analyzing {len(games_to_process)} game(s)...", flush=True)
    print()

    all_suggestions = []
    generated_count = 0

    for game_date, game_dir in games_to_process:
        # Find game in catalog
        game_data = None
        for g in catalog.get('games', []):
            if g.get('date') == game_date:
                game_data = g
                break

        if not game_data:
            print(f"{game_date}: Not in catalog, skipping", flush=True)
            continue

        # Generate suggestions
        suggestions_data = generate_suggestions(game_data, game_dir)

        # Filter by priority if specified
        if args.priority:
            severity_map = {'critical': 3, 'high': 2, 'medium': 1, 'low': 0}
            has_matching_issue = any(
                severity_map.get(issue.get('severity'), -1) >= min_priority
                for issue in suggestions_data.get('issues', [])
            )
            if not has_matching_issue:
                continue

        # Save suggestions
        if save_suggestions(game_dir, suggestions_data):
            generated_count += 1
            priority_score = calculate_priority_score(suggestions_data, suggestions_data.get('suggestions', []))
            all_suggestions.append((game_date, suggestions_data, priority_score))

            # Print status
            issue_count = len(suggestions_data.get('issues', []))
            suggestion_count = len(suggestions_data.get('suggestions', []))
            completion = suggestions_data.get('current_metrics', {}).get('completion_rate', 0.0)
            print(f"{game_date}: {issue_count} issues, {suggestion_count} suggestions (completion: {completion:.0%})", flush=True)
        else:
            print(f"{game_date}: Failed to save suggestions", flush=True)

    print()
    print(f"✓ Generated suggestions for {generated_count} game(s)", flush=True)

    # Generate summary if requested
    if args.summary:
        summary_data = generate_summary(all_suggestions, catalog)
        if save_summary(summary_data):
            print(f"✓ Generated improvement-summary.json", flush=True)

    return 0


def generate_summary(all_suggestions, catalog):
    """Generate summary report of all suggestions.

    Returns dict with aggregate statistics and prioritized game list.
    """
    # Sort by priority score descending
    prioritized = sorted(all_suggestions, key=lambda x: x[2], reverse=True)

    # Aggregate statistics
    total_games_analyzed = len(all_suggestions)
    total_issues = sum(len(s[1].get('issues', [])) for s in all_suggestions)
    total_suggestions = sum(len(s[1].get('suggestions', [])) for s in all_suggestions)

    issue_type_counts = defaultdict(int)
    for _, suggestions_data, _ in all_suggestions:
        for issue in suggestions_data.get('issues', []):
            issue_type_counts[issue.get('issue_type', 'unknown')] += 1

    severity_counts = defaultdict(int)
    for _, suggestions_data, _ in all_suggestions:
        for issue in suggestions_data.get('issues', []):
            severity_counts[issue.get('severity', 'unknown')] += 1

    # Completion rate statistics
    completion_rates = [
        s[1].get('current_metrics', {}).get('completion_rate', 0.0)
        for s in all_suggestions
    ]
    avg_completion = sum(completion_rates) / len(completion_rates) if completion_rates else 0.0

    return {
        'generated_at': datetime.now().isoformat(),
        'total_games_analyzed': total_games_analyzed,
        'statistics': {
            'total_issues_identified': total_issues,
            'total_suggestions_generated': total_suggestions,
            'average_completion_rate': round(avg_completion, 3),
            'issue_type_distribution': dict(issue_type_counts),
            'severity_distribution': dict(severity_counts),
        },
        'games_by_priority': [
            {
                'date': g[0],
                'title': g[1].get('title', 'Untitled Game'),
                'priority_score': g[2],
                'issue_count': len(g[1].get('issues', [])),
                'suggestion_count': len(g[1].get('suggestions', [])),
                'completion_rate': g[1].get('current_metrics', {}).get('completion_rate', 0.0),
                'difficulty_assessment': g[1].get('current_metrics', {}).get('difficulty_assessment', 'unknown'),
            }
            for g in prioritized[:20]  # Top 20 games
        ],
    }


def save_summary(summary_data):
    """Save summary to improvement-summary.json.

    Returns True on success, False on error.
    """
    try:
        with open('improvement-summary.json', 'w') as f:
            json.dump(summary_data, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving summary: {e}", file=sys.stderr)
        return False


if __name__ == '__main__':
    sys.exit(main())
