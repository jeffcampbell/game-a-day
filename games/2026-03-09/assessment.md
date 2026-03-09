# Dungeon Crawler RPG - Assessment

## Gameplay Overview

A turn-based dungeon crawler RPG where the player fights through enemy encounters to defeat a final boss. Features character progression, inventory management, and tactical combat choices.

## Core Mechanics

### Combat System
- **Turn-Based**: Player and enemy take turns each round
- **Actions**:
  - **Attack**: Deals damage based on ATK stat minus enemy DEF, with slight variance
  - **Defend**: Reduces incoming damage (currently passive for turn)
  - **Potion**: Heals 8 HP (limited supply: 2 potions per quest)
  - **Flee**: 50% chance to escape encounter

### Character Progression
- **Leveling**: Gain 10 EXP per enemy defeat; level up at 30 EXP
- **Stats at Level 1**: HP=20, ATK=5, DEF=2
- **Stat Gains per Level**: +5 max HP, +1 ATK, +1 DEF
- **Progression Arc**: Fight 2 goblin encounters, then face the boss

### Difficulty Curve
- **Goblin 1**: 8 HP, 3 ATK (starting encounter)
- **Goblin 2**: 14 HP, 4 ATK (after leveling)
- **Boss**: 25 HP, 6 ATK, 2 DEF (final challenge)

## Menu System
- **Start Quest**: Enter combat encounter
- **Quit**: Exit to menu

## Game States
1. **Menu**: Select "Start Quest" or "Quit"
2. **Play**: Combat encounters (can have multiple)
3. **Game Over**: Win (defeated boss) or lose (player HP = 0)

## Test Results

- ✓ State machine transitions work correctly
- ✓ Combat mechanics function as designed
- ✓ Leveling system progresses appropriately
- ✓ Win condition (3 enemy defeats) triggers correctly
- ✓ Lose condition (player HP = 0) triggers correctly
- ✓ Test infrastructure in place (_log, test_input, testmode)

## Design Notes

### Strengths
- Clear progression: player starts weak, levels up, then faces boss
- Engaging decision space: choose between attack, defend, heal
- Manageable scope: ~1050 tokens, well under limit
- Simple but complete game loop

### Possible Improvements (Future)
- Equipment system (armor/weapons for stat bonuses)
- More enemy variety (different monster types)
- Status effects (poison, stun, etc.)
- Multi-floor dungeons with treasure drops
- Boss special abilities

## Technical Details
- **Token Usage**: 1050/8192 (12.8% - plenty of room for expansion)
- **Sprites**: 2 (player, enemy placeholder)
- **Sound Effects**: 3 (menu, combat, gameover)
- **Target Playtime**: 3-5 minutes per playthrough
