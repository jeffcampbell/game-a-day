# Rhythm Blast - Assessment

## Game Overview
Rhythm Blast is a rhythm action game where players must press buttons (O or X) in time with a beat pattern. The game features a progressive difficulty system with increasing tempo after each level.

## Game Mechanics
- **Menu State**: Title screen with start instructions
- **Play State**: Beat counter displays current tempo, player watches rhythm pattern and presses correct button (O or X) at the right time
- **Gameover State**: Final score, max combo, and levels cleared displayed

## Core Features
- ✓ State machine implementation (menu → play → gameover)
- ✓ Test infrastructure with logging
- ✓ Rhythm pattern matching gameplay
- ✓ Combo tracking and combo breaker on misses
- ✓ Progressive difficulty (tempo increases each level)
- ✓ Health system (3 lives, lose one per miss)
- ✓ Score accumulation (10 points base × level multiplier)

## Testing
- ✓ Static analysis passes (state transitions detected)
- ✓ Adequate logging for all critical events
- ✓ Token count: 568/8192 (well under limit)
- ✓ All required cartridge sections present

## Known Notes
- HTML export created as stub due to headless environment (expected per CLAUDE.md)
- Interactive testing available via: `python3 tools/run-interactive-test.py 2026-04-22`
- Game uses deterministic beat timing (no audio needed)
- Visual feedback via beat display and input indicators
