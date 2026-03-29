# Beat Runner - Assessment

## Game Overview
A rhythm-based game where players tap buttons in sync with falling notes. Simple but engaging mechanic with clear feedback.

## Status
✅ **Complete** - Playable, fun, polished, with progressive difficulty

## Gameplay
- **Goal**: Hit falling notes to build combos and score points
- **Controls**: Press O button to hit notes; arrows to select difficulty
- **Win Condition**: Survive all 8 rounds without losing 3 lives
- **Lose Condition**: Miss 3 beats
- **Difficulty Levels**:
  - Easy: 1.5x speed (default, accessible)
  - Medium: 2.0x speed (+33% challenge)
  - Hard: 2.5x speed (+66% challenge, demanding)

## Implementation
- State Machine: menu → difficulty → play → gameover
- Test Infrastructure: Complete (_log, test_input, test_log)
- Difficulty Logging: difficulty:(easy|medium|hard) on game start
- Token Count: 628/8192 (efficient implementation)
- Sprites: Minimal (circles for visual feedback)
- Persistent Difficulty: Last selected difficulty remembered for next game

## Feedback & Polish
- Clear visual hit zone with colored feedback text
- Combo system provides progression feedback
- Lives counter shows remaining chances
- Difficulty indicator shown during gameplay
- Simple but effective menu, difficulty selection, and game over screens
- Visual feedback (text color) for selected difficulty in menu

## Recent Enhancements
✅ Sound effects for hits and misses
✅ Difficulty progression with faster beat speeds
✅ Persistent difficulty selection across games
✅ Difficulty menu with visual selection indicator

## Future Enhancements
- Add more complex beat patterns for higher difficulties
- Show visual feedback for perfect timing windows
- Add leaderboard for difficulty levels
- Adjust beat interval (spawn rate) based on difficulty
