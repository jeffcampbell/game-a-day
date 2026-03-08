#!/usr/bin/env python3
"""Gameplay Heatmap & Player Behavior Analyzer

Analyzes recorded player sessions to generate spatial and temporal heatmaps showing
where players succeed/fail, which areas they explore, and which mechanics they use.

Usage:
  python3 tools/gameplay-heatmap-analyzer.py 2026-03-08              # Analyze specific game
  python3 tools/gameplay-heatmap-analyzer.py --all                   # Analyze all games
  python3 tools/gameplay-heatmap-analyzer.py 2026-03-08 --viz        # Generate PNG visualization
  python3 tools/gameplay-heatmap-analyzer.py 2026-03-08 --force      # Re-analyze existing reports

Produces:
  - games/<date>/gameplay-heatmap-report.json     # Analysis data
  - games/<date>/gameplay-heatmap.png             # Heatmap visualization
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter
import statistics
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Try to import PIL for visualization
try:
    from PIL import Image, ImageDraw
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    logger.warning("PIL not available - PNG visualization disabled")

# Try to import numpy for efficient array operations
try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False
    logger.warning("NumPy not available - using pure Python arrays")


def load_session(session_path):
    """Load and validate a session JSON file.

    Returns dict if valid, None if invalid/malformed.
    """
    try:
        with open(session_path, 'r') as f:
            session = json.load(f)
            # Validate basic structure
            if not isinstance(session, dict):
                return None
            if 'button_sequence' not in session or 'logs' not in session:
                return None
            # Exclude synthetic sessions
            if session.get('is_synthetic', False):
                return None
            return session
    except (json.JSONDecodeError, IOError, TypeError):
        return None


def find_sessions(game_dir):
    """Find all real (non-synthetic) recorded sessions for a game.

    Returns list of (session_path, session_data) tuples sorted by date.
    """
    sessions = []

    if not os.path.isdir(game_dir):
        return sessions

    for entry in sorted(os.listdir(game_dir)):
        if entry.startswith('session_') and entry.endswith('.json'):
            session_path = os.path.join(game_dir, entry)
            session = load_session(session_path)
            if session:
                sessions.append((session_path, session))

    return sessions


def parse_logs(logs):
    """Extract game events and state info from logs.

    Returns dict with:
    - state_transitions: list of (frame_approx, state) tuples
    - events: list of event strings
    - positions: list of (x, y) if logged
    - scores: list of (frame_approx, score)
    - deaths: list of frame indices where death occurred
    - button_usage: counter of which buttons were pressed
    """
    info = {
        'state_transitions': [],
        'events': [],
        'positions': [],
        'scores': [],
        'deaths': [],
        'health': [],
        'button_usage': Counter(),
        'major_events': []
    }

    for log_entry in logs:
        # Type validation: skip non-string entries
        if not isinstance(log_entry, str):
            continue

        # State transitions
        if log_entry.startswith('state:'):
            state = log_entry.split(':', 1)[1]
            info['state_transitions'].append(state)

        # Score changes
        elif log_entry.startswith('score:'):
            try:
                score = int(log_entry.split(':', 1)[1])
                info['scores'].append(score)
            except ValueError:
                pass

        # Position logging
        elif log_entry.startswith('pos:'):
            try:
                parts = log_entry.split(':', 1)[1].split(',')
                x, y = int(parts[0]), int(parts[1])
                info['positions'].append((x, y))
            except (ValueError, IndexError):
                pass

        # Death/loss events
        elif any(word in log_entry.lower() for word in ['death', 'died', 'lose', 'lost', 'gameover']):
            info['deaths'].append(log_entry)
            info['major_events'].append(log_entry)

        # Health events
        elif any(word in log_entry.lower() for word in ['health', 'hp', 'damage']):
            info['health'].append(log_entry)

        # Collision/interaction events
        elif any(word in log_entry.lower() for word in ['collision', 'hit', 'collect', 'pickup']):
            info['major_events'].append(log_entry)

        # General events
        else:
            info['events'].append(log_entry)

    return info


def infer_positions_from_buttons(button_sequence, width=128, height=128, start_x=64, start_y=64):
    """Infer player position from button sequence.

    Simulates player movement based on button presses.
    Button mapping:
    - 1: Left (0)
    - 2: Right (1)
    - 4: Up (2)
    - 8: Down (3)

    Returns list of (x, y) positions.
    """
    positions = []
    x, y = start_x, start_y

    # Button bit positions
    LEFT = 0
    RIGHT = 1
    UP = 2
    DOWN = 3

    for buttons in button_sequence:
        # Movement speed: 1 pixel per frame
        if buttons & (1 << LEFT):
            x = max(0, x - 1)
        if buttons & (1 << RIGHT):
            x = min(width - 1, x + 1)
        if buttons & (1 << UP):
            y = max(0, y - 1)
        if buttons & (1 << DOWN):
            y = min(height - 1, y + 1)

        positions.append((x, y))

    return positions


def create_heatmap(positions, width=128, height=128):
    """Create a heatmap from positions.

    Returns 2D array of visit counts.
    """
    if HAS_NUMPY:
        heatmap = np.zeros((height, width), dtype=np.uint32)
        for x, y in positions:
            if 0 <= x < width and 0 <= y < height:
                heatmap[y, x] += 1
        return heatmap.tolist()
    else:
        heatmap = [[0] * width for _ in range(height)]
        for x, y in positions:
            if 0 <= x < width and 0 <= y < height:
                heatmap[y][x] += 1
        return heatmap


def analyze_game_sessions(game_dir, game_date):
    """Analyze all sessions for a game.

    Returns comprehensive heatmap report dict.
    """
    sessions = find_sessions(game_dir)

    if not sessions:
        return None

    # Initialize report
    report = {
        'date': game_date,
        'timestamp': datetime.now().isoformat(),
        'session_count': len(sessions),
        'session_metadata': [],
        'movement_heatmap': [[0] * 128 for _ in range(128)],
        'death_heatmap': [[0] * 128 for _ in range(128)],
        'success_heatmap': [[0] * 128 for _ in range(128)],
        'button_usage': {},
        'state_analysis': {
            'state_transitions': [],
            'unique_states': [],
            'state_durations': {}
        },
        'event_analysis': {
            'death_events': 0,
            'collision_events': 0,
            'score_gained': 0,
            'major_events': []
        },
        'temporal_analysis': {
            'avg_session_length_frames': 0,
            'median_session_length_frames': 0,
            'engagement_rate': 0.0,
            'first_death_frame_avg': 0,
            'button_press_frequency': 0.0
        },
        'spatial_analysis': {
            'visited_tiles': 0,
            'dead_zones': [],
            'hotspot_zones': [],
            'danger_zones': []
        },
        'recommendations': []
    }

    # Aggregated data for analysis
    all_positions = []
    all_death_positions = []
    all_button_sequences = []
    session_lengths = []
    first_death_frames = []
    all_state_transitions = []
    total_deaths = 0
    total_max_scores = 0

    # Process each session
    for session_path, session_data in sessions:
        session_meta = {
            'filename': os.path.basename(session_path),
            'duration_frames': session_data.get('duration_frames', 0),
            'logs_count': len(session_data.get('logs', [])),
            'button_presses': sum(1 for b in session_data.get('button_sequence', []) if b > 0)
        }

        duration = session_meta['duration_frames']
        session_lengths.append(duration)

        # Parse logs
        logs = session_data.get('logs', [])
        log_info = parse_logs(logs)

        session_meta['state_transitions'] = log_info['state_transitions']
        session_meta['death_events'] = len(log_info['deaths'])
        session_meta['major_events'] = log_info['major_events'][:5]  # Keep first 5

        report['session_metadata'].append(session_meta)

        # Extract or infer positions
        if log_info['positions']:
            positions = log_info['positions']
        else:
            # Infer from button sequence
            button_seq = session_data.get('button_sequence', [])
            positions = infer_positions_from_buttons(button_seq)

        # Track first death frame
        if log_info['deaths'] and duration > 0:
            # Estimate first death as occurring late in session
            first_death_frames.append(duration * 0.75)

        all_positions.extend(positions)
        all_state_transitions.extend(log_info['state_transitions'])

        # Track deaths at positions (last position where death occurred)
        if log_info['deaths'] and positions:
            # Assume death at end of session
            death_pos = positions[-1] if positions else (64, 64)
            all_death_positions.append(death_pos)
            total_deaths += len(log_info['deaths'])

        # Track button usage
        button_seq = session_data.get('button_sequence', [])
        all_button_sequences.extend(button_seq)
        for buttons in button_seq:
            if buttons & 1:  # Left
                report['button_usage']['left'] = report['button_usage'].get('left', 0) + 1
            if buttons & 2:  # Right
                report['button_usage']['right'] = report['button_usage'].get('right', 0) + 1
            if buttons & 4:  # Up
                report['button_usage']['up'] = report['button_usage'].get('up', 0) + 1
            if buttons & 8:  # Down
                report['button_usage']['down'] = report['button_usage'].get('down', 0) + 1
            if buttons & 16:  # O button
                report['button_usage']['o'] = report['button_usage'].get('o', 0) + 1
            if buttons & 32:  # X button
                report['button_usage']['x'] = report['button_usage'].get('x', 0) + 1

        # Track scores (maximum score per session)
        if log_info['scores']:
            total_max_scores += max(log_info['scores']) if log_info['scores'] else 0

    # Build movement heatmap
    movement_heatmap = create_heatmap(all_positions)
    report['movement_heatmap'] = movement_heatmap

    # Build death heatmap
    if all_death_positions:
        death_heatmap = create_heatmap(all_death_positions)
        report['death_heatmap'] = death_heatmap

    # Calculate temporal metrics
    if session_lengths:
        report['temporal_analysis']['avg_session_length_frames'] = statistics.mean(session_lengths)
        report['temporal_analysis']['median_session_length_frames'] = statistics.median(session_lengths)
        # Engagement rate: normalized metric showing repeat play frequency (approaches 1 as sessions increase)
        report['temporal_analysis']['engagement_rate'] = len(sessions) / (len(sessions) + 1)

        if first_death_frames:
            report['temporal_analysis']['first_death_frame_avg'] = statistics.mean(first_death_frames)

    if all_button_sequences:
        button_presses = sum(1 for b in all_button_sequences if b > 0)
        report['temporal_analysis']['button_press_frequency'] = (
            button_presses / len(all_button_sequences) if all_button_sequences else 0
        )

    # Spatial analysis
    visited_count = sum(1 for row in movement_heatmap for cell in row if cell > 0)
    report['spatial_analysis']['visited_tiles'] = visited_count

    # Find dead zones (never visited)
    dead_zones = []
    for y, row in enumerate(movement_heatmap):
        for x, count in enumerate(row):
            if count == 0:
                dead_zones.append((x, y))

    # Sample dead zones for report (limit to 10)
    report['spatial_analysis']['dead_zones'] = [
        {'x': x, 'y': y} for x, y in dead_zones[:10]
    ]

    # Find hotspot zones (highly visited)
    hotspot_pairs = sorted(
        [(x, y, count) for y, row in enumerate(movement_heatmap)
         for x, count in enumerate(row) if count > 0],
        key=lambda p: p[2],
        reverse=True
    )
    report['spatial_analysis']['hotspot_zones'] = [
        {'x': x, 'y': y, 'visits': count} for x, y, count in hotspot_pairs[:5]
    ]

    # Find danger zones (high death rate)
    if report['death_heatmap'] != [[0] * 128 for _ in range(128)]:
        danger_pairs = sorted(
            [(x, y, count) for y, row in enumerate(report['death_heatmap'])
             for x, count in enumerate(row) if count > 0],
            key=lambda p: p[2],
            reverse=True
        )
        report['spatial_analysis']['danger_zones'] = [
            {'x': x, 'y': y, 'deaths': count} for x, y, count in danger_pairs[:5]
        ]

    # Event analysis
    report['event_analysis']['death_events'] = total_deaths
    report['event_analysis']['score_gained'] = total_max_scores

    # Generate recommendations
    recommendations = []

    if visited_count < 30:
        recommendations.append({
            'type': 'limited_exploration',
            'severity': 'warning',
            'message': f'Players only explored {visited_count}/128x128 tiles. Consider making the game more encouraging to explore.',
            'action': 'Add waypoints or rewards in unexplored areas'
        })

    if len(dead_zones) > 50:
        recommendations.append({
            'type': 'large_dead_zones',
            'severity': 'critical',
            'message': f'Large areas of the game are never visited by players ({len(dead_zones)} dead zones).',
            'action': 'Redesign level layout to guide players through all areas'
        })

    if report['event_analysis']['death_events'] > len(sessions) * 5:
        recommendations.append({
            'type': 'high_death_rate',
            'severity': 'critical',
            'message': f'Players die {report["event_analysis"]["death_events"]} times across {len(sessions)} sessions (avg {report["event_analysis"]["death_events"]/len(sessions):.1f} per session).',
            'action': 'Review difficulty tuning, especially in danger zones'
        })

    if report['spatial_analysis']['danger_zones']:
        danger_zone = report['spatial_analysis']['danger_zones'][0]
        recommendations.append({
            'type': 'difficulty_spike',
            'severity': 'warning',
            'message': f'High death concentration at tile ({danger_zone["x"]}, {danger_zone["y"]}) - {danger_zone["deaths"]} deaths.',
            'action': 'Investigate design around this area, consider reducing difficulty or adding telegraphing'
        })

    if report['button_usage'].get('o', 0) == 0 and report['button_usage'].get('x', 0) == 0:
        recommendations.append({
            'type': 'unused_button',
            'severity': 'info',
            'message': 'Action buttons (O and X) are never used by players.',
            'action': 'Ensure core mechanics are discoverable and explained'
        })

    if report['temporal_analysis']['avg_session_length_frames'] < 300:  # ~5 seconds at 60fps
        recommendations.append({
            'type': 'short_sessions',
            'severity': 'warning',
            'message': f'Average session length is only {report["temporal_analysis"]["avg_session_length_frames"]/60:.1f} seconds.',
            'action': 'Add content or improve pacing to extend engagement'
        })

    report['recommendations'] = recommendations

    return report


def generate_png_visualization(report, output_path):
    """Generate PNG heatmap visualization.

    Creates a visual representation of movement and danger heatmaps.
    """
    if not HAS_PIL:
        logger.warning("PIL not available - skipping PNG generation")
        return False

    width, height = 128, 128
    scale = 4  # Scale each cell to 4x4 pixels for visibility
    img_width, img_height = width * scale, height * scale

    # Create new image with white background
    img = Image.new('RGB', (img_width + 100, img_height + 50), color='white')
    draw = ImageDraw.Draw(img)

    # Draw movement heatmap
    movement_heatmap = report['movement_heatmap']

    # Find max value for color scaling
    max_visits = max(max(row) for row in movement_heatmap) if movement_heatmap else 1
    max_visits = max(1, max_visits)  # Avoid division by zero

    for y in range(height):
        for x in range(width):
            visits = movement_heatmap[y][x] if y < len(movement_heatmap) and x < len(movement_heatmap[y]) else 0

            # Color gradient: blue (cold) -> cyan -> green -> yellow -> red (hot)
            intensity = visits / max_visits if max_visits > 0 else 0

            if intensity == 0:
                color = (200, 200, 200)  # Light gray for unvisited
            else:
                # Create heat gradient
                if intensity < 0.25:
                    # Blue to cyan
                    ratio = intensity / 0.25
                    color = (0, int(100 + ratio * 155), 255)
                elif intensity < 0.5:
                    # Cyan to green
                    ratio = (intensity - 0.25) / 0.25
                    color = (0, 255, int(255 - ratio * 255))
                elif intensity < 0.75:
                    # Green to yellow
                    ratio = (intensity - 0.5) / 0.25
                    color = (int(ratio * 255), 255, 0)
                else:
                    # Yellow to red
                    ratio = (intensity - 0.75) / 0.25
                    color = (255, int(255 - ratio * 255), 0)

            # Draw scaled cell
            x0, y0 = x * scale, y * scale
            x1, y1 = x0 + scale, y0 + scale
            draw.rectangle([x0, y0, x1, y1], fill=color)

    # Draw grid at 8x8 (PICO-8 sprite boundaries)
    grid_color = (100, 100, 100)
    for i in range(0, width * scale, 8 * scale):
        draw.line([(i, 0), (i, height * scale)], fill=grid_color, width=1)
    for i in range(0, height * scale, 8 * scale):
        draw.line([(0, i), (width * scale, i)], fill=grid_color, width=1)

    # Mark danger zones
    death_heatmap = report['death_heatmap']
    max_deaths = max(max(row) for row in death_heatmap) if death_heatmap else 0

    if max_deaths > 0:
        for y in range(height):
            for x in range(width):
                deaths = death_heatmap[y][x] if y < len(death_heatmap) and x < len(death_heatmap[y]) else 0
                if deaths > 0:
                    # Draw red X overlay
                    x0, y0 = x * scale + scale // 4, y * scale + scale // 4
                    x1, y1 = x * scale + 3 * scale // 4, y * scale + 3 * scale // 4
                    draw.line([(x0, y0), (x1, y1)], fill=(255, 0, 0), width=1)
                    draw.line([(x1, y0), (x0, y1)], fill=(255, 0, 0), width=1)

    # Add title and legend
    title = f"Gameplay Heatmap - {report['date']}"
    draw.text((10, img_height + 10), title, fill='black')

    legend_y = img_height + 25
    draw.rectangle([(10, legend_y), (30, legend_y + 10)], fill=(0, 100, 255))
    draw.text((35, legend_y - 2), "Cold (safe)", fill='black')

    draw.rectangle([(10, legend_y + 15), (30, legend_y + 25)], fill=(255, 0, 0))
    draw.text((35, legend_y + 13), "Hot (dangerous)", fill='black')

    # Save image
    try:
        img.save(output_path)
        logger.info(f"✓ PNG visualization saved: {output_path}")
        return True
    except Exception as e:
        logger.error(f"✗ Failed to save PNG: {e}")
        return False


def find_all_games():
    """Find all PICO-8 games."""
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


def main():
    parser = argparse.ArgumentParser(
        description='Analyze gameplay sessions and generate heatmaps'
    )
    parser.add_argument(
        'game_date',
        nargs='?',
        help='Game date (YYYY-MM-DD) or "--all" for all games'
    )
    parser.add_argument(
        '--all',
        action='store_true',
        help='Analyze all games with sessions'
    )
    parser.add_argument(
        '--viz',
        action='store_true',
        help='Generate PNG visualizations'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Re-analyze even if report exists'
    )

    args = parser.parse_args()

    # Determine which games to analyze
    if args.all or not args.game_date:
        games = find_all_games()
    else:
        # Validate game_date format to prevent path traversal
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', args.game_date):
            print(f"Invalid game date format: {args.game_date}", file=sys.stderr)
            return 1
        games = [(args.game_date, os.path.join('games', args.game_date))]

    if not games:
        print("No games found", file=sys.stderr)
        return 1

    analyzed_count = 0
    skipped_count = 0

    for game_date, game_dir in games:
        # Check if report already exists
        report_path = os.path.join(game_dir, 'gameplay-heatmap-report.json')
        if os.path.exists(report_path) and not args.force:
            logger.info(f"⊘ {game_date}: Report exists (use --force to re-analyze)")
            skipped_count += 1
            continue

        # Find sessions
        sessions = find_sessions(game_dir)
        if not sessions:
            logger.info(f"⊘ {game_date}: No real sessions recorded (minimum 3 needed)")
            skipped_count += 1
            continue

        if len(sessions) < 3:
            logger.info(f"⊘ {game_date}: Only {len(sessions)} session(s) (minimum 3 needed)")
            skipped_count += 1
            continue

        # Analyze game
        logger.info(f"→ Analyzing {game_date} ({len(sessions)} sessions)...")
        report = analyze_game_sessions(game_dir, game_date)

        if not report:
            logger.error(f"✗ {game_date}: Failed to analyze")
            continue

        # Save report
        try:
            with open(report_path, 'w') as f:
                json.dump(report, f, indent=2)
            logger.info(f"✓ {game_date}: Report saved")
            analyzed_count += 1
        except Exception as e:
            logger.error(f"✗ {game_date}: Failed to save report: {e}")
            continue

        # Generate PNG if requested
        if args.viz:
            png_path = os.path.join(game_dir, 'gameplay-heatmap.png')
            generate_png_visualization(report, png_path)

    print(f"\nSummary: {analyzed_count} analyzed, {skipped_count} skipped")
    return 0 if analyzed_count > 0 else 1


if __name__ == '__main__':
    sys.exit(main())
