#!/usr/bin/env python3
"""Validate Dungeon Crawler RPG difficulty balance against playtest targets.

Analyzes recorded playtest sessions and compares actual results against
predicted difficulty targets from assessment.md.

Usage:
  python3 tools/validate-dungeon-balance.py 2026-03-09
"""

import sys
import json
from pathlib import Path
from collections import defaultdict


def analyze_difficulty_results(game_date):
    """Analyze playtest results by difficulty level.

    Returns:
        dict with per-difficulty analysis and comparison to targets
    """

    game_dir = Path(f"games/{game_date}")
    sessions = list(game_dir.glob("session_*.json"))

    # Parse difficulty from filename
    results = defaultdict(lambda: {"sessions": [], "wins": 0, "losses": 0, "quits": 0})

    for session_file in sorted(sessions):
        try:
            with open(session_file) as f:
                session = json.load(f)

            # Extract difficulty from filename (easy/normal/hard)
            filename = session_file.stem
            parts = filename.split("_")

            difficulty = None
            outcome = None

            # Find difficulty and outcome in filename
            for part in parts:
                if part in ("easy", "normal", "hard"):
                    difficulty = part
                elif part in ("win", "loss", "quit"):
                    outcome = part

            if not difficulty or not outcome:
                continue

            # Get exit state from session
            exit_state = session.get("exit_state", outcome)
            duration_sec = session.get("duration_frames", 0) / 60.0

            results[difficulty]["sessions"].append({
                "file": session_file.name,
                "outcome": outcome,
                "exit_state": exit_state,
                "duration_sec": duration_sec,
                "logs": session.get("logs", [])
            })

            if outcome == "win":
                results[difficulty]["wins"] += 1
            elif outcome == "loss":
                results[difficulty]["losses"] += 1
            elif outcome == "quit":
                results[difficulty]["quits"] += 1

        except Exception as e:
            print(f"Error parsing {session_file.name}: {e}", file=sys.stderr)
            continue

    return results


def generate_validation_report(game_date):
    """Generate detailed validation report."""

    results = analyze_difficulty_results(game_date)

    # Target win rates from assessment.md
    targets = {
        "easy": {"target_win_rate": 0.70, "target_range": "70%+"},
        "normal": {"target_win_rate": 0.65, "target_range": "60-70%"},
        "hard": {"target_win_rate": 0.45, "target_range": "40-50%"}
    }

    report = []
    report.append("# Dungeon Crawler RPG - Difficulty Balance Validation Report")
    report.append("")
    report.append(f"Generated: {game_date}")
    report.append("")
    report.append("## Executive Summary")
    report.append("")

    total_sessions = sum(len(r["sessions"]) for r in results.values())
    total_wins = sum(r["wins"] for r in results.values())
    overall_win_rate = total_wins / total_sessions if total_sessions > 0 else 0

    report.append(f"**Total Sessions:** {total_sessions}")
    report.append(f"**Overall Win Rate:** {overall_win_rate:.0%}")
    report.append("")

    report.append("## Difficulty-Specific Results")
    report.append("")

    for difficulty in ["easy", "normal", "hard"]:
        if difficulty not in results:
            continue

        diff_data = results[difficulty]
        num_sessions = len(diff_data["sessions"])
        win_rate = diff_data["wins"] / num_sessions if num_sessions > 0 else 0

        target = targets[difficulty]
        target_rate = target["target_win_rate"]
        target_range = target["target_range"]

        report.append(f"### {difficulty.upper()} Mode")
        report.append("")
        report.append(f"**Target Win Rate:** {target_range} (expected {target_rate:.0%})")
        report.append(f"**Actual Win Rate:** {diff_data['wins']}/{num_sessions} sessions = {win_rate:.0%}")
        report.append("")

        # Performance assessment
        if win_rate >= target_rate:
            status = "✅ MEETS TARGET"
            assessment = "Difficulty is appropriately balanced."
        elif win_rate >= target_rate * 0.9:
            status = "⚠️  SLIGHTLY UNDER"
            assessment = "Win rate is slightly lower than target. Monitor for patterns."
        else:
            status = "❌ SIGNIFICANTLY UNDER"
            assessment = "Win rate is substantially below target. Difficulty may be too high."

        report.append(f"**Status:** {status}")
        report.append(f"**Assessment:** {assessment}")
        report.append("")

        # Breakdown by outcome
        report.append(f"**Outcome Breakdown:**")
        report.append(f"- Wins: {diff_data['wins']}")
        report.append(f"- Losses: {diff_data['losses']}")
        report.append(f"- Quits: {diff_data['quits']}")
        report.append("")

        # Session details
        report.append(f"**Session Details:**")
        for i, session in enumerate(diff_data["sessions"], 1):
            duration = session["duration_sec"]
            outcome = session["outcome"]
            report.append(f"{i}. {session['file']:50} {outcome:6} {duration:6.1f}s")

        report.append("")

    report.append("## Validation Against Assessment Targets")
    report.append("")

    # Check combat balance predictions
    report.append("### Boss Pacing Validation")
    report.append("")
    report.append("Expected turn counts from assessment.md:")
    report.append("- Easy: 10-15 turns per boss")
    report.append("- Normal: 15-20 turns per boss")
    report.append("- Hard: 20-25 turns per boss")
    report.append("")
    report.append("*Note: Actual turn counts not directly visible in session logs.*")
    report.append("*Can be inferred from session duration and log frequency.*")
    report.append("")

    # Check consumable usage
    report.append("### Resource Usage Validation")
    report.append("")
    report.append("Starting resources per assessment.md:")
    report.append("- Easy: 3 potions, 2 antidotes, 2 cure scrolls")
    report.append("- Normal: 2 potions, 1 antidote, 1 cure scroll")
    report.append("- Hard: 1 potion, 0 antidotes, 0 cure scrolls")
    report.append("")

    for difficulty in ["easy", "normal", "hard"]:
        if difficulty not in results:
            continue

        diff_data = results[difficulty]
        report.append(f"**{difficulty.upper()}** - Consumable patterns detected:")

        # Count mentions of consumable usage in logs
        potion_uses = 0
        antidote_uses = 0
        cure_uses = 0

        for session in diff_data["sessions"]:
            for log in session["logs"]:
                if "potion" in log.lower():
                    potion_uses += 1
                if "antidote" in log.lower():
                    antidote_uses += 1
                if "cure" in log.lower():
                    cure_uses += 1

        report.append(f"- Potion usage: {potion_uses} mentions across {len(diff_data['sessions'])} sessions")
        report.append(f"- Antidote usage: {antidote_uses} mentions across {len(diff_data['sessions'])} sessions")
        report.append(f"- Cure usage: {cure_uses} mentions across {len(diff_data['sessions'])} sessions")
        report.append("")

    report.append("## Combat Feel Improvements Validation")
    report.append("")
    report.append("Assessment documented these improvements:")
    report.append("- Damage numbers: Black outline for visibility")
    report.append("- Status indicators: Background boxes (POI/STN/PAR)")
    report.append("- Action feedback: Clearer messages")
    report.append("- Ability messages: More descriptive")
    report.append("- Screen shake: Tuned to be responsive without jarring")
    report.append("")
    report.append("*Validation note: These are visual improvements best assessed through*")
    report.append("*interactive playtesting. Session logs provide behavior validation.*")
    report.append("")

    report.append("## Key Findings")
    report.append("")

    key_findings = []

    # Analysis 1: Win rate achievement
    for difficulty in ["easy", "normal", "hard"]:
        if difficulty not in results:
            continue

        diff_data = results[difficulty]
        num_sessions = len(diff_data["sessions"])
        win_rate = diff_data["wins"] / num_sessions if num_sessions > 0 else 0
        target_rate = targets[difficulty]["target_win_rate"]

        if win_rate >= target_rate * 1.1:
            key_findings.append(f"✅ {difficulty.upper()}: Win rate {win_rate:.0%} exceeds target {target_rate:.0%}")
        elif win_rate >= target_rate * 0.9:
            key_findings.append(f"✅ {difficulty.upper()}: Win rate {win_rate:.0%} within 10% of target {target_rate:.0%}")
        elif win_rate >= target_rate * 0.8:
            key_findings.append(f"⚠️  {difficulty.upper()}: Win rate {win_rate:.0%} is {(1-win_rate/target_rate)*100:.0f}% below target {target_rate:.0%}")
        else:
            key_findings.append(f"❌ {difficulty.upper()}: Win rate {win_rate:.0%} significantly below target {target_rate:.0%}")

    for finding in key_findings:
        report.append(f"- {finding}")

    report.append("")
    report.append("## Recommendations")
    report.append("")
    report.append("### For Future Iteration")
    report.append("")
    report.append("1. **Continue interactive testing** - Record additional sessions via")
    report.append("   `python3 tools/run-interactive-test.py 2026-03-09 --record`")
    report.append("")
    report.append("2. **Monitor specific bosses** - Identify which bosses have the highest")
    report.append("   failure rates within each difficulty")
    report.append("")
    report.append("3. **Track consumable effectiveness** - Validate that Easy mode's")
    report.append("   increased resources are being used and improving win rates")
    report.append("")
    report.append("4. **A/B test difficulty adjustments** - If target win rates not achieved,")
    report.append("   consider small tweaks to difficulty scaling and retest")
    report.append("")

    report.append("## Conclusion")
    report.append("")
    report.append("This validation report provides a quantitative baseline for assessing")
    report.append("Dungeon Crawler's difficulty balance. The balance changes documented in")
    report.append("assessment.md have been implemented and recorded. Further playtesting")
    report.append("with human players is recommended to validate perceived difficulty and")
    report.append("fun factor alongside these mechanical balance metrics.")
    report.append("")

    return "\n".join(report)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/validate-dungeon-balance.py <game_date>")
        sys.exit(1)

    game_date = sys.argv[1]
    game_dir = Path(f"games/{game_date}")

    if not game_dir.exists():
        print(f"Error: Game directory {game_dir} not found")
        sys.exit(1)

    # Generate report
    report = generate_validation_report(game_date)
    print(report)

    # Save to file
    report_file = game_dir / "balance-validation-report.md"
    with open(report_file, 'w') as f:
        f.write(report)

    print(f"\n✅ Report saved to {report_file}")


if __name__ == "__main__":
    main()
