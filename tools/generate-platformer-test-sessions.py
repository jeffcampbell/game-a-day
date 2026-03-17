#!/usr/bin/env python3
"""
Generate synthetic test sessions for comprehensive platformer validation.
Creates deterministic button sequences that exercise key gameplay paths:
- Menu navigation and leaderboard functionality
- Progression through all 8 levels
- Boss encounter
- Secret level discovery
- Combo system triggers
- Failure/death scenarios
"""

import json
import os
from datetime import datetime

GAME_DATE = "2026-03-17"
GAME_DIR = f"games/{GAME_DATE}"

def create_session(name, button_sequence, duration_frames=0):
    """Create a session JSON object."""
    if not duration_frames:
        duration_frames = len(button_sequence)

    session = {
        "date": GAME_DATE,
        "timestamp": datetime.now().isoformat() + "Z",
        "name": name,
        "duration_frames": duration_frames,
        "button_sequence": button_sequence,
        "logs": [],  # Will be populated by actual game execution
        "exit_state": "recorded",
        "is_synthetic": True  # Mark as synthetic for analytics filtering
    }
    return session

def generate_menu_navigation_session():
    """Test menu navigation: start -> leaderboard -> clear -> play."""
    # Menu has 4 options: 1=start, 2=leaderboard, 3=clear, 4=time_attack
    # Button 2 = right arrow, Button 4 = O button (select)
    sequence = []

    # Start at menu (option 1)
    sequence.extend([0] * 10)  # Wait at start

    # Navigate to option 2 (leaderboard)
    sequence.extend([2] * 2)  # Press right
    sequence.extend([0] * 8)
    sequence.extend([16] * 2)  # Press O to select
    sequence.extend([0] * 30)  # View leaderboard

    # Go back and navigate to option 3 (clear)
    sequence.extend([16] * 2)  # Press O to return
    sequence.extend([0] * 8)
    sequence.extend([2] * 2)  # Move right to option 3
    sequence.extend([0] * 8)
    sequence.extend([16] * 2)  # Press O to select
    sequence.extend([0] * 20)  # View clear dialog
    sequence.extend([16] * 2)  # Confirm clear
    sequence.extend([0] * 10)

    # Navigate to option 4 (time attack)
    sequence.extend([2] * 2)  # Right
    sequence.extend([0] * 8)
    sequence.extend([16] * 2)  # Select
    sequence.extend([0] * 30)  # View time attack menu

    # Return to start
    sequence.extend([16] * 2)
    sequence.extend([0] * 8)

    # Start actual game
    sequence.extend([16] * 2)
    sequence.extend([0] * 10)

    return create_session("menu-navigation-test", sequence)

def generate_level_progression_session():
    """Test progression through all 8 levels with careful play."""
    sequence = []

    # Skip menu: press start immediately
    sequence.extend([16] * 2)
    sequence.extend([0] * 60)  # Wait for level intro

    # Level 1-8: For each level, simulate careful platform jumping
    for level in range(1, 9):
        # Each level: jump right, navigate platforms, reach top
        level_frames = 300  # ~5 seconds per level on average

        # Right movement with occasional jumps
        for _ in range(level_frames):
            if _ % 30 == 0:  # Jump every 30 frames
                sequence.append(16)  # Jump (O button)
            elif _ % 8 == 0:  # Move right periodically
                sequence.append(2)
            else:
                sequence.append(0)

        # Level complete wait
        sequence.extend([0] * 30)

    # Final level: wait for boss encounter
    sequence.extend([0] * 60)

    # Boss battle: jump and attack when safe
    for _ in range(200):
        if _ % 20 == 0:
            sequence.append(16)  # Jump
        elif _ % 10 == 0:
            sequence.append(32)  # X button (attack if implemented)
        else:
            sequence.append(0)

    # Victory
    sequence.extend([0] * 30)

    return create_session("level-progression-full", sequence)

def generate_aggressive_playthrough():
    """Aggressive playthrough: fast movement, early death, retry."""
    sequence = []

    # Skip menu
    sequence.extend([16] * 2)
    sequence.extend([0] * 40)

    # Aggressive forward movement with frequent jumps
    for _ in range(800):
        if _ % 10 == 0:
            sequence.append(2)  # Right
            sequence.append(16)  # Jump
        elif _ < 200:
            sequence.append(2)  # Push right hard in early levels
        else:
            # Later levels: collide with enemies (no dodge)
            if _ % 5 == 0:
                sequence.append(2)
            else:
                sequence.append(0)

    # Hit enemy, lose life at ~frame 200-400
    sequence.extend([0] * 20)  # Dead state

    # Back to level start
    sequence.extend([0] * 50)

    # Retry: more careful
    for _ in range(300):
        if _ % 15 == 0:
            sequence.append(2)  # Right
            sequence.append(16)  # Jump
        else:
            sequence.append(0)

    return create_session("aggressive-playthrough", sequence)

def generate_careful_playthrough():
    """Careful playthrough: slow, methodical, complete victory."""
    sequence = []

    # Skip menu
    sequence.extend([16] * 2)
    sequence.extend([0] * 40)

    # Slow, careful navigation through levels
    total_frames = 4000  # ~67 seconds of gameplay

    for i in range(total_frames):
        frame_mod = i % 100

        if frame_mod < 10:
            # Wait and observe
            sequence.append(0)
        elif frame_mod < 20:
            # Move right carefully
            sequence.append(2)
        elif frame_mod < 25:
            # Jump when safe
            sequence.append(16)
        elif frame_mod < 30:
            # Move up if applicable
            sequence.append(4)
        else:
            # More waiting
            sequence.append(0)

    # Boss defeated, victory
    sequence.extend([0] * 50)

    return create_session("careful-playthrough-victory", sequence)

def generate_death_and_retry_session():
    """Test death mechanic and respawn: die on level 3, retry, progress."""
    sequence = []

    # Skip menu and levels 1-2
    sequence.extend([16] * 2)
    sequence.extend([0] * 100)

    # Level 3: Progress then hit enemy
    for _ in range(200):
        sequence.append(2 if _ % 8 == 0 else 0)

    # Hit enemy on level 3
    sequence.extend([0] * 40)  # Dead

    # Respawn and retry
    sequence.extend([0] * 60)

    # Careful retry through level 3
    for _ in range(250):
        if _ % 20 == 0:
            sequence.append(16)  # Jump
        elif _ % 10 == 0:
            sequence.append(2)  # Right
        else:
            sequence.append(0)

    # Level complete
    sequence.extend([0] * 40)

    # Continue to level 4 and beyond
    for _ in range(500):
        sequence.append(2 if _ % 12 == 0 else 0)

    return create_session("death-and-retry-test", sequence)

def generate_exploration_session():
    """Explore for secrets: check hidden paths, find coin bonuses."""
    sequence = []

    # Skip menu
    sequence.extend([16] * 2)
    sequence.extend([0] * 50)

    # Move through levels with vertical exploration
    for level in range(8):
        level_frames = 400
        for frame in range(level_frames):
            mod = frame % 30
            if mod < 5:
                sequence.append(4)  # Up (explore high platforms)
            elif mod < 10:
                sequence.append(8)  # Down (explore low areas)
            elif mod < 15:
                sequence.append(2)  # Right
            elif mod < 17:
                sequence.append(16)  # Jump
            else:
                sequence.append(0)

        sequence.extend([0] * 30)

    return create_session("exploration-secret-hunt", sequence)

def generate_combo_system_session():
    """Test combo system: hit enemies rapidly to build multiplier."""
    sequence = []

    # Skip menu
    sequence.extend([16] * 2)
    sequence.extend([0] * 50)

    # Rapid engagement: move and jump frequently to trigger combos
    for _ in range(2000):
        frame_mod = _ % 8
        if frame_mod == 0:
            sequence.append(16)  # Jump
        elif frame_mod == 1:
            sequence.append(2)  # Right
        elif frame_mod == 2:
            sequence.append(32)  # X button (attack/action)
        elif frame_mod == 3:
            sequence.append(16)  # Jump again
        else:
            sequence.append(0)

    return create_session("combo-system-test", sequence)

def generate_boss_focused_session():
    """Fast progression to boss, test boss mechanics."""
    sequence = []

    # Skip menu and rush through levels 1-7
    sequence.extend([16] * 2)  # Start
    sequence.extend([0] * 30)

    # Levels 1-7: fast but safe
    for level in range(7):
        # Each level: methodical progression
        for _ in range(250):
            if _ % 15 == 0:
                sequence.append(16)  # Jump
            elif _ % 8 == 0:
                sequence.append(2)  # Right
            else:
                sequence.append(0)
        sequence.extend([0] * 20)  # Wait for level complete

    # Boss level: extended battle
    sequence.extend([0] * 60)  # Boss intro

    # Boss fight: dodge and attack
    for _ in range(600):
        frame_mod = _ % 30
        if frame_mod < 5:
            sequence.append(16)  # Jump
        elif frame_mod < 10:
            sequence.append(2)  # Move right
        elif frame_mod < 12:
            sequence.append(32)  # Attack
        elif frame_mod < 15:
            sequence.append(1)  # Move left
        elif frame_mod < 17:
            sequence.append(16)  # Jump
        else:
            sequence.append(0)

    # Boss defeated
    sequence.extend([0] * 50)

    return create_session("boss-focused-speedrun", sequence)

def save_session(session):
    """Save session to file."""
    os.makedirs(GAME_DIR, exist_ok=True)

    # Generate filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(GAME_DIR, f"session_{timestamp}_{session['name']}.json")

    with open(filename, 'w') as f:
        json.dump(session, f, indent=2)

    print(f"✅ Created session: {os.path.basename(filename)}")
    return filename

def main():
    """Generate all test sessions."""
    print("\n" + "="*70)
    print("🎮 GENERATING PLATFORMER TEST SESSIONS")
    print("="*70)
    print(f"\nGame Date: {GAME_DATE}")
    print(f"Creating synthetic test sessions for comprehensive validation\n")

    sessions = [
        generate_menu_navigation_session(),
        generate_level_progression_session(),
        generate_aggressive_playthrough(),
        generate_careful_playthrough(),
        generate_death_and_retry_session(),
        generate_exploration_session(),
        generate_combo_system_session(),
        generate_boss_focused_session(),
    ]

    print("Generated Sessions:")
    for session in sessions:
        save_session(session)

    print(f"\n✅ Total sessions created: {len(sessions)}")
    print(f"📊 Average session length: {sum(s['duration_frames'] for s in sessions) / len(sessions):.0f} frames")
    print(f"\nNotes:")
    print(f"  • All sessions marked as is_synthetic: true")
    print(f"  • Excluded from default analytics calculations")
    print(f"  • Suitable for feature validation and testing")

if __name__ == "__main__":
    main()
