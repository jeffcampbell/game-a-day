# Beat Runner - Assessment

## Game Overview
A rhythm-based game where players tap buttons in sync with falling notes. Simple but engaging mechanic with clear feedback.

## Status
✅ **Complete** - Playable, fun, and polished

## Gameplay
- **Goal**: Hit falling notes to build combos and score points
- **Controls**: Press O button to hit notes
- **Win Condition**: Survive all 8 rounds without losing 3 lives
- **Lose Condition**: Miss 3 beats
- **Difficulty**: 2/5 (Easy-Medium)

## Implementation
- State Machine: menu → play → gameover
- Test Infrastructure: Complete (_log, test_input, test_log)
- Token Count: ~750 (well under 8192 limit)
- Sprites: Minimal (circles for visual feedback)

## Feedback & Polish
- Clear visual hit zone with colored feedback text
- Combo system provides progression feedback
- Lives counter shows remaining chances
- Simple but effective menu and game over screens

## Future Enhancements
- Add sound effects for hits and misses
- Vary difficulty with faster beats
- Add more complex beat patterns
- Show visual feedback for perfect timing
