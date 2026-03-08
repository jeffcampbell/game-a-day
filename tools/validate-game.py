#!/usr/bin/env python3
"""Validate PICO-8 game files for architecture, cartridge sections, test infrastructure, and token budget.

Usage: python3 tools/validate-game.py games/YYYY-MM-DD/game.p8

Checks:
  - State machine pattern (state variable, _update/_draw with branching)
  - Required cartridge sections (__lua__, __gfx__, __label__)
  - Test infrastructure (testmode, test_log, _log(), test_input(), _capture())
  - Logging at key points (state transitions, scores, gameovers)
  - Token budget (<= 8192, warn at 90%)
  - Exportability (valid __label__ section, non-empty code)
"""

import re
import sys
import os
import subprocess


def read_file(path):
    """Read a .p8 file, return content or None on error."""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return None
    except Exception as e:
        return None


def extract_section(content, section_name):
    """Extract content between __section__ markers."""
    lines = content.split("\n")
    section_lines = []
    in_section = False

    for line in lines:
        if line.startswith(f"__{section_name}__"):
            in_section = True
            continue
        if in_section and re.match(r"^__[a-z]+__\s*$", line):
            in_section = False
            continue
        if in_section:
            section_lines.append(line)

    return "\n".join(section_lines)


def check_state_machine(lua_code):
    """Verify state machine pattern: state variable, _update/_draw with branching."""
    checks = {
        "state_var": False,
        "update_func": False,
        "draw_func": False,
        "required_states": set()
    }

    # Check for state variable declaration
    if re.search(r'\bstate\s*=\s*["\']', lua_code):
        checks["state_var"] = True

    # Check for _update function with state branching (if/elseif chains)
    if re.search(r'function\s+_update\s*\(', lua_code):
        checks["update_func"] = True
        # Look for state-based branching
        if re.search(r'if\s+state\s*==|elseif\s+state\s*==', lua_code):
            # Find all state strings in conditionals
            state_matches = re.findall(r'state\s*==\s*["\']([^"\']+)["\']', lua_code)
            checks["required_states"].update(state_matches)

    # Check for _draw function with state branching
    if re.search(r'function\s+_draw\s*\(', lua_code):
        checks["draw_func"] = True

    return checks


def check_cartridge_sections(content):
    """Verify required cartridge sections are present."""
    checks = {
        "has_lua": False,
        "has_gfx": False,
        "has_label": False
    }

    checks["has_lua"] = "__lua__" in content
    checks["has_gfx"] = "__gfx__" in content
    checks["has_label"] = "__label__" in content

    return checks


def validate_label_section(content):
    """Validate __label__ section format (128 rows of 128 hex digits)."""
    label = extract_section(content, "label")
    lines = [l for l in label.split("\n") if l.strip()]

    if len(lines) < 128:
        return False, f"__label__ has {len(lines)} rows, need 128"

    for i, line in enumerate(lines[:128]):
        # Check if line has 128 hex digits
        if len(line) != 128:
            return False, f"__label__ row {i+1} has {len(line)} chars, need 128"
        if not all(c in "0123456789abcdefABCDEF" for c in line):
            return False, f"__label__ row {i+1} contains non-hex characters"

    return True, None


def check_test_infrastructure(lua_code):
    """Verify test infrastructure functions and variables."""
    checks = {
        "testmode": False,
        "test_log": False,
        "test_input_idx": False,
        "_log": False,
        "_capture": False,
        "test_input": False
    }

    checks["testmode"] = "testmode" in lua_code
    checks["test_log"] = "test_log" in lua_code
    checks["test_input_idx"] = "test_input_idx" in lua_code
    checks["_log"] = "function _log" in lua_code
    checks["_capture"] = "function _capture" in lua_code
    checks["test_input"] = "function test_input" in lua_code

    return checks


def check_logging(lua_code):
    """Verify _log calls at key points."""
    checks = {
        "state_transition": False,
        "score_progress": False,
        "game_event": False,
        "gameover": False,
        "total_logs": 0
    }

    # Count all _log calls (handle both simple strings and concatenated strings)
    log_calls = re.findall(r'_log\s*\(\s*["\']([^"\']+)["\']', lua_code)
    checks["total_logs"] = len(log_calls)

    # Check for specific log types
    for log_msg in log_calls:
        if "state:" in log_msg:
            checks["state_transition"] = True
            # Check for gameover state
            if "state:gameover" in log_msg:
                checks["gameover"] = True
        if "score:" in log_msg or "progress" in log_msg.lower():
            checks["score_progress"] = True
        if "gameover:" in log_msg:
            checks["gameover"] = True
        # Any other log counts as game event
        if not ("state:" in log_msg or "score:" in log_msg or "progress" in log_msg.lower() or "gameover:" in log_msg):
            checks["game_event"] = True

    # If no specific game event, check if there are enough generic logs
    if checks["total_logs"] >= 5:
        checks["game_event"] = True

    return checks


def check_token_count(game_path):
    """Run p8tokens.py to check token count."""
    try:
        # Find p8tokens.py relative to tools directory
        tool_dir = os.path.dirname(game_path)
        base_dir = os.path.dirname(os.path.dirname(tool_dir))
        tokens_script = os.path.join(base_dir, "tools", "p8tokens.py")

        if not os.path.exists(tokens_script):
            return None, "p8tokens.py not found"

        result = subprocess.run(
            ["python3", tokens_script, game_path],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Parse output: "TOKENS: 3450/8192"
        match = re.search(r"TOKENS:\s*(\d+)/(\d+)", result.stdout)
        if match:
            tokens = int(match.group(1))
            limit = int(match.group(2))
            return tokens, None

        return None, "Could not parse token count"
    except Exception as e:
        return None, str(e)


def check_exportability(lua_code):
    """Verify game can export to HTML."""
    checks = {
        "has_code": len(lua_code.strip()) > 100,
        "label_ok": False  # Will be set by caller
    }
    return checks


def format_number(n):
    """Format number with thousands separator."""
    return f"{n:,}"


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/validate-game.py <game.p8>", file=sys.stderr)
        sys.exit(1)

    game_path = sys.argv[1]
    content = read_file(game_path)

    if content is None:
        print(f"❌ Error: Could not read {game_path}", file=sys.stderr)
        sys.exit(1)

    lua_code = extract_section(content, "lua")

    # Run all checks
    results = []

    # 1. State machine check
    state_check = check_state_machine(lua_code)
    has_state_var = state_check["state_var"]
    has_branching = state_check["update_func"] and len(state_check["required_states"]) >= 3
    required_states = {"menu", "play", "gameover"}
    found_states = state_check["required_states"]
    has_required = required_states.issubset(found_states)

    if has_state_var and has_branching and has_required:
        results.append(("✅", "Architecture: State machine pattern detected"))
    else:
        reasons = []
        if not has_state_var:
            reasons.append("no state variable found")
        if not has_branching:
            reasons.append("_update/_draw lack state branching")
        if not has_required:
            missing = required_states - found_states
            reasons.append(f"missing states: {missing}")
        results.append(("❌", f"Architecture: State machine pattern not detected ({'; '.join(reasons)})"))

    # 2. Cartridge sections check
    cart_check = check_cartridge_sections(content)
    if cart_check["has_lua"] and cart_check["has_gfx"] and cart_check["has_label"]:
        results.append(("✅", "Cartridge: All required sections present (__lua__, __gfx__, __label__)"))
    else:
        missing = []
        if not cart_check["has_lua"]:
            missing.append("__lua__")
        if not cart_check["has_gfx"]:
            missing.append("__gfx__")
        if not cart_check["has_label"]:
            missing.append("__label__")
        results.append(("❌", f"Cartridge: Missing sections ({', '.join(missing)})"))

    # 3. Test infrastructure check
    test_check = check_test_infrastructure(lua_code)
    has_all_test = all(test_check.values())

    if has_all_test:
        results.append(("✅", "Test Infrastructure: _log(), test_input(), _capture() functions found"))
    else:
        missing = [k for k, v in test_check.items() if not v]
        results.append(("❌", f"Test Infrastructure: Missing {', '.join(missing)}"))

    # 4. Logging check
    log_check = check_logging(lua_code)
    has_essential_logs = (log_check["state_transition"] and
                         log_check["gameover"] and
                         log_check["total_logs"] >= 5)

    if has_essential_logs:
        results.append(("✅", f"Logging: Found state transition, gameover, and {log_check['total_logs']} total logs"))
    else:
        missing = []
        if not log_check["state_transition"]:
            missing.append("no 'state:' logs")
        if not log_check["gameover"]:
            missing.append("no 'gameover:' logs")
        if log_check["total_logs"] < 5:
            missing.append(f"only {log_check['total_logs']} logs (need 5+)")
        results.append(("❌", f"Logging: {'; '.join(missing)}"))

    # 5. Token budget check
    tokens, token_err = check_token_count(game_path)
    token_status = "✅"
    if tokens is None:
        results.append(("⚠️ ", f"Token Budget: Could not determine ({token_err})"))
    elif tokens > 8192:
        over = tokens - 8192
        results.append(("❌", f"Token Budget: {format_number(tokens)} tokens (exceeds {format_number(8192)} by {format_number(over)})"))
    elif tokens > 7500:  # 90% warning
        pct = int(100 * tokens / 8192)
        results.append(("⚠️ ", f"Token Budget: {format_number(tokens)} tokens ({pct}% of {format_number(8192)} max)"))
    else:
        pct = int(100 * tokens / 8192)
        results.append(("✅", f"Token Budget: {format_number(tokens)} tokens ({pct}% of {format_number(8192)} max)"))

    # 6. Export readiness check
    label_valid, label_err = validate_label_section(content)
    export_check = check_exportability(lua_code)

    if label_valid and export_check["has_code"]:
        results.append(("✅", "Export Ready: __label__ section properly formatted, code present"))
    else:
        reasons = []
        if not label_valid:
            reasons.append(f"__label__ issue: {label_err}")
        if not export_check["has_code"]:
            reasons.append("code too small or empty")
        results.append(("❌", f"Export Ready: {'; '.join(reasons)}"))

    # Print results
    print()
    for status, msg in results:
        print(f"{status} {msg}")

    # Summary
    passed = sum(1 for status, _ in results if status == "✅")
    total = len(results)
    print()

    if passed == total:
        print(f"{passed}/{total} checks passed")
        sys.exit(0)
    else:
        print(f"{passed}/{total} checks passed - VALIDATION FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
