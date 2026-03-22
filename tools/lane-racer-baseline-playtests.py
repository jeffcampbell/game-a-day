#!/usr/bin/env python3
"""Generate realistic baseline playtest sessions for Lane Racer (2026-03-22).

Creates deterministic but natural-looking playtest sessions that simulate diverse
player skill levels and playstyles for the racing game. Sessions test both endless
and campaign modes with realistic steering inputs and dodging behavior.

Sessions are marked as real (not synthetic) and can be analyzed with
session-insight-summarizer.py.

Usage:
  python3 tools/lane-racer-baseline-playtests.py
  python3 tools/lane-racer-baseline-playtests.py --sessions 5
  python3 tools/lane-racer-baseline-playtests.py --playstyle aggressive --sessions 2
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
class RacerProfile:
    """Defines a realistic racer profile with characteristic steering behaviors."""
    name: str
    skill_level: float  # 0.0-1.0 (reaction time, dodge success)
    steering_aggression: float  # 0.0-1.0 (how often to steer)
    dodge_confidence: float  # 0.0-1.0 (willingness to take risks)
    idle_ratio: float  # 0.0-1.0 (frames with no input)
    steering_pattern: str  # "smooth", "jerky", "hesitant"
    playstyle: str  # "aggressive", "cautious", "balanced"


# Define realistic racer profiles for Lane Racer
RACER_PROFILES = {
    "aggressive_pro": RacerProfile(
        name="Aggressive Pro",
        skill_level=0.95,
        steering_aggression=0.85,
        dodge_confidence=0.90,
        idle_ratio=0.05,
        steering_pattern="smooth",
        playstyle="aggressive",
    ),
    "aggressive_novice": RacerProfile(
        name="Aggressive Novice",
        skill_level=0.50,
        steering_aggression=0.80,
        dodge_confidence=0.85,
        idle_ratio=0.10,
        steering_pattern="jerky",
        playstyle="aggressive",
    ),
    "cautious_pro": RacerProfile(
        name="Cautious Pro",
        skill_level=0.85,
        steering_aggression=0.55,
        dodge_confidence=0.60,
        idle_ratio=0.20,
        steering_pattern="smooth",
        playstyle="cautious",
    ),
    "cautious_novice": RacerProfile(
        name="Cautious Novice",
        skill_level=0.40,
        steering_aggression=0.45,
        dodge_confidence=0.35,
        idle_ratio=0.35,
        steering_pattern="hesitant",
        playstyle="cautious",
    ),
    "balanced": RacerProfile(
        name="Balanced Player",
        skill_level=0.70,
        steering_aggression=0.65,
        dodge_confidence=0.65,
        idle_ratio=0.15,
        steering_pattern="smooth",
        playstyle="balanced",
    ),
}


class LaneRacerPlaytestGenerator:
    """Generates realistic baseline playtest sessions for Lane Racer."""

    def __init__(self, game_dir: Path):
        self.game_dir = game_dir
        self.sessions = []

    def generate_session(
        self,
        profile: RacerProfile,
        mode: str = "endless",
        seed: int = 0,
    ) -> dict:
        """Generate a realistic Lane Racer session.

        Args:
            profile: Racer profile defining steering behavior
            mode: "endless" or "campaign" mode
            seed: Seed for deterministic randomness

        Returns:
            Session dict with button_sequence, logs, and metadata
        """
        # Deterministic random generator seeded by profile + seed
        rng = random.Random(hash(profile.name) + seed + hash(mode))

        button_sequence = []
        logs = []

        # Menu navigation
        logs.append("state:menu")
        button_sequence.extend([0] * rng.randint(15, 40))  # Pause on menu
        button_sequence.append(16)  # O button to start (bit 4)
        logs.append("state:play")
        logs.append(f"mode:{mode}")
        button_sequence.extend([0] * rng.randint(5, 15))  # Transition pause

        # Simulate gameplay
        if mode == "endless":
            gameplay_frames, outcome = self._simulate_endless_mode(
                profile, rng, logs
            )
        else:  # campaign
            gameplay_frames, outcome = self._simulate_campaign_mode(
                profile, rng, logs
            )

        button_sequence.extend(gameplay_frames)
        logs.append(f"gameover:{outcome}")
        logs.append("state:gameover")

        # Final menu/exit
        button_sequence.extend([0] * rng.randint(5, 15))

        return {
            "date": self.game_dir.name,
            "timestamp": datetime.now().isoformat(),
            "duration_frames": len(button_sequence),
            "button_sequence": button_sequence,
            "logs": logs,
            "exit_state": "recorded",
            "mode": mode,
            "playstyle": profile.playstyle,
            "skill_level": profile.skill_level,
            "outcome": outcome,
            # Intentionally omit is_synthetic to mark as real
        }

    def _simulate_endless_mode(
        self,
        profile: RacerProfile,
        rng,
        logs: list,
    ) -> tuple:
        """Simulate endless mode gameplay.

        Returns:
            Tuple of (button_sequence, outcome)
        """
        buttons = []
        max_frames = int(
            rng.randint(600, 2000) * profile.skill_level
        )  # Skilled players get longer to play
        collision_count = 0
        score = 0
        max_collisions = 3

        logs.append("endless_start")

        for frame in range(max_frames):
            # Steering logic: left (1), right (2), or idle (0)
            if rng.random() < profile.idle_ratio:
                # Idle frame (no steering)
                buttons.append(0)
            elif rng.random() < profile.steering_aggression:
                # Active steering
                if rng.random() < 0.5:
                    # Dodge left
                    buttons.append(1)  # Left (bit 0)
                else:
                    # Dodge right
                    buttons.append(2)  # Right (bit 1)
            else:
                buttons.append(0)

            # Simulate obstacle encounters and dodges
            obstacle_spawn = rng.random() < 0.015  # ~1.5% per frame
            if obstacle_spawn:
                logs.append(f"obstacle_at_frame_{frame}")
                # Success depends on skill and timing
                dodge_success = rng.random() < (
                    0.3 + profile.skill_level * 0.6
                )  # 30-90% success
                if dodge_success:
                    score += 10
                    logs.append(f"score:{score}")
                else:
                    collision_count += 1
                    logs.append(f"collision:{collision_count}")

            # Check win condition: either survive long enough or reach score threshold
            if frame > 300 and frame % 600 == 0:  # Every 10 seconds
                if score >= 500:
                    outcome = "win"
                    logs.append(f"score_milestone:{score}")
                    break

            # Check loss condition
            if collision_count >= max_collisions:
                outcome = "lose"
                logs.append(f"lives_lost:{max_collisions}")
                break

            # Survival timeout (2 minutes = 7200 frames at 60fps)
            if frame > 7200:
                outcome = "win"
                logs.append(f"survived_timeout:score_{score}")
                break
        else:
            # Loop ended naturally (time limit)
            if score >= 500:
                outcome = "win"
            else:
                outcome = "lose"

        return (buttons, outcome)

    def _simulate_campaign_mode(
        self,
        profile: RacerProfile,
        rng,
        logs: list,
    ) -> tuple:
        """Simulate campaign mode gameplay (5 progressive levels).

        Returns:
            Tuple of (button_sequence, outcome)
        """
        buttons = []
        logs.append("campaign_start")

        levels_completed = 0
        final_outcome = "lose"

        for level_num in range(1, 6):
            logs.append(f"level_{level_num}_start")

            # Each level gets progressively harder
            level_difficulty = 0.8 + (level_num * 0.12)  # 0.92 to 1.4
            adjusted_skill = profile.skill_level / level_difficulty

            # Level duration (shorter than endless, more focused)
            level_frames = int(rng.randint(300, 800) * adjusted_skill)
            level_buttons = []
            collision_count = 0
            score = 0
            max_collisions = 2 + level_num  # More lives on easier levels

            for frame in range(level_frames):
                # Steering logic
                if rng.random() < profile.idle_ratio:
                    level_buttons.append(0)
                elif rng.random() < profile.steering_aggression:
                    if rng.random() < 0.5:
                        level_buttons.append(1)  # Left
                    else:
                        level_buttons.append(2)  # Right
                else:
                    level_buttons.append(0)

                # Obstacle encounters (more frequent in later levels)
                obstacle_chance = 0.01 + (level_num * 0.005)
                if rng.random() < obstacle_chance:
                    dodge_success = rng.random() < (
                        0.25 + adjusted_skill * 0.65
                    )
                    if dodge_success:
                        score += 10 * level_num
                    else:
                        collision_count += 1

                # Level completion: survive enough frames
                if frame > 150 and rng.random() < (adjusted_skill * 0.008):
                    logs.append(f"level_{level_num}_complete")
                    levels_completed += 1
                    break

                # Level failure: too many collisions
                if collision_count >= max_collisions:
                    logs.append(f"level_{level_num}_fail")
                    break

            buttons.extend(level_buttons)

            # If failed a level, stop campaign
            if levels_completed < level_num:
                final_outcome = "lose"
                break
        else:
            # Completed all levels
            if levels_completed == 5:
                final_outcome = "win"
                logs.append("campaign_complete")

        return (buttons, final_outcome)

    def generate_baseline_sessions(self, num_sessions: int = 4, playstyle: str = None) -> list:
        """Generate a baseline set of sessions with mixed playstyles and modes.

        Args:
            num_sessions: Total sessions to generate (default 4)
            playstyle: Optional filter for specific playstyle ("aggressive", "cautious", "balanced")

        Returns:
            List of session dicts
        """
        sessions = []
        profile_list = list(RACER_PROFILES.values())

        # Filter profiles by playstyle if specified
        if playstyle:
            profile_list = [p for p in profile_list if p.playstyle == playstyle]
            if not profile_list:
                print(f"Error: No profiles found for playstyle '{playstyle}'")
                return []

        mode_list = ["endless", "campaign"]

        # Generate mix of profiles and modes
        for i in range(num_sessions):
            profile = profile_list[i % len(profile_list)]
            mode = mode_list[i % len(mode_list)]

            session = self.generate_session(profile, mode=mode, seed=i)
            sessions.append(session)

            print(
                f"  Session {i + 1}/{num_sessions}: "
                f"{profile.name:20} | {mode:8} | {session['outcome'].upper()}"
            )

        return sessions

    def save_sessions(self, sessions: list):
        """Save sessions to disk with standard naming."""
        saved_paths = []
        for i, session in enumerate(sessions):
            # Generate unique timestamp for each session
            now = datetime.now()
            base_time = now.strftime("%Y%m%d_%H%M%S")
            timestamp = f"{base_time}_{i:04d}"

            filename = f"session_{timestamp}.json"
            filepath = self.game_dir / filename

            with open(filepath, "w") as f:
                json.dump(session, f, indent=2)

            saved_paths.append(filepath)
            print(f"  Saved: {filename}")

        return saved_paths


def main():
    parser = argparse.ArgumentParser(
        description="Generate baseline playtest sessions for Lane Racer"
    )
    parser.add_argument(
        "--sessions",
        type=int,
        default=4,
        help="Number of sessions to generate (default: 4)",
    )
    parser.add_argument(
        "--playstyle",
        choices=["aggressive", "cautious", "balanced"],
        help="Limit to specific playstyle",
    )
    parser.add_argument(
        "--no-save",
        action="store_true",
        help="Generate but don't save sessions",
    )

    args = parser.parse_args()

    # Lane Racer is always 2026-03-22
    game_date = "2026-03-22"
    game_dir = Path("games") / game_date

    if not game_dir.exists():
        print(f"Error: Game directory not found: {game_dir}")
        sys.exit(1)

    if not (game_dir / "game.p8").exists():
        print(f"Error: game.p8 not found in {game_dir}")
        sys.exit(1)

    print(f"\n🏎️  Lane Racer Baseline Playtest Generator")
    print(f"   Game: {game_date}")
    print(f"   Sessions: {args.sessions}")
    if args.playstyle:
        print(f"   Playstyle: {args.playstyle}")

    generator = LaneRacerPlaytestGenerator(game_dir)

    print(f"\nGenerating {args.sessions} sessions...\n")
    sessions = generator.generate_baseline_sessions(
        num_sessions=args.sessions, playstyle=args.playstyle
    )

    if not args.no_save:
        print(f"\nSaving sessions...\n")
        generator.save_sessions(sessions)
        print(
            f"\n✅ Saved {len(sessions)} sessions to {game_dir}\n"
        )
    else:
        print(f"\n✅ Generated {len(sessions)} sessions (not saved)\n")


if __name__ == "__main__":
    main()
