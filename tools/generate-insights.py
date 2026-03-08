#!/usr/bin/env python3
"""Generate insights files for all games with session data.

Analyzes gameplay sessions using the analytics engine to produce
human-readable insights about game difficulty, engagement, and design issues.

Usage:
  python3 tools/generate-insights.py [--games <date>,<date>,...] [--force]

Examples:
  # Generate insights for all games
  python3 tools/generate-insights.py

  # Generate for specific games
  python3 tools/generate-insights.py --games 2026-03-07,2026-03-08

  # Regenerate existing insights
  python3 tools/generate-insights.py --force
"""

import os
import json
import sys
import re
import argparse
from pathlib import Path

# Import analytics engine
sys.path.insert(0, os.path.dirname(__file__))
from analytics_engine import (
    generate_insights,
    find_all_games,
)


def insights_exists(game_dir):
    """Check if insights.json already exists.

    Returns True if file exists, False otherwise.
    """
    insights_path = os.path.join(game_dir, 'insights.json')
    return os.path.exists(insights_path)


def save_insights(game_dir, insights):
    """Save insights dict to insights.json.

    Returns True on success, False on error.
    """
    if not insights:
        return False

    insights_path = os.path.join(game_dir, 'insights.json')
    try:
        os.makedirs(game_dir, exist_ok=True)
        with open(insights_path, 'w') as f:
            json.dump(insights, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving insights for {game_dir}: {e}", flush=True)
        return False


def generate_insights_for_game(game_date, game_dir, verbose=True):
    """Generate and save insights for a single game.

    Returns True if successful, False otherwise.
    """
    insights = generate_insights(game_date, game_dir)

    if not insights:
        if verbose:
            print(f"  ⚠ {game_date}: No session data available", flush=True)
        return False

    if not insights.get('has_sessions'):
        if verbose:
            print(f"  ⓘ {game_date}: No sessions (using defaults)", flush=True)
        saved = save_insights(game_dir, insights)
        return saved

    # Has sessions and insights
    if save_insights(game_dir, insights):
        if verbose:
            difficulty = insights.get('difficulty_assessment', {}).get('assessment', 'unknown')
            engagement = insights.get('engagement_score', 0)
            print(f"  ✓ {game_date}: {difficulty.capitalize()} (engagement: {engagement:.2f})", flush=True)
        return True
    else:
        if verbose:
            print(f"  ✗ {game_date}: Failed to save insights", flush=True)
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Generate insights files for games with session data'
    )
    parser.add_argument(
        '--games',
        help='Comma-separated list of game dates to process (default: all games)',
        default=None
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Regenerate insights even if they already exist'
    )

    args = parser.parse_args()

    # Find games
    all_games = find_all_games()
    if not all_games:
        print("No games found", file=sys.stderr, flush=True)
        return 1

    # Filter games if specified
    if args.games:
        requested_dates = set(args.games.split(','))
        games_to_process = [
            (date, path) for date, path in all_games
            if date in requested_dates
        ]
        if not games_to_process:
            print(f"No games found matching: {args.games}", file=sys.stderr, flush=True)
            return 1
    else:
        games_to_process = all_games

    print(f"Generating insights for {len(games_to_process)} game(s)", flush=True)
    print()

    insights_generated = 0
    insights_skipped = 0

    for game_date, game_dir in games_to_process:
        if not args.force and insights_exists(game_dir):
            print(f"{game_date}: Insights already exist, skipping (use --force to regenerate)", flush=True)
            insights_skipped += 1
            continue

        if generate_insights_for_game(game_date, game_dir, verbose=True):
            insights_generated += 1

    print()
    print(f"✓ Generated {insights_generated} insight files", flush=True)
    if insights_skipped > 0:
        print(f"⊘ Skipped {insights_skipped} existing insights", flush=True)

    return 0


if __name__ == '__main__':
    sys.exit(main())
