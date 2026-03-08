#!/usr/bin/env python3
"""Batch metadata initializer for PICO-8 games.

Automatically bootstraps metadata.json files for all games without metadata,
by analyzing game.p8 files and generating intelligent defaults.

Usage:
  python3 tools/init-game-metadata.py [--auto]

Options:
  --auto              Auto-apply all suggested metadata without confirmation
  --dry-run           Show suggestions without creating files
"""

import os
import sys
import json
import re
import subprocess
from pathlib import Path
from datetime import datetime


VALID_GENRES = {
    "puzzle", "action", "adventure", "strategy", "rhythm", "rpg", "sports", "educational"
}

VALID_AUDIENCES = {
    "general", "children", "teens", "adults", "expert"
}

# Keywords to detect genres in code
GENRE_KEYWORDS = {
    "action": ["jump", "dodge", "enemy", "shoot", "attack", "collision", "hit", "damage"],
    "puzzle": ["match", "piece", "block", "grid", "solve", "logic", "rotate"],
    "adventure": ["explore", "map", "world", "quest", "discover", "item", "inventory"],
    "strategy": ["turn", "ai", "bot", "pathfind", "move", "plan"],
    "rhythm": ["beat", "music", "tempo", "sync", "dance"],
    "rpg": ["player", "level", "exp", "stat", "character", "hp", "equip"],
    "sports": ["ball", "game", "score", "race", "compete", "team"],
    "educational": ["learn", "teach", "quiz", "count", "letter"]
}


def find_all_games():
    """Find all game directories without metadata.json."""
    games = []
    games_dir = "games"

    if not os.path.isdir(games_dir):
        print(f"Error: {games_dir} directory not found", file=sys.stderr)
        return games

    for entry in sorted(os.listdir(games_dir)):
        if re.match(r'^\d{4}-\d{2}-\d{2}$', entry):
            game_dir = os.path.join(games_dir, entry)
            if os.path.isdir(game_dir):
                game_p8 = os.path.join(game_dir, "game.p8")
                metadata_file = os.path.join(game_dir, "metadata.json")

                # Only process games with game.p8 but no metadata.json
                if os.path.exists(game_p8) and not os.path.exists(metadata_file):
                    games.append((entry, game_dir))

    return games


def extract_lua_section(game_p8_path):
    """Extract Lua code from __lua__ section."""
    try:
        with open(game_p8_path, 'r') as f:
            content = f.read()
    except (IOError, OSError):
        return ""

    lines = content.split("\n")
    lua_lines = []
    in_lua = False

    for line in lines:
        if line.startswith("__lua__"):
            in_lua = True
            continue
        if in_lua and re.match(r"^__[a-z]+__\s*$", line):
            in_lua = False
            continue
        if in_lua:
            lua_lines.append(line)

    return "\n".join(lua_lines)


def extract_first_comment(lua_code):
    """Extract first meaningful comment as game title."""
    lines = lua_code.split("\n")
    for line in lines[:20]:  # Check first 20 lines
        stripped = line.strip()
        if stripped.startswith("--") and not stripped.startswith("-- test"):
            # Extract comment text, remove -- prefix
            title = stripped[2:].strip()
            if title and len(title) > 0 and len(title) < 60:
                return title
    return None


def extract_gfx_section(game_p8_path):
    """Extract __gfx__ section for sprite analysis."""
    try:
        with open(game_p8_path, 'r') as f:
            content = f.read()
    except (IOError, OSError):
        return ""

    lines = content.split("\n")
    gfx_lines = []
    in_gfx = False

    for line in lines:
        if line.startswith("__gfx__"):
            in_gfx = True
            continue
        if in_gfx and re.match(r"^__[a-z]+__\s*$", line):
            in_gfx = False
            continue
        if in_gfx:
            gfx_lines.append(line)

    return "\n".join(gfx_lines)


def extract_sfx_section(game_p8_path):
    """Extract __sfx__ section for sound analysis."""
    try:
        with open(game_p8_path, 'r') as f:
            content = f.read()
    except (IOError, OSError):
        return ""

    lines = content.split("\n")
    sfx_lines = []
    in_sfx = False

    for line in lines:
        if line.startswith("__sfx__"):
            in_sfx = True
            continue
        if in_sfx and re.match(r"^__[a-z]+__\s*$", line):
            in_sfx = False
            continue
        if in_sfx:
            sfx_lines.append(line)

    return "\n".join(sfx_lines)


def count_token_count(game_p8_path):
    """Run p8tokens.py to count tokens."""
    try:
        result = subprocess.run(
            ['python3', 'tools/p8tokens.py', game_p8_path],
            capture_output=True,
            text=True,
            timeout=5
        )
        # Parse output: "TOKENS: 3450/8192"
        match = re.search(r'TOKENS:\s*(\d+)', result.stdout)
        if match:
            return int(match.group(1))
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        pass

    return None


def count_sprites(gfx_content):
    """Count non-zero sprites in __gfx__ section."""
    count = 0
    for line in gfx_content.split("\n"):
        if line.strip() and any(c != '0' for c in line):
            count += 1
    return count


def count_sounds(sfx_content):
    """Count non-empty sound definitions in __sfx__ section."""
    count = 0
    for line in sfx_content.split("\n"):
        if line.strip() and not line.startswith(';'):
            count += 1
    return count


def detect_genres(lua_code):
    """Detect genres from code keywords."""
    lua_lower = lua_code.lower()
    genre_scores = {}

    for genre, keywords in GENRE_KEYWORDS.items():
        score = 0
        for keyword in keywords:
            # Simple word boundary matching
            pattern = r'\b' + re.escape(keyword) + r'\b'
            matches = len(re.findall(pattern, lua_lower))
            score += matches

        if score > 0:
            genre_scores[genre] = score

    # Sort by score and return top 1-2 genres
    if not genre_scores:
        return ["puzzle"]

    sorted_genres = sorted(genre_scores.items(), key=lambda x: x[1], reverse=True)
    selected = [genre for genre, score in sorted_genres[:2]]

    return selected if selected else ["puzzle"]


def estimate_difficulty(lua_code, token_count, sprite_count, sound_count):
    """Estimate difficulty based on code complexity."""
    difficulty = 2

    # Base difficulty on token count
    if token_count and token_count > 6000:
        difficulty = 4
    elif token_count and token_count > 4000:
        difficulty = 3

    # Adjust for sprite/sound usage (more assets often = more complex game)
    if sprite_count > 30:
        difficulty = min(5, difficulty + 1)
    if sound_count > 15:
        difficulty = min(5, difficulty + 1)

    # Check for advanced features
    if "ai" in lua_code.lower() or "pathfind" in lua_code.lower():
        difficulty = min(5, difficulty + 1)
    if "particle" in lua_code.lower():
        difficulty = min(5, difficulty + 1)

    return max(1, min(5, difficulty))


def generate_description(game_title, lua_code, genres):
    """Generate a game description from code analysis."""
    parts = []

    # Start with a basic template
    parts.append(f"A {', '.join(genres)} PICO-8 game.")

    # Try to infer mechanics
    mechanics = []
    if "player" in lua_code.lower():
        mechanics.append("control a character")
    if "enemy" in lua_code.lower() or "bot" in lua_code.lower():
        mechanics.append("face enemies")
    if "score" in lua_code.lower():
        mechanics.append("earn points")
    if "level" in lua_code.lower():
        mechanics.append("progress through levels")
    if "power" in lua_code.lower():
        mechanics.append("collect power-ups")

    if mechanics:
        parts.append(" ".join(mechanics).capitalize() + ".")

    return " ".join(parts)


def generate_metadata(date_str, game_dir):
    """Generate metadata for a game."""
    game_p8 = os.path.join(game_dir, "game.p8")

    # Extract sections
    lua_code = extract_lua_section(game_p8)
    gfx_content = extract_gfx_section(game_p8)
    sfx_content = extract_sfx_section(game_p8)

    # Count tokens and assets
    token_count = count_token_count(game_p8)
    sprite_count = count_sprites(gfx_content)
    sound_count = count_sounds(sfx_content)

    # Generate basic fields
    title = extract_first_comment(lua_code) or f"Game {date_str}"
    genres = detect_genres(lua_code)
    difficulty = estimate_difficulty(lua_code, token_count, sprite_count, sound_count)
    description = generate_description(title, lua_code, genres)

    metadata = {
        "title": title,
        "description": description,
        "release_date": date_str,
        "genres": genres,
        "theme": "",
        "difficulty": difficulty,
        "playtime_minutes": 5,
        "target_audience": "general",
        "keywords": [],
        "completion_status": "in-progress",
        "tester_notes": "",
        "token_count": token_count or 0,
        "sprite_count": sprite_count,
        "sound_count": sound_count
    }

    return metadata


def validate_metadata(metadata):
    """Validate metadata structure and values."""
    required_fields = {
        "title", "description", "release_date", "genres", "difficulty", "completion_status"
    }

    # Check required fields
    missing = required_fields - set(metadata.keys())
    if missing:
        return False, f"Missing required fields: {', '.join(sorted(missing))}"

    # Validate title
    if not isinstance(metadata.get("title"), str) or not metadata["title"].strip():
        return False, "title must be a non-empty string"

    # Validate description
    if not isinstance(metadata.get("description"), str) or not metadata["description"].strip():
        return False, "description must be a non-empty string"

    # Validate release_date
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', metadata.get("release_date", "")):
        return False, "release_date must be in YYYY-MM-DD format"

    # Validate genres
    genres = metadata.get("genres", [])
    if not isinstance(genres, list) or not genres:
        return False, "genres must be a non-empty list"
    invalid_genres = set(genres) - VALID_GENRES
    if invalid_genres:
        return False, f"Invalid genres: {', '.join(sorted(invalid_genres))}"

    # Validate difficulty
    diff = metadata.get("difficulty")
    if not isinstance(diff, int) or diff < 1 or diff > 5:
        return False, "difficulty must be an integer between 1 and 5"

    # Validate completion_status
    status = metadata.get("completion_status")
    if status not in {"in-progress", "complete", "polished"}:
        return False, f"completion_status must be one of: in-progress, complete, polished"

    return True, None


def save_metadata(metadata, path):
    """Save metadata.json file."""
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(metadata, f, indent=2)
        return True
    except (IOError, OSError) as e:
        print(f"Error saving {path}: {e}", file=sys.stderr)
        return False


def print_summary(suggestions):
    """Print summary of suggested metadata."""
    print(f"\n{'=' * 80}")
    print(f"SUGGESTED METADATA FOR {len(suggestions)} GAMES")
    print(f"{'=' * 80}\n")

    for date, metadata in suggestions:
        print(f"Date: {date}")
        print(f"  Title: {metadata['title']}")
        print(f"  Description: {metadata['description']}")
        print(f"  Genres: {', '.join(metadata['genres'])}")
        print(f"  Difficulty: {metadata['difficulty']}/5")
        print(f"  Tokens: {metadata['token_count']}/8192")
        print(f"  Sprites: {metadata['sprite_count']}")
        print(f"  Sounds: {metadata['sound_count']}")
        print()


def main():
    """Main entry point."""
    auto_apply = "--auto" in sys.argv
    dry_run = "--dry-run" in sys.argv

    games = find_all_games()

    if not games:
        print("No games without metadata found.")
        return 0

    print(f"Found {len(games)} games without metadata. Analyzing...")

    suggestions = []
    valid_count = 0

    for date, game_dir in games:
        print(f"  Analyzing {date}...", end=" ", flush=True)

        try:
            metadata = generate_metadata(date, game_dir)

            # Validate
            is_valid, error = validate_metadata(metadata)
            if not is_valid:
                print(f"⚠️  INVALID: {error}")
                continue

            suggestions.append((date, metadata))
            valid_count += 1
            print("✓")
        except Exception as e:
            print(f"✗ ERROR: {e}")
            continue

    if not suggestions:
        print("\nNo valid metadata could be generated.", file=sys.stderr)
        return 1

    # Print summary
    print_summary(suggestions)

    # If dry-run, stop here
    if dry_run:
        print(f"DRY-RUN: Would create {len(suggestions)} metadata files")
        return 0

    # Ask for confirmation unless --auto
    if not auto_apply:
        response = input(f"Create metadata.json files for {len(suggestions)} games? (yes/no): ").strip().lower()
        if response != "yes":
            print("Cancelled.")
            return 0

    # Create all metadata files
    print("\nCreating metadata.json files...")
    created_count = 0

    for date, metadata in suggestions:
        game_dir = os.path.join("games", date)
        metadata_path = os.path.join(game_dir, "metadata.json")

        if save_metadata(metadata, metadata_path):
            print(f"  ✓ {date}")
            created_count += 1
        else:
            print(f"  ✗ {date}")

    print(f"\n{created_count}/{len(suggestions)} metadata files created.")

    # Try to generate catalog.json
    print("\nGenerating catalog.json...")
    try:
        result = subprocess.run(
            ['python3', 'tools/generate-library.py'],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            print(f"  ✓ {result.stdout.strip()}")
            return 0
        else:
            print(f"  ⚠️  generate-library.py returned {result.returncode}")
            if result.stderr:
                print(f"     {result.stderr.strip()}")
            return 1
    except Exception as e:
        print(f"  ⚠️  Could not run generate-library.py: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
