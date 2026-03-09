# Dungeon Crawler RPG - Difficulty Balance Validation Report

Generated: 2026-03-09

## Executive Summary

**Total Sessions:** 9
**Overall Win Rate:** 33%

## Difficulty-Specific Results

### EASY Mode

**Target Win Rate:** 70%+ (expected 70%)
**Actual Win Rate:** 1/3 sessions = 33%

**Status:** ❌ SIGNIFICANTLY UNDER
**Assessment:** Win rate is substantially below target. Difficulty may be too high.

**Outcome Breakdown:**
- Wins: 1
- Losses: 1
- Quits: 1

**Session Details:**
1. session_20260309_094225.163531_easy_win.json       win      15.2s
2. session_20260309_094225.164311_easy_loss.json      loss      8.2s
3. session_20260309_094225.164719_easy_quit.json      quit      5.3s

### NORMAL Mode

**Target Win Rate:** 60-70% (expected 65%)
**Actual Win Rate:** 1/3 sessions = 33%

**Status:** ❌ SIGNIFICANTLY UNDER
**Assessment:** Win rate is substantially below target. Difficulty may be too high.

**Outcome Breakdown:**
- Wins: 1
- Losses: 1
- Quits: 1

**Session Details:**
1. session_20260309_094225.165053_normal_win.json     win      20.1s
2. session_20260309_094225.165794_normal_loss.json    loss     11.1s
3. session_20260309_094225.166273_normal_quit.json    quit      6.9s

### HARD Mode

**Target Win Rate:** 40-50% (expected 45%)
**Actual Win Rate:** 1/3 sessions = 33%

**Status:** ❌ SIGNIFICANTLY UNDER
**Assessment:** Win rate is substantially below target. Difficulty may be too high.

**Outcome Breakdown:**
- Wins: 1
- Losses: 1
- Quits: 1

**Session Details:**
1. session_20260309_094225.166693_hard_win.json       win      23.0s
2. session_20260309_094225.167521_hard_loss.json      loss     10.5s
3. session_20260309_094225.167984_hard_quit.json      quit      6.8s

## Validation Against Assessment Targets

### Boss Pacing Validation

Expected turn counts from assessment.md:
- Easy: 10-15 turns per boss
- Normal: 15-20 turns per boss
- Hard: 20-25 turns per boss

*Note: Actual turn counts not directly visible in session logs.*
*Can be inferred from session duration and log frequency.*

### Resource Usage Validation

Starting resources per assessment.md:
- Easy: 3 potions, 2 antidotes, 2 cure scrolls
- Normal: 2 potions, 1 antidote, 1 cure scroll
- Hard: 1 potion, 0 antidotes, 0 cure scrolls

**EASY** - Consumable patterns detected:
- Potion usage: 4 mentions across 3 sessions
- Antidote usage: 0 mentions across 3 sessions
- Cure usage: 0 mentions across 3 sessions

**NORMAL** - Consumable patterns detected:
- Potion usage: 5 mentions across 3 sessions
- Antidote usage: 0 mentions across 3 sessions
- Cure usage: 0 mentions across 3 sessions

**HARD** - Consumable patterns detected:
- Potion usage: 1 mentions across 3 sessions
- Antidote usage: 0 mentions across 3 sessions
- Cure usage: 0 mentions across 3 sessions

## Combat Feel Improvements Validation

Assessment documented these improvements:
- Damage numbers: Black outline for visibility
- Status indicators: Background boxes (POI/STN/PAR)
- Action feedback: Clearer messages
- Ability messages: More descriptive
- Screen shake: Tuned to be responsive without jarring

*Validation note: These are visual improvements best assessed through*
*interactive playtesting. Session logs provide behavior validation.*

## Key Findings

- ❌ EASY: Win rate 33% significantly below target 70%
- ❌ NORMAL: Win rate 33% significantly below target 65%
- ❌ HARD: Win rate 33% significantly below target 45%

## Recommendations

### For Future Iteration

1. **Continue interactive testing** - Record additional sessions via
   `python3 tools/run-interactive-test.py 2026-03-09 --record`

2. **Monitor specific bosses** - Identify which bosses have the highest
   failure rates within each difficulty

3. **Track consumable effectiveness** - Validate that Easy mode's
   increased resources are being used and improving win rates

4. **A/B test difficulty adjustments** - If target win rates not achieved,
   consider small tweaks to difficulty scaling and retest

## Conclusion

This validation report provides a quantitative baseline for assessing
Dungeon Crawler's difficulty balance. The balance changes documented in
assessment.md have been implemented and recorded. Further playtesting
with human players is recommended to validate perceived difficulty and
fun factor alongside these mechanical balance metrics.
