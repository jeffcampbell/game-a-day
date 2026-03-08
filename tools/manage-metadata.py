#!/usr/bin/env python3
"""Metadata management for PICO-8 games.

Usage:
  python3 tools/manage-metadata.py list
  python3 tools/manage-metadata.py show <date>
  python3 tools/manage-metadata.py edit <date>
  python3 tools/manage-metadata.py init <date>

Manages metadata.json files in each game directory with game info,
difficulty, genres, token counts, and tester notes.
"""

import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime

# Valid values
VALID_GENRES = {
    "puzzle", "action", "adventure", "strategy", "rhythm", "rpg", "sports", "educational"
}

VALID_AUDIENCES = {
    "general", "children", "teens", "adults", "expert"
}


def validate_metadata(metadata):
    """Validate metadata structure and values. Returns (is_valid, error_message)."""
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

    # Validate release_date format
    date_str = metadata.get("release_date", "")
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
        return False, "release_date must be in YYYY-MM-DD format"

    # Validate genres
    genres = metadata.get("genres", [])
    if not isinstance(genres, list):
        return False, "genres must be a list"
    if not genres:
        return False, "genres list cannot be empty"
    invalid_genres = set(genres) - VALID_GENRES
    if invalid_genres:
        return False, f"Invalid genres: {', '.join(sorted(invalid_genres))}. Valid: {', '.join(sorted(VALID_GENRES))}"

    # Validate theme (optional)
    if "theme" in metadata and not isinstance(metadata["theme"], str):
        return False, "theme must be a string"

    # Validate difficulty
    difficulty = metadata.get("difficulty")
    if not isinstance(difficulty, int) or difficulty < 1 or difficulty > 5:
        return False, "difficulty must be an integer between 1 and 5"

    # Validate playtime_minutes (optional)
    if "playtime_minutes" in metadata:
        pt = metadata["playtime_minutes"]
        if not isinstance(pt, int) or pt < 1:
            return False, "playtime_minutes must be a positive integer"

    # Validate target_audience (optional)
    if "target_audience" in metadata:
        aud = metadata["target_audience"]
        if aud not in VALID_AUDIENCES:
            return False, f"target_audience must be one of: {', '.join(sorted(VALID_AUDIENCES))}"

    # Validate keywords (optional)
    if "keywords" in metadata:
        kw = metadata["keywords"]
        if not isinstance(kw, list):
            return False, "keywords must be a list"
        if not all(isinstance(k, str) for k in kw):
            return False, "all keywords must be strings"

    # Validate completion_status
    valid_statuses = {"in-progress", "complete", "polished"}
    status = metadata.get("completion_status")
    if status not in valid_statuses:
        return False, f"completion_status must be one of: {', '.join(sorted(valid_statuses))}"

    # Validate tester_notes (optional)
    if "tester_notes" in metadata and not isinstance(metadata["tester_notes"], str):
        return False, "tester_notes must be a string"

    # Validate token_count (optional)
    if "token_count" in metadata:
        tc = metadata["token_count"]
        if not isinstance(tc, int) or tc < 0:
            return False, "token_count must be a non-negative integer"

    # Validate sprite_count (optional)
    if "sprite_count" in metadata:
        sc = metadata["sprite_count"]
        if not isinstance(sc, int) or sc < 0:
            return False, "sprite_count must be a non-negative integer"

    # Validate sound_count (optional)
    if "sound_count" in metadata:
        snd = metadata["sound_count"]
        if not isinstance(snd, int) or snd < 0:
            return False, "sound_count must be a non-negative integer"

    return True, None


def find_all_games():
    """Find all game directories (YYYY-MM-DD)."""
    games = []
    games_dir = "games"

    if not os.path.isdir(games_dir):
        return games

    for entry in sorted(os.listdir(games_dir)):
        if re.match(r'^\d{4}-\d{2}-\d{2}$', entry):
            game_path = os.path.join(games_dir, entry)
            if os.path.isdir(game_path):
                games.append((entry, game_path))

    return games


def load_metadata(date_str):
    """Load metadata.json for a specific game. Returns (metadata, path, exists)."""
    game_dir = os.path.join("games", date_str)
    metadata_path = os.path.join(game_dir, "metadata.json")

    if os.path.exists(metadata_path):
        try:
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
            return metadata, metadata_path, True
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading {metadata_path}: {e}", file=sys.stderr)
            return None, metadata_path, True

    return None, metadata_path, False


def save_metadata(metadata, path):
    """Save metadata.json file."""
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(metadata, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving {path}: {e}", file=sys.stderr)
        return False


def extract_metrics_from_p8(game_dir):
    """Extract token count, sprite count, and sound count from game.p8."""
    game_p8 = os.path.join(game_dir, "game.p8")

    if not os.path.exists(game_p8):
        return None, None, None

    try:
        with open(game_p8, 'r') as f:
            content = f.read()
    except IOError:
        return None, None, None

    # Count tokens (use p8tokens if available)
    token_count = None
    try:
        import subprocess
        result = subprocess.run(
            ['python3', 'tools/p8tokens.py', game_p8],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 or result.returncode == 1:  # 0 = pass, 1 = over limit
            match = re.search(r'TOKENS:\s*(\d+)', result.stdout)
            if match:
                token_count = int(match.group(1))
    except (FileNotFoundError, subprocess.TimeoutExpired, Exception):
        pass

    # Count non-zero sprites in __gfx__ section
    sprite_count = 0
    in_gfx = False
    gfx_lines = 0

    for line in content.split('\n'):
        if line.startswith('__gfx__'):
            in_gfx = True
            continue
        if in_gfx and line.startswith('__'):
            break
        if in_gfx and line.strip():
            gfx_lines += 1
            # Check if line has any non-zero characters (i.e., sprite data)
            if any(c != '0' for c in line):
                sprite_count += 1

    # Count non-empty lines in __sfx__ section
    sound_count = 0
    in_sfx = False

    for line in content.split('\n'):
        if line.startswith('__sfx__'):
            in_sfx = True
            continue
        if in_sfx and line.startswith('__'):
            break
        if in_sfx and line.strip() and not line.startswith(';'):
            sound_count += 1

    return token_count, sprite_count, sound_count


def generate_default_metadata(date_str, game_dir):
    """Generate default metadata for a new game."""
    token_count, sprite_count, sound_count = extract_metrics_from_p8(game_dir)

    metadata = {
        "title": "Untitled Game",
        "description": "A PICO-8 game",
        "release_date": date_str,
        "genres": ["puzzle"],
        "theme": "",
        "difficulty": 3,
        "playtime_minutes": 5,
        "target_audience": "general",
        "keywords": [],
        "completion_status": "in-progress",
        "tester_notes": "",
        "token_count": token_count or 0,
        "sprite_count": sprite_count or 0,
        "sound_count": sound_count or 0
    }

    return metadata


def list_games():
    """List all games with their metadata."""
    games = find_all_games()

    if not games:
        print("No games found.")
        return 0

    print(f"Found {len(games)} games:\n")

    for date, game_dir in games:
        metadata, _, exists = load_metadata(date)

        if exists and metadata:
            title = metadata.get("title", "Untitled")
            genres = ", ".join(metadata.get("genres", []))
            difficulty = metadata.get("difficulty", "?")
            status = metadata.get("completion_status", "?")
            print(f"  {date} | {title}")
            print(f"           Status: {status} | Difficulty: {difficulty}/5 | Genres: {genres}")
        else:
            print(f"  {date} | (no metadata)")

    return 0


def show_game(date_str):
    """Display metadata for a specific game."""
    metadata, _, exists = load_metadata(date_str)

    if not exists:
        print(f"No metadata found for game {date_str}", file=sys.stderr)
        return 1

    if not metadata:
        print(f"Error loading metadata for game {date_str}", file=sys.stderr)
        return 1

    # Pretty-print metadata
    print(json.dumps(metadata, indent=2))
    return 0


def init_game(date_str):
    """Initialize metadata for a game."""
    # Validate date format
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
        print(f"Error: Invalid date format '{date_str}'. Use YYYY-MM-DD.", file=sys.stderr)
        return 1

    game_dir = os.path.join("games", date_str)

    if not os.path.isdir(game_dir):
        print(f"Error: Game directory {game_dir} not found", file=sys.stderr)
        return 1

    if not os.path.exists(os.path.join(game_dir, "game.p8")):
        print(f"Error: {game_dir}/game.p8 not found", file=sys.stderr)
        return 1

    metadata, metadata_path, exists = load_metadata(date_str)

    if exists:
        print(f"Metadata already exists at {metadata_path}")
        return 0

    # Generate default metadata
    metadata = generate_default_metadata(date_str, game_dir)

    # Validate
    is_valid, error = validate_metadata(metadata)
    if not is_valid:
        print(f"Error: Generated metadata is invalid: {error}", file=sys.stderr)
        return 1

    # Save
    if save_metadata(metadata, metadata_path):
        print(f"✓ Created {metadata_path}")
        return 0
    else:
        return 1


def edit_game(date_str):
    """Interactive editor for game metadata."""
    # Validate date format
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
        print(f"Error: Invalid date format '{date_str}'. Use YYYY-MM-DD.", file=sys.stderr)
        return 1

    game_dir = os.path.join("games", date_str)

    if not os.path.isdir(game_dir):
        print(f"Error: Game directory {game_dir} not found", file=sys.stderr)
        return 1

    metadata, metadata_path, exists = load_metadata(date_str)

    # If metadata doesn't exist, create default
    if not exists:
        metadata = generate_default_metadata(date_str, game_dir)

    if not metadata:
        print(f"Error loading metadata for game {date_str}", file=sys.stderr)
        return 1

    print(f"\nEditing metadata for {date_str}\n")

    # Edit title
    title = input(f"Title [{metadata['title']}]: ").strip()
    if title:
        metadata['title'] = title

    # Edit description
    print("Description (current: {})".format(metadata['description'][:50]))
    desc = input("New description: ").strip()
    if desc:
        metadata['description'] = desc

    # Edit genres
    print(f"Current genres: {', '.join(metadata['genres'])}")
    print(f"Available: {', '.join(sorted(VALID_GENRES))}")
    genres_input = input("Genres (comma-separated): ").strip()
    if genres_input:
        genres = [g.strip() for g in genres_input.split(',')]
        invalid = set(genres) - VALID_GENRES
        if invalid:
            print(f"Invalid genres: {', '.join(invalid)}", file=sys.stderr)
            return 1
        metadata['genres'] = genres

    # Edit theme
    theme = input(f"Theme [{metadata.get('theme', '')}]: ").strip()
    if theme is not None:
        metadata['theme'] = theme

    # Edit difficulty
    while True:
        diff_input = input(f"Difficulty (1-5) [{metadata['difficulty']}]: ").strip()
        if not diff_input:
            break
        try:
            diff = int(diff_input)
            if 1 <= diff <= 5:
                metadata['difficulty'] = diff
                break
            else:
                print("Difficulty must be between 1 and 5", file=sys.stderr)
        except ValueError:
            print("Invalid integer", file=sys.stderr)

    # Edit playtime
    while True:
        pt_input = input(f"Playtime (minutes) [{metadata.get('playtime_minutes', 5)}]: ").strip()
        if not pt_input:
            break
        try:
            pt = int(pt_input)
            if pt > 0:
                metadata['playtime_minutes'] = pt
                break
            else:
                print("Playtime must be positive", file=sys.stderr)
        except ValueError:
            print("Invalid integer", file=sys.stderr)

    # Edit target audience
    target_aud = input(f"Target audience [{metadata.get('target_audience', 'general')}]: ").strip()
    if target_aud:
        if target_aud in VALID_AUDIENCES:
            metadata['target_audience'] = target_aud
        else:
            print(f"Invalid audience. Valid: {', '.join(sorted(VALID_AUDIENCES))}", file=sys.stderr)
            return 1

    # Edit keywords
    keywords_input = input(f"Keywords (comma-separated) [{', '.join(metadata.get('keywords', []))}]: ").strip()
    if keywords_input:
        metadata['keywords'] = [k.strip() for k in keywords_input.split(',')]

    # Edit completion status
    status = input(f"Status [{metadata['completion_status']}] (in-progress/complete/polished): ").strip()
    if status:
        if status in {"in-progress", "complete", "polished"}:
            metadata['completion_status'] = status
        else:
            print("Invalid status", file=sys.stderr)
            return 1

    # Edit tester notes
    notes = input(f"Tester notes [{metadata.get('tester_notes', '')}]: ").strip()
    if notes is not None:
        metadata['tester_notes'] = notes

    # Auto-extract metrics
    token_count, sprite_count, sound_count = extract_metrics_from_p8(game_dir)
    if token_count is not None:
        metadata['token_count'] = token_count
    if sprite_count is not None:
        metadata['sprite_count'] = sprite_count
    if sound_count is not None:
        metadata['sound_count'] = sound_count

    # Validate
    is_valid, error = validate_metadata(metadata)
    if not is_valid:
        print(f"Error: Metadata is invalid: {error}", file=sys.stderr)
        return 1

    # Save
    if save_metadata(metadata, metadata_path):
        print(f"\n✓ Saved {metadata_path}")
        return 0
    else:
        return 1


def generate_catalog():
    """Generate catalog.json with all game metadata."""
    games = find_all_games()
    catalog = {
        "generated": datetime.now().isoformat(),
        "game_count": 0,
        "games": []
    }

    for date, game_dir in games:
        metadata, _, exists = load_metadata(date)

        if exists and metadata:
            # Validate metadata before including
            is_valid, _ = validate_metadata(metadata)
            if is_valid:
                catalog["games"].append(metadata)
                catalog["game_count"] += 1

    # Sort by date descending
    catalog["games"].sort(key=lambda g: g.get("release_date", ""), reverse=True)

    # Write catalog
    try:
        catalog_path = os.path.join("games", "catalog.json")
        with open(catalog_path, 'w') as f:
            json.dump(catalog, f, indent=2)
        print(f"✓ Generated {catalog_path} ({catalog['game_count']} games)")
        return 0
    except IOError as e:
        print(f"Error writing catalog: {e}", file=sys.stderr)
        return 1


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage:", file=sys.stderr)
        print("  python3 tools/manage-metadata.py list", file=sys.stderr)
        print("  python3 tools/manage-metadata.py show <date>", file=sys.stderr)
        print("  python3 tools/manage-metadata.py edit <date>", file=sys.stderr)
        print("  python3 tools/manage-metadata.py init <date>", file=sys.stderr)
        print("  python3 tools/manage-metadata.py catalog", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    if command == "list":
        return list_games()
    elif command == "show":
        if len(sys.argv) < 3:
            print("Error: 'show' requires a date argument", file=sys.stderr)
            return 1
        return show_game(sys.argv[2])
    elif command == "edit":
        if len(sys.argv) < 3:
            print("Error: 'edit' requires a date argument", file=sys.stderr)
            return 1
        return edit_game(sys.argv[2])
    elif command == "init":
        if len(sys.argv) < 3:
            print("Error: 'init' requires a date argument", file=sys.stderr)
            return 1
        return init_game(sys.argv[2])
    elif command == "catalog":
        return generate_catalog()
    else:
        print(f"Error: Unknown command '{command}'", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
