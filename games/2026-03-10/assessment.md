# Jungle Escape (2026-03-10) - Initial Assessment

## Game Overview
A single-screen platformer where the player navigates across moving platforms, collects gems, and avoids enemies to reach the exit portal at the top of the screen.

## Core Mechanics ✓
- **Player Movement**: Arrow keys / WASD to move left/right, Up/W to jump
- **Gravity & Physics**: Smooth gravity (0.3), jump power (5), max fall speed (3)
- **Platform Navigation**: 4 platforms at varying heights, 2 with moving patterns
- **Enemy Avoidance**: 2 patrolling enemies with predictable movement patterns
- **Gem Collection**: 4 collectible gems worth 10 points each
- **Exit Portal**: Win condition - reach the exit at top of screen
- **Health System**: 3 hits - lose 1 health when hit by enemy or falling off screen

## Technical Implementation ✓
- State Machine: menu → play → gameover
- Complete test infrastructure (_log, test_input, test_log)
- Proper collision detection (player-platform, player-enemy, player-gems, player-exit)
- Token Count: 1143/8192 (well under budget)
- Sprites: 4 basic sprites for player, enemies, gems, and exit

## Game Flow
1. **Menu**: Instructions displayed, Z/C to start
2. **Play**:
   - Navigate platforms and collect gems
   - Avoid enemies by jumping over them
   - Reach exit portal to win
   - Fall or hit enemy → lose health
3. **Game Over**:
   - Win: Reached exit (any score counts as win)
   - Lose: Health reaches 0
   - Z/C to return to menu

## Balance & Difficulty
- Platforms arranged in ascending difficulty
- Movement speed (2 pixels/frame) allows precision platforming
- Enemy speeds (1-1.5) are learnable and avoidable
- Health = 3 provides fair challenge without frustration
- Target completion time: 5-10 minutes

## Testing Status
- [x] Game boots and shows menu
- [x] Player can move left/right
- [x] Jumping works correctly
- [x] Platform collision functional
- [x] Gravity and physics working
- [x] Enemies patrol as expected
- [x] Gem collection increments score
- [x] Exit portal detects collision
- [x] Health system working (lose health on enemy/fall)
- [x] Game over triggers on health <= 0
- [x] Win condition works (reach exit)
- [x] Menu returns after game over

## Known Limitations
- No sound effects yet (can be added for polish)
- Sprites are minimal (acceptable for day 1)
- No animation between states (acceptable baseline)

## Next Iteration Ideas
- Add sound effects (jump, gem collect, enemy hit, exit)
- More sophisticated platform patterns
- Enemy variety (different speeds/behaviors)
- Power-ups or obstacles
- Score multipliers based on clear speed

## Final Notes
Game is playable and fun with clear win/lose conditions. All acceptance criteria met. Ready for playtesting.
