#!/usr/bin/env python3
"""Skeleton game enhancer - Intelligently enhance skeleton games with concept-driven guidance.

Analyzes skeleton games (minimal code, no gameplay) and provides enhancement roadmaps
based on similar successful games in the same genre.

Problem:
Skeleton games have no session data and completion rates. They need CONCEPT-DRIVEN
guidance based on game intent (genre, theme) and reference similar games.

Solution:
1. Detects skeleton games (token_count < 50, no sessions)
2. Analyzes game metadata (genre, target audience, theme)
3. Finds similar successful games that match the genre
4. Extracts winning mechanics and formulas from similar games
5. Generates prioritized enhancement roadmap with code templates
6. Provides complexity and playtime estimates

Usage:
  python3 tools/skeleton-game-enhancer.py              # All skeleton games
  python3 tools/skeleton-game-enhancer.py 2026-03-08   # Single game
  python3 tools/skeleton-game-enhancer.py --template   # Show genre templates
  python3 tools/skeleton-game-enhancer.py --compare    # Show similar games comparison

Generates:
  - games/<date>/skeleton-enhancement-plan.json for each skeleton
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter


# Code templates for common game mechanics
CODE_TEMPLATES = {
    "player_movement": {
        "description": "Basic player movement with arrow keys",
        "complexity": "low",
        "estimated_tokens": 50,
        "code": """-- player movement
player = {x=64, y=100, w=4, h=4, speed=2}

function update_player_input()
  if btn(0) then player.x -= player.speed  -- left
  if btn(1) then player.x += player.speed  -- right
  if btn(2) then player.y -= player.speed  -- up
  if btn(3) then player.y += player.speed  -- down

  -- clamp to screen
  player.x = max(0, min(128-player.w, player.x))
  player.y = max(0, min(128-player.h, player.y))
end

function draw_player()
  rect(player.x, player.y, player.x+player.w, player.y+player.h, 7)
end""",
    },

    "simple_collision": {
        "description": "Basic rectangular collision detection",
        "complexity": "low",
        "estimated_tokens": 40,
        "code": """-- simple collision detection
function check_collision(a, b)
  -- check if rectangles overlap
  return a.x < b.x+b.w and
         a.x+a.w > b.x and
         a.y < b.y+b.h and
         a.y+a.h > b.y
end""",
    },

    "enemy_spawning": {
        "description": "Spawn enemies at regular intervals",
        "complexity": "medium",
        "estimated_tokens": 80,
        "code": """-- enemy spawning system
enemies = {}
spawn_timer = 0
spawn_interval = 60  -- frames between spawns

function spawn_enemy()
  local enemy = {
    x = rnd(128),
    y = -8,
    w = 4,
    h = 4,
    speed = 1
  }
  add(enemies, enemy)
end

function update_enemies()
  spawn_timer += 1
  if spawn_timer >= spawn_interval then
    spawn_enemy()
    spawn_timer = 0
  end

  -- move enemies
  for enemy in all(enemies) do
    enemy.y += enemy.speed
    -- remove if off screen
    if enemy.y > 128 then
      del(enemies, enemy)
    end
  end
end

function draw_enemies()
  for enemy in all(enemies) do
    rect(enemy.x, enemy.y, enemy.x+enemy.w, enemy.y+enemy.h, 8)
  end
end""",
    },

    "score_system": {
        "description": "Basic score tracking and display",
        "complexity": "low",
        "estimated_tokens": 30,
        "code": """-- score system
score = 0

function add_score(points)
  score += points
  _log("score:"..score)
end

function draw_score()
  print("score:"..score, 2, 2, 7)
end""",
    },

    "simple_health": {
        "description": "Player health/lives system",
        "complexity": "low",
        "estimated_tokens": 40,
        "code": """-- health/lives system
player.health = 3
player.max_health = 3

function damage_player(amount)
  player.health -= amount
  if player.health <= 0 then
    _log("gameover:lose")
    state = "gameover"
  end
  _log("health:"..player.health)
end

function heal_player(amount)
  player.health = min(player.max_health, player.health + amount)
end

function draw_health()
  print("hp:"..player.health.."/"..player.max_health, 2, 10, 7)
end""",
    },

    "wave_system": {
        "description": "Progressive waves with increasing difficulty",
        "complexity": "medium",
        "estimated_tokens": 70,
        "code": """-- wave/level system
wave = 1
enemies_killed = 0
enemies_per_wave = 5

function check_wave_complete()
  if #enemies == 0 and enemies_killed >= enemies_per_wave then
    wave_complete()
  end
end

function wave_complete()
  wave += 1
  enemies_killed = 0
  enemies_per_wave = 5 + wave  -- harder each wave
  _log("wave:"..wave)
end

function draw_wave()
  print("wave:"..wave, 100, 2, 7)
end""",
    },

    "pause_menu": {
        "description": "Pause/menu state management",
        "complexity": "low",
        "estimated_tokens": 60,
        "code": """-- pause menu
function update_play()
  if btnp(4) then  -- X button pauses
    state = "pause"
    _log("state:pause")
  end
  -- normal gameplay update
end

function update_pause()
  if btnp(4) then  -- X unpauses
    state = "play"
    _log("state:play")
  end
end

function draw_pause()
  draw_play()  -- draw game underneath
  rectfill(30, 50, 98, 78, 0)
  print("paused", 50, 60, 7)
  print("x to continue", 35, 68, 7)
end""",
    },

    "projectile_system": {
        "description": "Simple projectile/bullet system",
        "complexity": "medium",
        "estimated_tokens": 100,
        "code": """-- projectile system
projectiles = {}

function shoot_projectile(x, y, vx, vy)
  local proj = {
    x = x,
    y = y,
    vx = vx,
    vy = vy,
    w = 2,
    h = 2
  }
  add(projectiles, proj)
  _log("shoot")
end

function update_projectiles()
  for proj in all(projectiles) do
    proj.x += proj.vx
    proj.y += proj.vy

    -- check collisions with enemies
    for enemy in all(enemies) do
      if check_collision(proj, enemy) then
        del(enemies, enemy)
        del(projectiles, proj)
        add_score(10)
        break
      end
    end

    -- remove if off screen
    if proj.x < 0 or proj.x > 128 or
       proj.y < 0 or proj.y > 128 then
      del(projectiles, proj)
    end
  end
end

function draw_projectiles()
  for proj in all(projectiles) do
    rect(proj.x, proj.y, proj.x+proj.w, proj.y+proj.h, 11)
  end
end""",
    },

    "screen_flash": {
        "description": "Hit/damage feedback with screen flash",
        "complexity": "low",
        "estimated_tokens": 30,
        "code": """-- screen flash effect
flash_timer = 0
flash_duration = 10

function trigger_flash(duration)
  flash_timer = duration or flash_duration
end

function update_flash()
  if flash_timer > 0 then
    flash_timer -= 1
  end
end

function draw_flash()
  if flash_timer > 0 then
    rectfill(0, 0, 128, 128, 7)
  end
end""",
    },
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


def is_skeleton_game(game):
    """Check if a game is a skeleton (minimal implementation).

    Skeleton criteria:
    - token_count < 50 (essentially empty)
    - sprite_count < 2
    - sound_count < 2
    - sessions_recorded == 0
    """
    token_count = game.get('token_count', 0)
    sprite_count = game.get('sprite_count', 0)
    sound_count = game.get('sound_count', 0)
    sessions = game.get('sessions_recorded', 0)

    return (token_count < 50 and
            sprite_count < 2 and
            sound_count < 2 and
            sessions == 0)


def find_skeleton_games(catalog):
    """Find all skeleton games in catalog.

    Returns list of (date, game_dict) tuples.
    """
    if not catalog or 'games' not in catalog:
        return []

    skeletons = []
    for game in catalog.get('games', []):
        if is_skeleton_game(game):
            date = game.get('date')
            if date:
                skeletons.append((date, game))

    return skeletons


def find_similar_games(game, catalog, limit=5):
    """Find successful games similar to the skeleton game.

    Similarity is based on:
    - Matching genres
    - Similar difficulty level
    - Good engagement or completion metrics

    Returns list of (date, game_dict, similarity_score) tuples.
    """
    if not catalog or 'games' not in catalog:
        return []

    skeleton_genres = set(game.get('genres', []))
    skeleton_target = game.get('target_audience', 'general')
    skeleton_difficulty = game.get('difficulty', 3)

    candidates = []

    for other_game in catalog.get('games', []):
        # Skip the skeleton itself
        if other_game.get('date') == game.get('date'):
            continue

        # Skip other skeletons
        if is_skeleton_game(other_game):
            continue

        # Only look at games with meaningful content
        if other_game.get('token_count', 0) < 100:
            continue

        # Calculate similarity score
        score = 0

        # Genre matching (most important)
        other_genres = set(other_game.get('genres', []))
        genre_overlap = len(skeleton_genres & other_genres)
        if genre_overlap > 0:
            score += genre_overlap * 30

        # Target audience matching
        if other_game.get('target_audience') == skeleton_target:
            score += 10

        # Difficulty similarity (within 1 level)
        diff = abs(other_game.get('difficulty', 3) - skeleton_difficulty)
        if diff <= 1:
            score += 15

        # Engagement metrics
        engagement = other_game.get('engagement_score', 0)
        quality = other_game.get('game_quality_score', 0)
        if engagement > 0.2:
            score += 10
        if quality > 0.2:
            score += 5

        if score > 0:
            candidates.append((other_game.get('date'), other_game, score))

    # Sort by similarity score descending
    candidates.sort(key=lambda x: x[2], reverse=True)

    return candidates[:limit]


def extract_mechanics_from_code(game_p8_path):
    """Extract mechanics used in a game's code.

    Returns list of detected mechanics.
    """
    if not os.path.exists(game_p8_path):
        return []

    mechanics_patterns = {
        'jump': r'\bjump\b|player\.y\s*[+-]=',
        'enemy_spawning': r'spawn|enemy|add\(',
        'collision': r'collision|check_collision|overlap',
        'scoring': r'score|points|add_score',
        'health': r'health|hp|damage|lives',
        'waves': r'wave|level|round|stage',
        'projectiles': r'projectile|bullet|shoot|fire',
        'animation': r'frame|anim|sprite_animation',
        'sound': r'sfx\(|music\(',
        'particles': r'particle|effect|splash',
    }

    try:
        with open(game_p8_path, 'r') as f:
            code = f.read()
            # Extract lua section only
            match = re.search(r'__lua__\n(.*?)(?=\n__[a-z]+__|$)', code, re.DOTALL)
            if match:
                code = match.group(1)
    except IOError:
        return []

    detected = []
    for mechanic, pattern in mechanics_patterns.items():
        if re.search(pattern, code, re.IGNORECASE):
            detected.append(mechanic)

    return detected


def analyze_similar_games(similar_games, catalog_dir='games'):
    """Analyze mechanics and patterns from similar games.

    Returns dict with extracted patterns and mechanics.
    """
    all_mechanics = Counter()
    avg_playtime = 0
    avg_difficulty = 0
    count = 0

    for date, game, score in similar_games:
        game_dir = os.path.join(catalog_dir, date)
        game_p8 = os.path.join(game_dir, 'game.p8')

        mechanics = extract_mechanics_from_code(game_p8)
        for mechanic in mechanics:
            all_mechanics[mechanic] += 1

        playtime = game.get('playtime_minutes', 5)
        difficulty = game.get('difficulty', 3)

        avg_playtime += playtime
        avg_difficulty += difficulty
        count += 1

    if count > 0:
        avg_playtime /= count
        avg_difficulty /= count

    return {
        'detected_mechanics': dict(all_mechanics),
        'most_common_mechanics': [m[0] for m in all_mechanics.most_common(5)],
        'average_playtime': round(avg_playtime, 1),
        'average_difficulty': round(avg_difficulty, 1),
        'game_count': count,
    }


def generate_enhancement_roadmap(skeleton_game, similar_games, patterns):
    """Generate prioritized feature roadmap for skeleton game.

    Returns list of enhancement recommendations with templates.
    """
    recommendations = []
    priority = 1

    # Core gameplay foundation - ALWAYS first
    recommendations.append({
        'id': priority,
        'title': 'Implement Core Game Loop',
        'description': 'Set up state machine (menu -> play -> gameover) and basic game state management.',
        'category': 'foundation',
        'complexity': 'low',
        'estimated_tokens': 100,
        'estimated_playtime_gain': 2,
        'priority': str(priority),
        'implementation_steps': [
            'Create state variable (state = "menu")',
            'Implement _update() state dispatcher',
            'Implement _draw() state renderer',
            'Add logging for state transitions',
            'Test menu and gamestate flow',
        ],
        'rationale': 'All games need a state machine. This is the foundation for everything else.',
    })
    priority += 1

    # Player entity based on detected mechanics
    if 'jump' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Implement Player Movement (Jump)',
            'description': 'Add player entity with jump mechanics, as seen in similar games.',
            'category': 'core_mechanic',
            'complexity': 'low',
            'estimated_tokens': 80,
            'estimated_playtime_gain': 0.5,
            'priority': str(priority),
            'template': 'player_movement',
            'implementation_steps': [
                'Create player table with x, y, velocity',
                'Implement jump on Z/C button press',
                'Add gravity and collision with ground',
                'Test jump mechanics feel responsive',
            ],
            'rationale': f"Jump mechanics found in {patterns['detected_mechanics'].get('jump', 0)} similar games.",
        })
        priority += 1

    # Enemies/obstacles
    if 'enemy_spawning' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Add Enemy Spawning System',
            'description': 'Create enemies that spawn periodically and move toward player.',
            'category': 'core_mechanic',
            'complexity': 'medium',
            'estimated_tokens': 120,
            'estimated_playtime_gain': 1.0,
            'priority': str(priority),
            'template': 'enemy_spawning',
            'implementation_steps': [
                'Create enemies table',
                'Implement spawn timer and spawn_enemy() function',
                'Add enemy movement logic',
                'Remove enemies when off-screen',
                'Test spawn frequency feels balanced',
            ],
            'rationale': f"Enemy systems found in {patterns['detected_mechanics'].get('enemy_spawning', 0)} similar games.",
        })
        priority += 1

    # Collision detection
    recommendations.append({
        'id': priority,
        'title': 'Implement Collision Detection',
        'description': 'Add basic rectangular collision for player-enemy and player-items.',
        'category': 'core_mechanic',
        'complexity': 'low',
        'estimated_tokens': 40,
        'estimated_playtime_gain': 0,
        'priority': str(priority),
        'template': 'simple_collision',
        'implementation_steps': [
            'Create check_collision() function',
            'Test collisions in update loops',
            'Handle game-over on collision',
        ],
        'rationale': 'Essential for any game with multiple moving entities.',
    })
    priority += 1

    # Scoring system
    if 'scoring' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Add Scoring System',
            'description': 'Track and display player score with points for achievements.',
            'category': 'engagement',
            'complexity': 'low',
            'estimated_tokens': 50,
            'estimated_playtime_gain': 0.3,
            'priority': str(priority),
            'template': 'score_system',
            'implementation_steps': [
                'Create score variable',
                'Add add_score() function with logging',
                'Display score in draw_play()',
                'Award points for kills/achievements',
            ],
            'rationale': f"Scoring systems found in {patterns['detected_mechanics'].get('scoring', 0)} similar games.",
        })
        priority += 1

    # Health system
    if 'health' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Implement Player Health/Lives',
            'description': 'Add health system so player survives multiple hits.',
            'category': 'gameplay',
            'complexity': 'low',
            'estimated_tokens': 60,
            'estimated_playtime_gain': 0.5,
            'priority': str(priority),
            'template': 'simple_health',
            'implementation_steps': [
                'Add health to player table',
                'Create damage_player() function',
                'Display health on screen',
                'Trigger game-over when health reaches 0',
            ],
            'rationale': f"Health systems found in {patterns['detected_mechanics'].get('health', 0)} similar games.",
        })
        priority += 1

    # Projectiles/shooting
    if 'projectiles' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Add Projectile/Shooting System',
            'description': 'Let player shoot projectiles at enemies.',
            'category': 'core_mechanic',
            'complexity': 'medium',
            'estimated_tokens': 100,
            'estimated_playtime_gain': 0.5,
            'priority': str(priority),
            'template': 'projectile_system',
            'implementation_steps': [
                'Create projectiles table',
                'Implement shoot on X/V button',
                'Add projectile collision with enemies',
                'Add score reward for kills',
            ],
            'rationale': f"Projectile systems found in {patterns['detected_mechanics'].get('projectiles', 0)} similar games.",
        })
        priority += 1

    # Progressive difficulty (waves)
    if 'waves' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Add Progressive Waves/Levels',
            'description': 'Increase difficulty in stages to extend engagement.',
            'category': 'progression',
            'complexity': 'medium',
            'estimated_tokens': 80,
            'estimated_playtime_gain': 1.0,
            'priority': str(priority),
            'template': 'wave_system',
            'implementation_steps': [
                'Create wave counter',
                'Increase spawn rate each wave',
                'Increase enemy difficulty each wave',
                'Display current wave to player',
            ],
            'rationale': f"Wave systems found in {patterns['detected_mechanics'].get('waves', 0)} similar games.",
        })
        priority += 1

    # Visual/audio feedback
    if 'sound' in patterns.get('most_common_mechanics', []):
        recommendations.append({
            'id': priority,
            'title': 'Add Sound Effects and Music',
            'description': 'Improve feedback with audio cues and background music.',
            'category': 'polish',
            'complexity': 'medium',
            'estimated_tokens': 50,
            'estimated_playtime_gain': 0.2,
            'priority': str(priority),
            'implementation_steps': [
                'Add SFX patterns in __sfx__ section',
                'Play sfx() on key events (hit, score, death)',
                'Add background music pattern',
                'Loop music during gameplay',
            ],
            'rationale': 'Audio significantly improves engagement and feel.',
        })
        priority += 1

    # Polish features
    recommendations.append({
        'id': priority,
        'title': 'Polish: Screen Effects and Feedback',
        'description': 'Add hit feedback, screen flash, and visual polish.',
        'category': 'polish',
        'complexity': 'low',
        'estimated_tokens': 40,
        'estimated_playtime_gain': 0.2,
        'priority': str(priority),
        'template': 'screen_flash',
        'implementation_steps': [
            'Add flash effect on damage',
            'Add sprite animations for idle/hit',
            'Add particle effects for collisions',
        ],
        'rationale': 'Small visual touches make games feel responsive and juicy.',
    })
    priority += 1

    return recommendations


def save_enhancement_plan(game_dir, plan_data):
    """Save enhancement plan to skeleton-enhancement-plan.json.

    Returns True on success, False on error.
    """
    if not plan_data:
        return False

    plan_path = os.path.join(game_dir, 'skeleton-enhancement-plan.json')
    try:
        os.makedirs(game_dir, exist_ok=True)
        with open(plan_path, 'w') as f:
            json.dump(plan_data, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving enhancement plan for {game_dir}: {e}", file=sys.stderr)
        return False


def generate_enhancement_plan(skeleton_game, similar_games, catalog_dir='games'):
    """Generate complete enhancement plan for a skeleton game.

    Returns dict with plan data.
    """
    game_date = skeleton_game.get('date', 'unknown')
    title = skeleton_game.get('title', 'Untitled Game')
    genres = skeleton_game.get('genres', [])

    # Analyze similar games
    patterns = analyze_similar_games(similar_games, catalog_dir)

    # Generate roadmap
    roadmap = generate_enhancement_roadmap(skeleton_game, similar_games, patterns)

    # Build plan
    plan = {
        'game_date': game_date,
        'title': title,
        'generated_at': datetime.now().isoformat(),
        'game_metadata': {
            'genres': genres,
            'difficulty': skeleton_game.get('difficulty', 3),
            'target_audience': skeleton_game.get('target_audience', 'general'),
            'playtime_target': skeleton_game.get('playtime_minutes', 5),
            'description': skeleton_game.get('description', ''),
        },
        'similar_games': [
            {
                'date': g[0],
                'title': g[1].get('title', 'Unknown'),
                'genres': g[1].get('genres', []),
                'difficulty': g[1].get('difficulty', 0),
                'token_count': g[1].get('token_count', 0),
                'engagement_score': g[1].get('engagement_score', 0),
                'quality_score': g[1].get('game_quality_score', 0),
                'similarity_score': g[2],
            }
            for g in similar_games
        ],
        'reference_patterns': patterns,
        'enhancement_roadmap': roadmap,
        'code_templates': {
            name: {
                'description': template['description'],
                'complexity': template['complexity'],
                'estimated_tokens': template['estimated_tokens'],
                'code': template['code'],
            }
            for name, template in CODE_TEMPLATES.items()
        },
        'summary': generate_summary_text(skeleton_game, roadmap, patterns),
    }

    return plan


def generate_summary_text(skeleton_game, roadmap, patterns):
    """Generate human-readable summary of enhancement plan."""
    lines = []

    genres = skeleton_game.get('genres', [])
    if genres:
        lines.append(f"Genre(s): {', '.join(genres)}")

    if patterns.get('game_count', 0) > 0:
        lines.append(f"Reference games found: {patterns['game_count']}")

    if patterns.get('most_common_mechanics'):
        lines.append(f"Common mechanics in similar games: {', '.join(patterns['most_common_mechanics'][:3])}")

    lines.append(f"Enhancement roadmap: {len(roadmap)} prioritized features")

    if roadmap:
        lines.append(f"Start with: {roadmap[0]['title']}")
        total_tokens = sum(r.get('estimated_tokens', 0) for r in roadmap)
        lines.append(f"Total estimated tokens: ~{total_tokens} (limit is 8192)")

    return '\n'.join(lines)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Generate enhancement plans for skeleton games'
    )
    parser.add_argument(
        'date',
        nargs='?',
        help='Specific game date to analyze (YYYY-MM-DD), or omit for all skeletons'
    )
    parser.add_argument(
        '--template',
        action='store_true',
        help='Show available code templates and exit'
    )
    parser.add_argument(
        '--compare',
        action='store_true',
        help='Show comparison with similar games'
    )

    args = parser.parse_args()

    # Show templates if requested
    if args.template:
        print("Available Code Templates")
        print("=" * 50)
        for name, template in CODE_TEMPLATES.items():
            print(f"\n{name}")
            print(f"  Complexity: {template['complexity']}")
            print(f"  Tokens: ~{template['estimated_tokens']}")
            print(f"  {template['description']}")
        return 0

    # Load catalog
    catalog = load_catalog()
    if not catalog:
        print("Cannot proceed without catalog.json", file=sys.stderr)
        return 1

    # Find skeleton games
    all_skeletons = find_skeleton_games(catalog)
    if not all_skeletons:
        print("No skeleton games found", file=sys.stderr)
        return 1

    # Filter by date if specified
    if args.date:
        skeletons = [(d, g) for d, g in all_skeletons if d == args.date]
        if not skeletons:
            print(f"Skeleton game not found: {args.date}", file=sys.stderr)
            return 1
    else:
        skeletons = all_skeletons

    print(f"Analyzing {len(skeletons)} skeleton game(s)...", flush=True)
    print()

    processed_count = 0

    for game_date, skeleton_game in skeletons:
        # Find similar games
        similar = find_similar_games(skeleton_game, catalog)

        if not similar:
            print(f"{game_date}: No similar games found, skipping", flush=True)
            continue

        # Generate plan
        plan = generate_enhancement_plan(skeleton_game, similar)

        # Save plan
        game_dir = os.path.join('games', game_date)
        if save_enhancement_plan(game_dir, plan):
            processed_count += 1

            title = skeleton_game.get('title', 'Untitled')
            similar_count = len(similar)
            features = len(plan.get('enhancement_roadmap', []))

            print(f"{game_date}: {similar_count} reference games, {features} features", flush=True)

            if args.compare:
                # Show detailed comparison
                print(f"  Reference games:")
                for similar_game in plan['similar_games'][:3]:
                    print(f"    - {similar_game['date']}: {similar_game['title']} (similarity: {similar_game['similarity_score']})")
                print()
        else:
            print(f"{game_date}: Failed to save plan", flush=True)

    print()
    print(f"✓ Generated enhancement plans for {processed_count} game(s)", flush=True)

    return 0


if __name__ == '__main__':
    sys.exit(main())
