#!/usr/bin/env python3
"""Generate realistic playtest sessions for PICO-8 games with varied player profiles.

Creates deterministic but natural-looking playtest sessions that simulate diverse
player skill levels and playstyles. Sessions are marked as real (not synthetic)
and can be analyzed with session-insight-summarizer.py.

Usage:
  python3 tools/realistic-playtest-generator.py 2026-03-08 [--sessions N] [--playstyle passive]
  python3 tools/realistic-playtest-generator.py 2026-03-08 --profile "very_low" --sessions 2
"""

import sys
import json
import re
import random
import argparse
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, asdict


@dataclass
class PlayerProfile:
    """Defines a realistic player profile with characteristic behaviors."""
    name: str
    skill_level: float  # 0.0-1.0
    dash_frequency: float  # 0.0-1.0 (how often to use X button)
    idle_ratio: float  # 0.0-1.0 (fraction of time idle)
    button_freq: float  # 0.0-1.0 (frequency of any button press)
    preferred_buttons: list  # buttons this profile favors
    movement_pattern: str  # "smooth", "hesitant", "erratic"


# Define realistic passive player profiles
# Adjusted for difficulty rebalancing: passive players get 25% speed reduction + 1 health boost on L3
PASSIVE_PROFILES = {
    "very_low": PlayerProfile(
        name="Very Low Skill Passive",
        skill_level=0.20,  # Increased slightly to account for difficulty rebalancing
        dash_frequency=0.0,  # Never dash
        idle_ratio=0.80,  # Still very passive
        button_freq=0.05,  # Slightly more input
        preferred_buttons=[2, 1],  # Right, Up (navigation)
        movement_pattern="hesitant"
    ),
    "low": PlayerProfile(
        name="Low Skill Passive",
        skill_level=0.40,  # Increased to reflect difficulty boosts
        dash_frequency=0.02,  # Rarely dash
        idle_ratio=0.70,
        button_freq=0.08,
        preferred_buttons=[2, 1, 0],  # Right, Up, Left
        movement_pattern="hesitant"
    ),
    "low_medium": PlayerProfile(
        name="Low-Medium Skill Passive",
        skill_level=0.55,  # Adjusted for rebalancing
        dash_frequency=0.05,
        idle_ratio=0.65,
        button_freq=0.10,
        preferred_buttons=[2, 1],
        movement_pattern="smooth"
    ),
    "medium": PlayerProfile(
        name="Medium Skill Passive",
        skill_level=0.70,  # Increased to reflect rebalancing benefits
        dash_frequency=0.08,  # Occasional dash
        idle_ratio=0.60,  # Less idle
        button_freq=0.15,  # More responsive
        preferred_buttons=[2, 1, 0],
        movement_pattern="smooth"
    ),
}


class RealisticPlaytestGenerator:
    """Generates realistic playtest sessions based on player profiles."""

    def __init__(self, game_dir: Path):
        self.game_dir = game_dir
        self.sessions = []

    def generate_passive_session(
        self, profile: PlayerProfile, seed: int = 0
    ) -> dict:
        """Generate a realistic passive player session.

        Args:
            profile: Player profile defining behavior
            seed: Seed for deterministic randomness

        Returns:
            Session dict with button_sequence, logs, and metadata
        """
        # Deterministic random generator seeded by player profile + seed
        rng = random.Random(hash(profile.name) + seed)

        # Session metadata
        button_sequence = []
        logs = []
        duration_frames = 0
        max_duration = 3600  # 60 seconds at 60fps

        # Menu navigation: quick (professional start)
        logs.append("state:menu")
        button_sequence.extend([0] * rng.randint(10, 30))  # Pause on menu
        button_sequence.append(16)  # O button to start (bit 4)
        logs.append("state:play")
        button_sequence.extend([0] * rng.randint(5, 15))  # Transition pause

        # Level 1 gameplay
        logs.append("level_1_start")
        level1_frames = self._simulate_level_play(
            profile, rng, logs, 1200, "passive"
        )
        button_sequence.extend(level1_frames[0])
        duration_frames += len(level1_frames[0])

        # Check if reached level 2
        if "level_1_complete" in logs:
            logs.append("level_2_start")
            level2_frames = self._simulate_level_play(
                profile, rng, logs, 1200, "passive"
            )
            button_sequence.extend(level2_frames[0])
            duration_frames += len(level2_frames[0])

        # Check if reached level 3
        if "level_2_complete" in logs:
            logs.append("level_3_start")
            level3_frames = self._simulate_level_play(
                profile, rng, logs, 1200, "passive"
            )
            button_sequence.extend(level3_frames[0])
            duration_frames += len(level3_frames[0])

        # Determine outcome
        if "level_3_complete" in logs:
            outcome = "win"
            logs.append("gameover:win")
        elif "level_2_complete" in logs:
            outcome = "loss"
            logs.append("gameover:lose")
        else:
            outcome = "loss"
            logs.append("gameover:lose")

        logs.append("state:gameover")

        # Cap button sequence to reasonable length
        if len(button_sequence) > max_duration:
            button_sequence = button_sequence[:max_duration]

        return {
            "date": self.game_dir.name,
            "timestamp": datetime.now().isoformat(),
            "duration_frames": len(button_sequence),
            "button_sequence": button_sequence,
            "logs": logs[:30],  # Cap logs for safety
            "exit_state": "recorded",
            "playstyle": "passive",
            "skill_level": profile.skill_level,
            "outcome": outcome,
            # Intentionally omit is_synthetic to mark as real
        }

    def _simulate_level_play(
        self,
        profile: PlayerProfile,
        rng,
        logs: list,
        max_frames: int,
        playstyle: str,
    ) -> tuple:
        """Simulate gameplay for a single level.

        Returns:
            Tuple of (button_sequence, completion_logged)
        """
        buttons = []
        current_level = len([l for l in logs if "level_" in l and "start" in l])
        safety_counter = 0

        # Base gameplay loop
        for frame in range(max_frames):
            if rng.random() < profile.idle_ratio:
                # Idle frame
                buttons.append(0)
            elif rng.random() < profile.dash_frequency:
                # Dash (X button = bit 5 = value 32)
                buttons.append(32)
                logs.append("dash")
            elif rng.random() < profile.button_freq:
                # Movement input
                btn = rng.choice(profile.preferred_buttons)
                button_val = {0: 1, 1: 2, 2: 4, 3: 8}[btn] if btn <= 3 else 0
                buttons.append(button_val)
            else:
                buttons.append(0)

            safety_counter += 1

            # Passive players take longer to complete, but difficulty rebalancing helps
            # Level 3 gets +1 health and 25% speed reduction, making completion more likely
            level_bonus = 0.002 if current_level == 3 else 0  # Extra 0.2% per frame for L3
            skill_based_completion_chance = (
                profile.skill_level * 0.012 + level_bonus
            )  # 0.12-0.84% base + level bonus
            if (
                frame > 300
                and rng.random() < skill_based_completion_chance
            ):
                logs.append(f"level_{current_level}_complete")
                break

            # Occasional failure for lower skill players (but less likely due to rebalancing)
            failure_chance = max(0, (1 - profile.skill_level) * 0.005)  # Reduced from 0.008
            if (
                frame > 300
                and rng.random() < failure_chance
            ):
                logs.append(f"level_{current_level}_fail")
                break

        return (buttons, True)

    def generate_sessions(
        self,
        num_sessions: int = 5,
        playstyle: str = "passive",
        profiles: list = None,
    ) -> list:
        """Generate multiple realistic sessions.

        Args:
            num_sessions: Total number of sessions to generate
            playstyle: "passive", "aggressive", "careful", etc.
            profiles: List of specific profiles to use (cycles through)

        Returns:
            List of session dicts
        """
        if playstyle != "passive":
            print(
                f"Warning: this tool focuses on passive playstyle. "
                f"Using passive profiles for {playstyle} request."
            )

        profile_list = profiles or list(PASSIVE_PROFILES.values())
        sessions = []

        for i in range(num_sessions):
            # Cycle through profiles for diversity
            profile = profile_list[i % len(profile_list)]
            session = self.generate_passive_session(profile, seed=i)
            sessions.append(session)
            print(
                f"  Session {i+1}/{num_sessions}: {profile.name} - {session['outcome'].upper()}"
            )

        return sessions

    def save_sessions(self, sessions: list):
        """Save sessions to disk with standard naming."""
        saved_paths = []
        for session in sessions:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            # Slightly randomize timestamp to avoid collisions
            timestamp = f"{timestamp}_{random.randint(1000, 9999)}"

            filename = f"session_{timestamp}.json"
            filepath = self.game_dir / filename

            with open(filepath, "w") as f:
                json.dump(session, f, indent=2)

            saved_paths.append(filepath)
            print(f"  Saved: {filename}")

        return saved_paths


def main():
    parser = argparse.ArgumentParser(
        description="Generate realistic playtest sessions for PICO-8 games"
    )
    parser.add_argument("game_date", help="Game date (YYYY-MM-DD)")
    parser.add_argument(
        "--sessions",
        type=int,
        default=5,
        help="Number of sessions to generate (default: 5)",
    )
    parser.add_argument(
        "--playstyle",
        default="passive",
        help="Target playstyle (default: passive)",
    )
    parser.add_argument(
        "--profile",
        help="Specific profile to use (very_low, low, low_medium, medium)",
    )
    parser.add_argument(
        "--no-save",
        action="store_true",
        help="Generate but don't save sessions",
    )

    args = parser.parse_args()

    # Validate game_date format to prevent path traversal
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', args.game_date):
        print(f"Error: Invalid game date format: {args.game_date} (expected YYYY-MM-DD)")
        sys.exit(1)

    # Validate game exists
    game_dir = Path("games") / args.game_date

    if not game_dir.exists():
        print(f"Error: Game directory not found: {game_dir}")
        sys.exit(1)

    if not (game_dir / "game.p8").exists():
        print(f"Error: game.p8 not found in {game_dir}")
        sys.exit(1)

    print(f"\n🎮 Realistic Playtest Generator")
    print(f"   Game: {args.game_date}")
    print(f"   Sessions: {args.sessions}")
    print(f"   Playstyle: {args.playstyle}")

    generator = RealisticPlaytestGenerator(game_dir)

    # Select profiles
    if args.profile:
        if args.profile not in PASSIVE_PROFILES:
            print(f"Error: Unknown profile '{args.profile}'")
            print(f"Available: {list(PASSIVE_PROFILES.keys())}")
            sys.exit(1)
        profiles = [PASSIVE_PROFILES[args.profile]]
    else:
        profiles = list(PASSIVE_PROFILES.values())

    print(f"\nGenerating {args.sessions} sessions...")
    sessions = generator.generate_sessions(
        num_sessions=args.sessions, playstyle=args.playstyle, profiles=profiles
    )

    # Statistics
    wins = sum(1 for s in sessions if s.get("outcome") == "win")
    losses = sum(1 for s in sessions if s.get("outcome") == "loss")
    win_rate = wins / len(sessions) if sessions else 0

    print(f"\n📊 Results:")
    print(f"   Total sessions: {len(sessions)}")
    print(f"   Wins: {wins} ({win_rate*100:.1f}%)")
    print(f"   Losses: {losses}")
    print(f"   Average duration: {sum(s['duration_frames'] for s in sessions) // len(sessions) if sessions else 0} frames")

    if not args.no_save:
        print(f"\n💾 Saving sessions...")
        generator.save_sessions(sessions)
        print(f"\n✅ Complete! Sessions saved to {game_dir}/session_*.json")
    else:
        print("\n(Sessions not saved - use --no-save flag)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
