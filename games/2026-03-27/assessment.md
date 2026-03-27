# Mini Quest - Assessment

## Game Overview
A dungeon exploration RPG where the player navigates a grid-based maze, encounters an enemy, engages in turn-based combat, and attempts to escape with the key.

## Mechanics
- **Movement**: Arrow keys to move around the dungeon (4x4 grid)
- **Combat**: Z/C button to attack when touching enemy (turn-based)
- **Objective**: Defeat the enemy, pick up the key, and reach the exit
- **Score**: 10 points for defeating enemy, 50 bonus for escaping = 60 max

## Design
- Simple 14x14 grid dungeon with walls
- Enemy starts at (5,4), respawns at (3,12) after defeat
- Player health system (10 HP)
- Basic damage calculation (2-3 HP per attack)
- State machine: menu → play → gameover

## Technical
- Token count: 880/8192 (well under limit)
- No sprites or sound effects used (geometric rendering only)
- Full test infrastructure with _log() calls for state transitions and events
- Compatible with headless testing

## Polish
- Clean menu with instructions
- Combat feedback messages ("hit for 2!", "you were defeated!")
- Distinct win/lose screens
- Color-coded UI (enemy red/8, key yellow/10, player blue/11)

## Known Limitations
- Combat is very simple (no tactical depth)
- Dungeon is small and simple
- Only one enemy

## Future Enhancements
- Multiple enemies with different behaviors
- More dungeon variety and larger exploration area
- Item system (healing potions, weapons)
- Sound effects and animations
- Enemy AI pathfinding
- Multiple levels
