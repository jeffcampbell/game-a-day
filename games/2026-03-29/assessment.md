# Sky Climb - Assessment

## Game Overview
A fast-paced platformer where players jump upward through procedurally generated platforms while avoiding spikes. Simple but challenging mechanic with smooth physics and engaging gameplay.

## Status
✅ **Complete** - Playable, fun, with progressive difficulty via platform spacing

## Gameplay
- **Goal**: Jump up through platforms to reach a height of 150 units to win
- **Controls**: Arrow keys to move left/right, Z/C (O button) to jump
- **Win Condition**: Reach height ≥150 units
- **Lose Condition**: Fall off the bottom or hit a spike obstacle
- **Challenge**: Platforms are randomly positioned, spikes are spread throughout the level

## Implementation
- State Machine: menu → play → gameover
- Test Infrastructure: Complete (_log, test_input, test_log)
- State Transitions: game:init → state:play → gameover:(win|lose)
- Actions Logged: jump, jump_start, gameover:lose, gameover:win
- Token Count: 958/8192 (efficient implementation)
- Sprites: Uses colored rectangles for platforms (green), spikes (red), and player (cyan)

## Gameplay Mechanics
- Player physics: gravity-based movement with jump power of 3
- Platform collision: player lands on platforms and can jump from them
- Spike collision: touching a spike triggers instant gameover
- Procedural level: platforms and spikes regenerate as player climbs
- Height tracking: score increments with every 10 units climbed
- Smooth scrolling: camera stays centered on player

## Feedback & Polish
- Real-time height display (score) during gameplay
- Clear visual distinction: platforms (green/cyan), spikes (red), player (cyan)
- Win/lose screens with final height displayed
- Simple controls explanation on menu screen
- Responsive controls with smooth movement and jumping

## Game Balance
- Difficulty: 3/5 (platformer with reflex-based timing)
- Playtime: ~8 minutes per session
- Win rate potential: Achievable but requires skill to avoid spikes

## Differences from Recent Games
- Fresh concept (platformer) vs. recent games:
  - 2026-03-28: Comet Clash (action/arcade)
  - 2026-03-27: Mini Quest (adventure/rpg)
  - 2026-03-26-25: Gravity/Sliding Puzzle (puzzle)
  - 2026-03-24: Tile Tactics (strategy)
