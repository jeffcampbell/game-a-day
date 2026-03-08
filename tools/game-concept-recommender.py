#!/usr/bin/env python3
"""Game concept recommender - Analyzes recent games and suggests next game concepts.

Analyzes genre usage, difficulty distribution, mechanics patterns, and player
engagement to provide actionable recommendations for the next game to build.

Problem:
CLAUDE.md requires developers to manually check the last few days' games for
variety, but this is error-prone. Current catalog shows genre imbalance:
- 7/13 puzzle games (54% repetition)
- 10/13 games marked "too_hard"

Solution:
Build a tool that recommends:
1. Top 3 genres by "neediness" (underused + high-engagement)
2. Recommended difficulty level
3. Mechanics to avoid and try
4. Resource budget guidance
5. Variety score for recent games

Usage:
  python3 tools/game-concept-recommender.py              # Recommend for today
  python3 tools/game-concept-recommender.py --days 14   # Analyze 14-day window
  python3 tools/game-concept-recommender.py --json      # Output JSON format
  python3 tools/game-concept-recommender.py --all-genres # Show all genre stats
"""

import os
import sys
import json
import re
import math
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timedelta, timezone
from collections import defaultdict, Counter


# All known genres in the system
KNOWN_GENRES = [
    "action", "adventure", "puzzle", "rpg", "sports", "strategy",
    "rhythm", "educational"
]

# Default engagement scores for genres (if no real data available)
DEFAULT_ENGAGEMENT_SCORES = {
    "action": 0.75,
    "adventure": 0.70,
    "puzzle": 0.50,
    "rpg": 0.80,
    "sports": 0.60,
    "strategy": 0.55,
    "rhythm": 0.65,
    "educational": 0.40,
}

# Mechanics patterns to detect in code
MECHANICS_PATTERNS = {
    "jump": r"\bjump|\by\s*[+-]=",
    "dodge": r"dodge|avoid|collision|hit",
    "match": r"match|tile|grid|piece|swap",
    "collect": r"collect|pickup|item|inventory|power.?up",
    "shoot": r"shoot|bullet|projectile|fire",
    "explore": r"explore|map|world|warp|room",
    "build": r"build|place|construct|block",
    "defend": r"defend|tower|protect|guard",
    "race": r"race|speed|lap|checkpoint",
    "flip": r"flip|rotate|turn|spin",
}


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


def parse_date(date_str):
    """Parse game date string (YYYY-MM-DD) to datetime."""
    try:
        return datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return None


def get_games_in_window(catalog, days=7):
    """Get games within the specified day window.

    Args:
        catalog: Loaded catalog dict
        days: Number of days to look back (default 7)

    Returns list of games sorted by date (newest first).
    """
    if not catalog or 'games' not in catalog:
        return []

    games = catalog['games']
    if not games:
        return []

    # Calculate cutoff date
    today = parse_date(games[0]['date'])  # Newest game date
    if not today:
        return []

    cutoff = today - timedelta(days=days - 1)

    recent_games = [g for g in games if parse_date(g['date']) and parse_date(g['date']) >= cutoff]
    return recent_games


def analyze_genre_distribution(games):
    """Analyze genre usage in the game window.

    Returns dict with genre stats:
    {
        'genre_name': {
            'count': int,
            'percent': float,
            'games': [dates],
            'avg_engagement': float,
            'avg_difficulty': float
        }
    }
    """
    genre_stats = defaultdict(lambda: {
        'count': 0,
        'games': [],
        'engagement_scores': [],
        'difficulties': []
    })

    for game in games:
        genres = game.get('genres', [])
        if isinstance(genres, list):
            for genre in genres:
                genre_stats[genre]['count'] += 1
                genre_stats[genre]['games'].append(game['date'])

                # Collect metrics
                engagement = game.get('engagement_score', 0)
                if engagement > 0:
                    genre_stats[genre]['engagement_scores'].append(engagement)

                difficulty = game.get('difficulty', 0)
                if difficulty > 0:
                    genre_stats[genre]['difficulties'].append(difficulty)

    # Convert to final format
    total_games = len(games)
    result = {}
    for genre, stats in genre_stats.items():
        result[genre] = {
            'count': stats['count'],
            'percent': round(100 * stats['count'] / total_games, 1) if total_games > 0 else 0,
            'games': stats['games'],
            'avg_engagement': round(sum(stats['engagement_scores']) / len(stats['engagement_scores']), 3)
                if stats['engagement_scores'] else 0,
            'avg_difficulty': round(sum(stats['difficulties']) / len(stats['difficulties']), 1)
                if stats['difficulties'] else 0,
        }

    return result


def detect_mechanics_in_code(game_dir):
    """Detect mechanics in game code.

    Returns dict mapping mechanic_name -> bool (detected or not).
    """
    game_p8 = os.path.join(game_dir, 'game.p8')
    if not os.path.exists(game_p8):
        return {}

    try:
        with open(game_p8, 'r') as f:
            code = f.read()
    except IOError:
        return {}

    # Extract lua section only
    match = re.search(r'__lua__\n(.*?)(?=\n__[a-z]+__|$)', code, re.DOTALL)
    if match:
        code = match.group(1)

    detected = {}
    for mechanic, pattern in MECHANICS_PATTERNS.items():
        detected[mechanic] = bool(re.search(pattern, code, re.IGNORECASE))

    return detected


def analyze_mechanics_usage(games):
    """Analyze repeated mechanics in recent games.

    Returns dict:
    {
        'detected_mechanics': {mechanic: count},
        'repeated_mechanics': [mechanics used > 30% of games],
        'underused_mechanics': [mechanics used < 20% of games]
    }
    """
    all_mechanics = defaultdict(int)
    game_count = len(games)

    if game_count == 0:
        return {
            'detected_mechanics': {},
            'repeated_mechanics': [],
            'underused_mechanics': []
        }

    for game in games:
        game_dir = os.path.join('games', game['date'])
        mechanics = detect_mechanics_in_code(game_dir)
        for mechanic, detected in mechanics.items():
            if detected:
                all_mechanics[mechanic] += 1

    # Classify mechanics
    repeated = []
    underused = []

    for mechanic, count in all_mechanics.items():
        percent = count / game_count
        if percent > 0.3:  # >30%
            repeated.append(mechanic)
        elif percent < 0.2:  # <20%
            underused.append(mechanic)

    return {
        'detected_mechanics': dict(all_mechanics),
        'repeated_mechanics': sorted(repeated),
        'underused_mechanics': sorted(underused),
    }


def calculate_difficulty_stats(games):
    """Calculate difficulty distribution and recommendations.

    Returns dict with difficulty stats and recommendation.
    """
    difficulties = [g.get('difficulty', 3) for g in games if g.get('difficulty')]

    if not difficulties:
        return {
            'min': 1,
            'max': 5,
            'average': 3,
            'distribution': {},
            'recommended': 2,
            'reasoning': "No difficulty data; recommend easy game"
        }

    dist = Counter(difficulties)
    avg = round(sum(difficulties) / len(difficulties), 1)

    # Recommend complementary difficulty
    if avg >= 4.0:
        recommended = 1  # Too hard recently, go easy
    elif avg >= 3.5:
        recommended = 2
    elif avg <= 2.0:
        recommended = 4  # Too easy recently, go harder
    elif avg <= 2.5:
        recommended = 4
    else:
        recommended = 3  # Balanced

    return {
        'min': min(difficulties),
        'max': max(difficulties),
        'average': avg,
        'distribution': dict(sorted(dist.items())),
        'recommended': recommended,
        'reasoning': f"Recent average is {avg} - recommend difficulty {recommended} for balance"
    }


def calculate_variety_score(genre_stats, games):
    """Calculate a variety score (0-100) for recent games.

    0-30: Low variety (problematic)
    30-60: Moderate variety
    60-100: High variety
    """
    if not games:
        return 100

    # Calculate concentration: if one or two genres dominate, variety is low
    game_count = len(games)
    genre_percents = [g['percent'] for g in genre_stats.values()]

    if not genre_percents:
        return 100

    # Use Herfindahl-Hirschman Index (HHI) for concentration
    # Convert percent to decimal: genre_percents are already in 0-100
    hhi = sum((p / 100) ** 2 for p in genre_percents)

    # HHI ranges from 0 to 1, convert to 0-100 variety score
    # HHI of 0.5 (high concentration) = variety score of 0
    # HHI of 0.125 (perfect balance of 8 genres) = variety score of 100
    variety = max(0, 100 * (0.5 - hhi) / 0.5)

    return round(variety, 1)


def rank_genres_by_neediness(genre_stats, catalog_stats):
    """Rank genres by "neediness" - underused but high-engagement.

    Neediness = (1 - usage_percent) * engagement_score

    Returns list of (genre, neediness_score, details) tuples.
    """
    all_genres = set(genre_stats.keys()) | set(KNOWN_GENRES)

    ranked = []
    for genre in all_genres:
        usage = genre_stats.get(genre, {})
        percent = usage.get('percent', 0)

        # Get engagement score (from catalog stats or default)
        if 'statistics' in catalog_stats and 'genre_distribution' in catalog_stats.get('statistics', {}):
            all_time_count = catalog_stats['statistics'].get('genre_distribution', {}).get(genre, 0)
            all_time_total = catalog_stats['statistics'].get('total_games', 1)
            all_time_percent = (all_time_count / all_time_total * 100) if all_time_total > 0 else 0
        else:
            all_time_percent = 0

        engagement = usage.get('avg_engagement', DEFAULT_ENGAGEMENT_SCORES.get(genre, 0.5))

        # Neediness: avoid very low engagement, favor underused genres with high engagement
        if engagement > 0:
            neediness = (1 - percent / 100) * engagement
        else:
            neediness = 1 - (percent / 100)

        ranked.append((genre, round(neediness, 3), {
            'current_usage': percent,
            'all_time_usage': round(all_time_percent, 1),
            'engagement': round(engagement, 3)
        }))

    # Sort by neediness, descending
    ranked.sort(key=lambda x: x[1], reverse=True)

    return ranked


def generate_recommendation_text(recommendation):
    """Generate human-readable recommendation text."""
    lines = []

    # Genre recommendation
    top_genres = recommendation.get('top_genres', [])
    if top_genres:
        genre_list = ', '.join(top_genres[:3])
        lines.append(f"Recommended genres: {genre_list}")

    # Difficulty
    diff_rec = recommendation.get('difficulty', {})
    if diff_rec:
        lines.append(f"Recommended difficulty: {diff_rec.get('recommended')} (recent avg: {diff_rec.get('average')})")

    # Mechanics to avoid
    mech = recommendation.get('mechanics', {})
    avoid = mech.get('repeated_mechanics', [])
    if avoid:
        avoid_str = ', '.join(avoid)
        lines.append(f"Avoid repeating: {avoid_str}")

    # Mechanics to try
    try_mechanics = mech.get('underused_mechanics', [])
    if try_mechanics:
        try_str = ', '.join(try_mechanics[:3])
        lines.append(f"Try exploring: {try_str}")

    # Variety score
    variety = recommendation.get('variety_score', 0)
    if variety < 30:
        lines.append(f"⚠️  Variety score LOW ({variety}/100) - strong need for different genre")
    elif variety < 60:
        lines.append(f"Variety score moderate ({variety}/100)")
    else:
        lines.append(f"Variety score good ({variety}/100)")

    return '\n'.join(lines)


def generate_recommendation(catalog, days=7):
    """Generate concept recommendation based on catalog analysis.

    Args:
        catalog: Loaded catalog dict
        days: Number of days to analyze

    Returns dict with recommendation data.
    """
    games = get_games_in_window(catalog, days)

    if not games:
        return {
            'status': 'error',
            'message': 'No games found in specified window',
            'window_days': days,
            'games_analyzed': 0,
        }

    if len(games) < 3:
        return {
            'status': 'warning',
            'message': f'Only {len(games)} games in window; recommendations may be limited',
            'window_days': days,
            'games_analyzed': len(games),
        }

    # Analyze
    genre_stats = analyze_genre_distribution(games)
    mechanics = analyze_mechanics_usage(games)
    difficulty = calculate_difficulty_stats(games)
    variety = calculate_variety_score(genre_stats, games)
    ranked_genres = rank_genres_by_neediness(genre_stats, catalog)

    # Top 3 genres by neediness
    top_genres = [g[0] for g in ranked_genres[:3]]

    # Resource budget (based on recent avg)
    token_usage = [g.get('token_count', 0) for g in games if g.get('token_count', 0) > 0]
    sprite_usage = [g.get('sprite_count', 0) for g in games if g.get('sprite_count', 0) > 0]
    sound_usage = [g.get('sound_count', 0) for g in games if g.get('sound_count', 0) > 0]

    avg_tokens = round(sum(token_usage) / len(token_usage), 0) if token_usage else 5000
    avg_sprites = round(sum(sprite_usage) / len(sprite_usage), 0) if sprite_usage else 10
    avg_sounds = round(sum(sound_usage) / len(sound_usage), 0) if sound_usage else 5

    tokens_available = max(0, 8192 - int(avg_tokens))
    if tokens_available > 0:
        token_guidance = f"Recent games average ~{int(avg_tokens)} tokens; budget {tokens_available} tokens for next game"
    else:
        token_guidance = f"Recent games average ~{int(avg_tokens)} tokens (near limit!); aim for simpler mechanics"

    recommendation = {
        'generated': datetime.now(timezone.utc).isoformat(),
        'window_days': days,
        'games_analyzed': len(games),
        'variety_score': variety,
        'top_genres': top_genres,
        'genre_stats': genre_stats,
        'genre_ranking': [
            {
                'rank': i + 1,
                'genre': g[0],
                'neediness_score': g[1],
                'details': g[2]
            }
            for i, g in enumerate(ranked_genres)
        ],
        'difficulty': difficulty,
        'mechanics': mechanics,
        'resource_budget': {
            'average_tokens': int(avg_tokens),
            'tokens_available': tokens_available,
            'average_sprites': int(avg_sprites),
            'average_sounds': int(avg_sounds),
            'guidance': token_guidance
        },
        'status': 'success'
    }

    return recommendation


def write_recommendation_to_game_dir(recommendation, date):
    """Write recommendation to game directory as concept-recommendation.json."""
    if recommendation.get('status') != 'success':
        return False

    game_dir = os.path.join('games', date)
    if not os.path.exists(game_dir):
        os.makedirs(game_dir, exist_ok=True)

    output_path = os.path.join(game_dir, 'concept-recommendation.json')

    try:
        with open(output_path, 'w') as f:
            json.dump(recommendation, f, indent=2)
        return True
    except IOError as e:
        print(f"Error writing recommendation to {output_path}: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Recommend game concepts based on recent game analysis'
    )
    parser.add_argument('--days', type=int, default=7,
                        help='Number of days to analyze (default 7)')
    parser.add_argument('--json', action='store_true',
                        help='Output as JSON only (no human-readable text)')
    parser.add_argument('--all-genres', action='store_true',
                        help='Show stats for all genres, not just top 5')
    parser.add_argument('--date', type=str, default=None,
                        help='Target date for recommendation (YYYY-MM-DD, default: today)')

    args = parser.parse_args()

    # Validate date argument if provided
    if args.date:
        if not parse_date(args.date):
            print(f"Error: Invalid date format '{args.date}'. Use YYYY-MM-DD format.", file=sys.stderr)
            sys.exit(1)
        target_date = args.date
    else:
        # Use today's date
        target_date = datetime.now().strftime('%Y-%m-%d')

    # Load catalog
    catalog = load_catalog()
    if not catalog:
        print("Error: Could not load catalog.json", file=sys.stderr)
        sys.exit(1)

    # Generate recommendation
    recommendation = generate_recommendation(catalog, days=args.days)

    # Write to game directory if successful
    if recommendation.get('status') == 'success':
        write_recommendation_to_game_dir(recommendation, target_date)

    # Output
    if args.json:
        print(json.dumps(recommendation, indent=2))
    else:
        # Human-readable output
        print(f"Game Concept Recommendation")
        print(f"=" * 50)
        print(f"Analyzed: {recommendation.get('games_analyzed')} games ({args.days}-day window)")
        print()

        if recommendation.get('status') != 'success':
            print(f"Status: {recommendation.get('status')}")
            print(f"Message: {recommendation.get('message')}")
            sys.exit(0)

        # Variety
        variety = recommendation.get('variety_score', 0)
        print(f"Variety Score: {variety}/100", end="")
        if variety < 30:
            print(" ⚠️ LOW - Strong need for genre diversity")
        elif variety < 60:
            print(" (Moderate)")
        else:
            print(" (Good)")
        print()

        # Genre stats
        print(f"\nRecent Genre Distribution:")
        genre_stats = recommendation.get('genre_stats', {})
        for genre in sorted(genre_stats.keys(), key=lambda g: genre_stats[g]['percent'], reverse=True):
            stats = genre_stats[genre]
            print(f"  {genre:12} {stats['percent']:5.1f}% ({stats['count']} games, engagement: {stats['avg_engagement']:.2f})")

        # Top genres
        max_genres = len(recommendation.get('genre_ranking', [])) if args.all_genres else 3
        print(f"\nTop Recommended Genres:")
        for item in recommendation.get('genre_ranking', [])[:max_genres]:
            genre = item['genre']
            score = item['neediness_score']
            details = item['details']
            print(f"  {item['rank']}. {genre:12} (neediness: {score:.2f})")
            print(f"     Current: {details['current_usage']:.1f}% | All-time: {details['all_time_usage']:.1f}% | Engagement: {details['engagement']:.2f}")

        # Difficulty
        diff = recommendation.get('difficulty', {})
        print(f"\nDifficulty Recommendation:")
        print(f"  Recommended: {diff.get('recommended')} (Recent avg: {diff.get('average')})")
        print(f"  {diff.get('reasoning')}")

        # Mechanics
        mech = recommendation.get('mechanics', {})
        avoid = mech.get('repeated_mechanics', [])
        try_list = mech.get('underused_mechanics', [])

        if avoid:
            print(f"\nMechanics to Avoid (overused):")
            for m in avoid:
                count = mech['detected_mechanics'].get(m, 0)
                print(f"  • {m} ({count} of {recommendation.get('games_analyzed')} games)")

        if try_list:
            print(f"\nMechanics to Try (underused):")
            for m in try_list[:5]:
                count = mech['detected_mechanics'].get(m, 0)
                print(f"  • {m} ({count} of {recommendation.get('games_analyzed')} games)")

        # Resources
        resources = recommendation.get('resource_budget', {})
        print(f"\nResource Budget Guidance:")
        print(f"  {resources.get('guidance')}")

        print(f"\nRecommendation written to: games/{target_date}/concept-recommendation.json")


if __name__ == '__main__':
    main()
