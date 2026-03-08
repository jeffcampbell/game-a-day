#!/usr/bin/env python3
"""Daily game intelligence report generator.

Analyzes recent game performance and provides data-driven recommendations for
today's game creation. Reads catalog.json and insights.json files to synthesize
completion rates, difficulty assessments, and engagement metrics.

OBJECTIVE:
Help the daily game creator understand what's working and what isn't, providing
actionable insights to improve completion rates and difficulty balancing.

Usage:
  python3 tools/daily-intelligence.py                    # Generate for today
  python3 tools/daily-intelligence.py --date 2026-03-10  # Generate for specific date
  python3 tools/daily-intelligence.py --output path/to/file.json  # Custom output

Generates:
  - games/<date>/daily-intelligence.json (default)
  - Custom path via --output flag
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict
import statistics


def load_catalog():
    """Load catalog.json from project root.

    Returns dict with game list, or None if not found.
    """
    catalog_path = 'catalog.json'

    if not os.path.exists(catalog_path):
        return None

    try:
        with open(catalog_path, 'r') as f:
            catalog = json.load(f)
            if isinstance(catalog, dict) and 'games' in catalog:
                return catalog
    except (json.JSONDecodeError, IOError, TypeError):
        pass

    return None


def parse_date(date_str):
    """Parse YYYY-MM-DD format to datetime object.

    Returns datetime.date or None if invalid.
    """
    try:
        return datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return None


def get_games_in_range(catalog, target_date, days=14):
    """Get all games from the past N days (inclusive of target_date).

    Args:
        catalog: Loaded catalog dict
        target_date: datetime.date for the report
        days: Number of days to look back (default 14)

    Returns list of game entries with dates in range.
    """
    if not catalog or 'games' not in catalog:
        return []

    cutoff_date = target_date - timedelta(days=days-1)
    games = []

    for game in catalog['games']:
        if 'date' not in game:
            continue

        game_date = parse_date(game['date'])
        if game_date and cutoff_date <= game_date <= target_date:
            games.append(game)

    return sorted(games, key=lambda g: g['date'], reverse=True)


def analyze_genre_performance(games):
    """Analyze completion rates and engagement by genre.

    Args:
        games: List of game dicts from catalog

    Returns dict with genre -> {avg_completion, avg_engagement, game_count, games}
    """
    genre_stats = defaultdict(lambda: {
        'completion_rates': [],
        'engagement_scores': [],
        'games': []
    })

    for game in games:
        if 'genres' not in game or not game['genres']:
            continue

        for genre in game['genres']:
            completion = game.get('completion_rate', 0)
            engagement = game.get('engagement_score', 0)

            genre_stats[genre]['completion_rates'].append(completion)
            genre_stats[genre]['engagement_scores'].append(engagement)
            genre_stats[genre]['games'].append({
                'date': game['date'],
                'title': game.get('title', 'Untitled'),
                'completion_rate': completion,
                'engagement_score': engagement
            })

    # Calculate aggregates
    result = {}
    for genre, stats in genre_stats.items():
        completions = stats['completion_rates']
        engagements = stats['engagement_scores']

        result[genre] = {
            'avg_completion': round(statistics.mean(completions), 2) if completions else 0,
            'avg_engagement': round(statistics.mean(engagements), 2) if engagements else 0,
            'games': len(completions),
            'min_completion': min(completions) if completions else 0,
            'max_completion': max(completions) if completions else 0,
            'games_list': stats['games']
        }

    return result


def calculate_trend(games):
    """Calculate completion rate trend over time.

    Splits games into two groups (first half vs second half of period)
    and calculates trend direction and delta.

    Args:
        games: List of game dicts sorted by date (newest first)

    Returns dict with trend info.
    """
    if len(games) < 2:
        return {
            'completion_rate_trend': 'insufficient_data',
            'trend_delta_pct': 0,
            'avg_completion_recent': 0,
            'avg_completion_older': 0
        }

    # Split into recent and older halves
    mid = len(games) // 2
    recent = games[:mid]
    older = games[mid:]

    # Calculate averages
    recent_rates = [g.get('completion_rate', 0) for g in recent if 'completion_rate' in g]
    older_rates = [g.get('completion_rate', 0) for g in older if 'completion_rate' in g]

    avg_recent = statistics.mean(recent_rates) if recent_rates else 0
    avg_older = statistics.mean(older_rates) if older_rates else 0

    # Determine trend
    delta = avg_recent - avg_older

    if abs(delta) < 0.05:  # Less than 5% change
        trend = 'stable'
    elif delta > 0:
        trend = 'improving'
    else:
        trend = 'declining'

    return {
        'completion_rate_trend': trend,
        'trend_delta_pct': round(delta * 100, 1),
        'avg_completion_recent_7d': round(avg_recent * 100, 1),
        'avg_completion_older_7d': round(avg_older * 100, 1),
        'games_in_recent': len(recent_rates),
        'games_in_older': len(older_rates)
    }


def get_top_performers(games, metric='completion_rate', limit=3):
    """Get top N games by specified metric.

    Args:
        games: List of game dicts
        metric: 'completion_rate', 'engagement_score', or 'quality_score'
        limit: Number of games to return

    Returns list of top game dicts.
    """
    valid_games = [g for g in games if metric in g]
    sorted_games = sorted(valid_games, key=lambda g: g[metric], reverse=True)
    return sorted_games[:limit]


def get_worst_performers(games, metric='completion_rate', limit=3):
    """Get bottom N games by specified metric.

    Args:
        games: List of game dicts
        metric: 'completion_rate', 'engagement_score', or 'quality_score'
        limit: Number of games to return

    Returns list of worst game dicts.
    """
    valid_games = [g for g in games if metric in g]
    sorted_games = sorted(valid_games, key=lambda g: g[metric])
    return sorted_games[:limit]


def generate_recommendations(games, genre_performance, trend_info):
    """Generate recommendations for today's game based on analysis.

    Args:
        games: List of game dicts from past 14 days
        genre_performance: Dict of genre stats
        trend_info: Trend analysis dict

    Returns dict with recommendations.
    """
    if len(games) == 0:
        return {
            'recommended_genres': ['puzzle'],
            'avoid_genres': [],
            'recommended_difficulty': 3,
            'target_playtime_minutes': 5,
            'target_engagement_score': 0.3,
            'reasoning': 'Insufficient data for recommendations; defaults provided'
        }

    # Identify underperforming and overperforming genres
    avoid_genres = []
    recommended_genres = []

    if genre_performance:
        # Sort by completion rate
        sorted_genres = sorted(
            genre_performance.items(),
            key=lambda x: x[1]['avg_completion']
        )

        # Genres with <25% completion are risky
        for genre, stats in sorted_genres[:2]:
            if stats['avg_completion'] < 0.25:
                avoid_genres.append(genre)

        # Genres with >35% completion are good bets
        for genre, stats in sorted(sorted_genres, key=lambda x: x[1]['avg_completion'], reverse=True)[:2]:
            if stats['avg_completion'] >= 0.35 and genre not in avoid_genres:
                recommended_genres.append(genre)

    # Ensure we have recommendations
    if not recommended_genres and genre_performance:
        # Fall back to highest-performing genres
        recommended_genres = [
            g for g, _ in sorted(
                genre_performance.items(),
                key=lambda x: x[1]['avg_completion'],
                reverse=True
            )[:2]
        ]

    # Recommended difficulty: average - 0.5 (slightly easier than average)
    difficulties = [g.get('difficulty', 3) for g in games if 'difficulty' in g]
    avg_difficulty = statistics.mean(difficulties) if difficulties else 3
    recommended_difficulty = max(1, min(5, int(avg_difficulty - 0.5)))

    # Target engagement based on successful games (>40% completion)
    successful = [g for g in games if g.get('completion_rate', 0) >= 0.4]
    if successful:
        engagements = [g.get('engagement_score', 0) for g in successful]
        target_engagement = round(statistics.mean(engagements), 2)
    else:
        target_engagement = 0.35

    # Build reasoning
    reasoning_parts = []
    if avoid_genres:
        reasoning_parts.append(f"{', '.join(avoid_genres)} games underperforming")
    if recommended_genres:
        reasoning_parts.append(f"{', '.join(recommended_genres)} has good completion")
    if trend_info['completion_rate_trend'] == 'declining':
        reasoning_parts.append("completion rate declining - focus on engagement")

    reasoning = "; ".join(reasoning_parts) if reasoning_parts else "Based on recent performance data"

    return {
        'recommended_genres': recommended_genres[:2] if recommended_genres else ['puzzle'],
        'avoid_genres': avoid_genres[:2] if avoid_genres else [],
        'recommended_difficulty': recommended_difficulty,
        'target_playtime_minutes': 5,
        'target_engagement_score': target_engagement,
        'reasoning': reasoning
    }


def generate_risk_alerts(games, genre_performance, trend_info):
    """Generate risk alerts based on data patterns.

    Args:
        games: List of game dicts
        genre_performance: Dict of genre stats
        trend_info: Trend analysis dict

    Returns list of alert dicts.
    """
    alerts = []

    # Alert 1: Declining completion rate
    if trend_info.get('completion_rate_trend') == 'declining':
        delta = abs(trend_info.get('trend_delta_pct', 0))
        alerts.append({
            'severity': 'warning',
            'message': f"Completion rate declining: last 7 games avg {trend_info.get('avg_completion_recent_7d', 0)}% "
                      f"vs prior 7 games avg {trend_info.get('avg_completion_older_7d', 0)}%"
        })

    # Alert 2: Genre underperformance
    for genre, stats in genre_performance.items():
        if stats['games'] >= 2 and stats['avg_completion'] < 0.25:
            underperforming = [g for g in stats['games_list'] if g['completion_rate'] < 0.25]
            if len(underperforming) >= 2:
                alerts.append({
                    'severity': 'warning',
                    'message': f"{genre.capitalize()} games underperforming: "
                              f"{len(underperforming)}/{stats['games']} below 25% completion"
                })

    # Alert 3: Difficulty mismatch
    created_difficulties = [g.get('difficulty', 3) for g in games]
    completed_games = [g for g in games if g.get('completion_rate', 0) >= 0.5]

    if created_difficulties and completed_games:
        created_avg = round(statistics.mean(created_difficulties), 1)
        completed_difficulties = [g.get('difficulty', 3) for g in completed_games]
        completed_avg = round(statistics.mean(completed_difficulties), 1)

        if created_avg > completed_avg + 0.5:
            alerts.append({
                'severity': 'warning',
                'message': f"Difficulty mismatch: creating games at difficulty {created_avg} "
                          f"but high-completion games average {completed_avg}"
            })

    # Alert 4: Excessive "too_hard" assessments
    too_hard_count = sum(
        1 for g in games
        if g.get('difficulty_assessment', '') == 'too_hard'
    )
    if len(games) >= 5 and too_hard_count >= len(games) * 0.7:
        alerts.append({
            'severity': 'critical',
            'message': f"Difficulty crisis: {too_hard_count}/{len(games)} games marked 'too_hard' "
                      f"({round(too_hard_count/len(games)*100, 0):.0f}%)"
        })

    return alerts


def calculate_daily_stats(games):
    """Calculate aggregate stats for the time period.

    Args:
        games: List of game dicts

    Returns dict with aggregated statistics.
    """
    if not games:
        return {}

    completion_rates = [g.get('completion_rate', 0) for g in games]
    engagement_scores = [g.get('engagement_score', 0) for g in games]
    difficulties = [g.get('difficulty', 3) for g in games]

    stats = {
        'games_analyzed': len(games),
        'avg_completion_rate': round(statistics.mean(completion_rates), 3) if completion_rates else 0,
        'median_completion_rate': round(statistics.median(completion_rates), 3) if completion_rates else 0,
        'min_completion_rate': min(completion_rates) if completion_rates else 0,
        'max_completion_rate': max(completion_rates) if completion_rates else 0,
        'avg_engagement_score': round(statistics.mean(engagement_scores), 3) if engagement_scores else 0,
        'avg_difficulty': round(statistics.mean(difficulties), 1) if difficulties else 0,
        'avg_difficulty_assessment': count_majority([g.get('difficulty_assessment', 'unknown') for g in games])
    }

    return stats


def count_majority(items):
    """Return most common item in list, or 'unknown' if empty.

    Args:
        items: List of items

    Returns most common item string.
    """
    if not items:
        return 'unknown'

    from collections import Counter
    counts = Counter(items)
    return counts.most_common(1)[0][0]


def format_game_reference(game):
    """Format a game entry for reference sections.

    Args:
        game: Game dict from catalog

    Returns dict with key fields.
    """
    return {
        'date': game.get('date', 'unknown'),
        'title': game.get('title', 'Untitled'),
        'completion_rate': game.get('completion_rate', 0),
        'engagement_score': game.get('engagement_score', 0),
        'difficulty': game.get('difficulty', 0),
        'difficulty_assessment': game.get('difficulty_assessment', 'unknown'),
        'genres': game.get('genres', []),
        'game_quality_score': game.get('game_quality_score', 0)
    }


def generate_intelligence_report(target_date_str=None):
    """Generate daily intelligence report.

    Args:
        target_date_str: YYYY-MM-DD date string, or None for today

    Returns dict with complete intelligence report.
    """
    # Parse target date
    if target_date_str:
        target_date = parse_date(target_date_str)
        if not target_date:
            print(f"Invalid date format: {target_date_str}", file=sys.stderr)
            return None
    else:
        target_date = datetime.now().date()

    # Load catalog
    catalog = load_catalog()
    if not catalog:
        print("Error: catalog.json not found", file=sys.stderr)
        return None

    # Get games from past 14 days
    games = get_games_in_range(catalog, target_date, days=14)

    # Analyze genres
    genre_performance = analyze_genre_performance(games)

    # Calculate trend
    trend_info = calculate_trend(games)

    # Get aggregated stats
    daily_stats = calculate_daily_stats(games)

    # Generate recommendations
    recommendations = generate_recommendations(games, genre_performance, trend_info)

    # Generate risk alerts
    risk_alerts = generate_risk_alerts(games, genre_performance, trend_info)

    # Get reference games
    top_performers = get_top_performers(games, 'completion_rate', limit=3)
    most_engaging = get_top_performers(games, 'engagement_score', limit=3)
    quality_leaders = get_top_performers(games, 'game_quality_score', limit=3)

    # Build genre performance output
    genre_output = {}
    for genre, stats in sorted(genre_performance.items()):
        # Recommend or avoid based on completion rate
        avg_comp = stats['avg_completion']
        if avg_comp >= 0.4:
            recommendation = 'recommended'
        elif avg_comp < 0.25:
            recommendation = 'avoid'
        else:
            recommendation = 'balanced'

        genre_output[genre] = {
            'avg_completion': stats['avg_completion'],
            'avg_engagement': stats['avg_engagement'],
            'games_in_period': stats['games'],
            'min_max_completion': [stats['min_completion'], stats['max_completion']],
            'recommendation': recommendation
        }

    # Assemble final report
    report = {
        'date': target_date.isoformat(),
        'generated_at': datetime.now().isoformat(),
        'period_analyzed_days': 14,
        'trend_analysis': {
            'completion_rate_trend': trend_info['completion_rate_trend'],
            'trend_delta_pct': trend_info['trend_delta_pct'],
            'avg_completion_recent_7d': trend_info.get('avg_completion_recent_7d', 0),
            'avg_completion_older_7d': trend_info.get('avg_completion_older_7d', 0),
            'genre_performance': genre_output,
            'overall_stats': daily_stats
        },
        'todays_recommendations': recommendations,
        'reference_games': {
            'top_performers': [format_game_reference(g) for g in top_performers],
            'most_engaging': [format_game_reference(g) for g in most_engaging],
            'quality_leaders': [format_game_reference(g) for g in quality_leaders]
        },
        'risk_alerts': risk_alerts,
        'data_quality': {
            'games_analyzed': len(games),
            'genres_represented': len(genre_performance),
            'has_sufficient_data': len(games) >= 7
        }
    }

    return report


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Generate daily game intelligence report'
    )
    parser.add_argument(
        '--date',
        help='Generate report for specific date (YYYY-MM-DD, default: today)',
        default=None
    )
    parser.add_argument(
        '--output',
        help='Output file path (default: games/<date>/daily-intelligence.json)',
        default=None
    )

    args = parser.parse_args()

    # Generate report
    report = generate_intelligence_report(args.date)
    if not report:
        sys.exit(1)

    # Determine output path
    if args.output:
        output_path = args.output
    else:
        target_date = args.date or datetime.now().date().isoformat()
        games_dir = os.path.join('games', target_date)
        os.makedirs(games_dir, exist_ok=True)
        output_path = os.path.join(games_dir, 'daily-intelligence.json')

    # Write report
    try:
        os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"✓ Report generated: {output_path}")
        return 0
    except IOError as e:
        print(f"Error writing report: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
