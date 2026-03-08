#!/usr/bin/env python3
"""Generate comprehensive game library catalog.

Scans all games/ directories and aggregates metadata, test reports, and session
analytics into a master catalog.json file.

Usage:
  python3 tools/generate-library.py

Generates:
  - catalog.json  (at project root with all game entries)
"""

import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict
import statistics


def find_all_games():
    """Find all game directories (YYYY-MM-DD format).

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


def load_test_report(game_dir):
    """Load test-report.json for a game.

    Returns dict if valid, None otherwise.
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

    Returns list of session dicts.
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
                        sessions.append(session)
            except (json.JSONDecodeError, IOError, TypeError):
                pass

    return sessions


def calculate_completion_rate(sessions):
    """Calculate completion rate from sessions.

    Returns float between 0.0 and 1.0, or None if no sessions.
    """
    if not sessions:
        return None

    completions = defaultdict(int)
    for session in sessions:
        status = session.get('exit_state', 'quit')
        completions[status] += 1

    # Count wins/completion as successful
    wins = completions.get('won', 0) + completions.get('win', 0)
    total = len(sessions)

    if total == 0:
        return None

    rate = wins / total
    return round(rate, 2)


def load_assessment(game_dir):
    """Load assessment.md if it exists.

    Returns assessment status (active/complete/archived) or None.
    """
    assessment_path = os.path.join(game_dir, 'assessment.md')

    if not os.path.exists(assessment_path):
        return None

    try:
        with open(assessment_path, 'r') as f:
            content = f.read()
            # Look for status marker in assessment
            if 'complete' in content.lower():
                return 'complete'
            if 'active' in content.lower():
                return 'active'
            # Default: has assessment
            return 'active'
    except IOError:
        pass

    return None


def load_insights(game_dir):
    """Load insights.json if it exists.

    Returns insights dict, or None if not available.
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


def calculate_game_quality_score(completion_rate, engagement_score, test_status):
    """Calculate an overall game quality score combining multiple metrics.

    Score is 0.0-1.0 based on:
    - Completion rate: 40%
    - Engagement score: 40%
    - Test status: 20% (PASS=1.0, FAIL=0.0, UNKNOWN=0.5)

    Returns float between 0.0 and 1.0.
    """
    # Normalize inputs to 0-1 range
    completion_score = min(1.0, completion_rate) if completion_rate else 0.0
    engagement = min(1.0, engagement_score) if engagement_score else 0.0

    # Test status scoring
    test_score = 0.5  # Default for UNKNOWN
    if test_status == 'PASS':
        test_score = 1.0
    elif test_status == 'FAIL':
        test_score = 0.0

    # Weighted score
    quality_score = (
        completion_score * 0.4 +
        engagement * 0.4 +
        test_score * 0.2
    )

    return round(quality_score, 3)


def aggregate_game_entry(date, game_dir):
    """Aggregate all data for a single game into a catalog entry.

    Returns dict with complete game information, or None if invalid.
    """
    # Load all data sources
    metadata = load_metadata(game_dir)
    test_report = load_test_report(game_dir)
    sessions = find_sessions(game_dir)
    assessment_status = load_assessment(game_dir)
    insights = load_insights(game_dir)

    # Metadata is required
    if not metadata:
        return None

    # Extract core fields from metadata
    entry = {
        'date': date,
        'title': metadata.get('title', 'Untitled Game'),
        'description': metadata.get('description', ''),
        'genres': metadata.get('genres', []),
        'difficulty': metadata.get('difficulty', 3),
        'playtime_minutes': metadata.get('playtime_minutes', 5),
        'completion_status': metadata.get('completion_status', 'in-progress'),
    }

    # Add test report data if available
    if test_report:
        entry['test_status'] = test_report.get('status', 'UNKNOWN')
        entry['state_transitions'] = test_report.get('state_transitions', [])
        entry['logs_captured'] = test_report.get('logs_captured', 0)
    else:
        entry['test_status'] = 'UNKNOWN'
        entry['state_transitions'] = []
        entry['logs_captured'] = 0

    # Add session analytics if available
    entry['sessions_recorded'] = len(sessions)
    completion_rate = calculate_completion_rate(sessions)
    entry['completion_rate'] = completion_rate if completion_rate is not None else 0.0

    # Add insights data if available
    if insights:
        entry['has_insights'] = True

        # Add difficulty assessment from insights
        difficulty_assessment = insights.get('difficulty_assessment', {})
        entry['difficulty_assessment'] = difficulty_assessment.get('assessment', 'unknown')

        # Add engagement score from insights
        engagement_score = insights.get('engagement_score', 0.0)
        entry['engagement_score'] = engagement_score

        # Calculate overall quality score
        quality_score = calculate_game_quality_score(
            entry.get('completion_rate', 0.0),
            engagement_score,
            entry.get('test_status', 'UNKNOWN')
        )
        entry['game_quality_score'] = quality_score

        # Add player behavior patterns
        behavior = insights.get('player_behavior_patterns', {})
        if behavior:
            entry['player_playstyle'] = behavior.get('most_common_playstyle', 'unknown')
    else:
        entry['has_insights'] = False

    # Add assessment status if available
    if assessment_status:
        entry['assessment_status'] = assessment_status

    # Add optional metadata fields
    if 'theme' in metadata and metadata['theme']:
        entry['theme'] = metadata['theme']

    if 'target_audience' in metadata:
        entry['target_audience'] = metadata['target_audience']

    if 'keywords' in metadata and metadata['keywords']:
        entry['keywords'] = metadata['keywords']

    if 'token_count' in metadata:
        entry['token_count'] = metadata['token_count']

    if 'sprite_count' in metadata:
        entry['sprite_count'] = metadata['sprite_count']

    if 'sound_count' in metadata:
        entry['sound_count'] = metadata['sound_count']

    if 'tester_notes' in metadata and metadata['tester_notes']:
        entry['tester_notes'] = metadata['tester_notes']

    return entry


def generate_statistics(games):
    """Generate statistics from all games.

    Returns dict with aggregated metrics.
    """
    if not games:
        return {}

    difficulties = [g.get('difficulty', 3) for g in games if 'difficulty' in g]
    playtimes = [g.get('playtime_minutes', 5) for g in games if 'playtime_minutes' in g]
    completion_rates = [g.get('completion_rate', 0) for g in games if 'completion_rate' in g and g['completion_rate'] > 0]
    engagement_scores = [g.get('engagement_score', 0) for g in games if g.get('has_insights') and g.get('engagement_score')]
    quality_scores = [g.get('game_quality_score', 0) for g in games if g.get('has_insights') and 'game_quality_score' in g]

    # Genre frequency
    genre_freq = defaultdict(int)
    for game in games:
        for genre in game.get('genres', []):
            genre_freq[genre] += 1

    # Completion status breakdown
    status_freq = defaultdict(int)
    for game in games:
        status_freq[game.get('completion_status', 'unknown')] += 1

    # Difficulty assessment breakdown (from insights)
    difficulty_assessment_freq = defaultdict(int)
    for game in games:
        if game.get('has_insights'):
            assessment = game.get('difficulty_assessment', 'unknown')
            difficulty_assessment_freq[assessment] += 1

    stats = {
        'total_games': len(games),
        'total_sessions_recorded': sum(g.get('sessions_recorded', 0) for g in games),
        'games_with_insights': sum(1 for g in games if g.get('has_insights')),
        'average_completion_rate': round(statistics.mean(completion_rates), 2) if completion_rates else 0.0,
    }

    if engagement_scores:
        stats['engagement_score_stats'] = {
            'min': round(min(engagement_scores), 3),
            'max': round(max(engagement_scores), 3),
            'average': round(statistics.mean(engagement_scores), 3),
        }

    if quality_scores:
        stats['quality_score_stats'] = {
            'min': round(min(quality_scores), 3),
            'max': round(max(quality_scores), 3),
            'average': round(statistics.mean(quality_scores), 3),
        }

    if difficulties:
        stats['difficulty_stats'] = {
            'min': min(difficulties),
            'max': max(difficulties),
            'average': round(statistics.mean(difficulties), 1),
        }

    if playtimes:
        stats['playtime_stats'] = {
            'min': min(playtimes),
            'max': max(playtimes),
            'average': round(statistics.mean(playtimes), 1),
            'median': statistics.median(playtimes),
        }

    if genre_freq:
        stats['genre_distribution'] = dict(sorted(genre_freq.items(), key=lambda x: x[1], reverse=True))

    if status_freq:
        stats['completion_status_breakdown'] = dict(status_freq)

    if difficulty_assessment_freq:
        stats['difficulty_assessment_breakdown'] = dict(difficulty_assessment_freq)

    return stats


def generate_catalog():
    """Generate catalog.json with all game metadata.

    Returns 0 on success, 1 on failure.
    """
    print("Scanning games directory...", flush=True)

    games_list = find_all_games()
    if not games_list:
        print("No games found", file=sys.stderr)
        return 1

    print(f"Found {len(games_list)} games", flush=True)

    # Aggregate data for each game
    catalog_games = []
    errors = []

    for date, game_dir in games_list:
        entry = aggregate_game_entry(date, game_dir)
        if entry:
            catalog_games.append(entry)
        else:
            errors.append(f"{date}: Missing required metadata")

    if not catalog_games:
        print("No valid games to catalog", file=sys.stderr)
        return 1

    # Sort by date (most recent first)
    catalog_games.sort(key=lambda g: g.get('date', ''), reverse=True)

    # Generate statistics
    stats = generate_statistics(catalog_games)

    # Build catalog
    catalog = {
        'generated': datetime.now().isoformat(),
        'version': '1.0',
        'total_games': len(catalog_games),
        'statistics': stats,
        'games': catalog_games
    }

    # Write catalog
    try:
        catalog_path = 'catalog.json'
        with open(catalog_path, 'w') as f:
            json.dump(catalog, f, indent=2)

        print(f"✓ Generated {catalog_path} ({len(catalog_games)} games)", flush=True)

        if errors:
            print(f"⚠️  {len(errors)} games skipped due to errors", flush=True)
            for error in errors[:5]:  # Show first 5 errors
                print(f"   - {error}", flush=True)

        return 0
    except IOError as e:
        print(f"Error writing catalog: {e}", file=sys.stderr)
        return 1


def main():
    """Main entry point."""
    try:
        return generate_catalog()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
