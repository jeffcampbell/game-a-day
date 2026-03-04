#!/usr/bin/env python3
"""Count PICO-8 tokens in a .p8 cartridge file.

Usage: python3 tools/p8tokens.py games/YYYY-MM-DD/game.p8

Output: TOKENS: 6432/8192
        TOKENS: 10486/8192 — OVER LIMIT

Tokenizer rules match PICO-8's internal counter:
  1 token: identifiers, keywords (except local/end), numbers, strings,
           opening brackets ([{, operators
  0 tokens: local, end, closing brackets )]], commas, dots, colons,
            semicolons, comments, whitespace
  Compound operators (+=, >>=, etc.) = 1 token
  Unary -/~ before a numeric literal = free (merged into the number)
"""

import re
import sys

TOKEN_LIMIT = 8192

# PICO-8 keywords that cost 1 token (local and end are free)
KEYWORDS = {
    "and", "break", "do", "else", "elseif", "false", "for", "function",
    "goto", "if", "in", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
}

FREE_KEYWORDS = {"local", "end"}

# Opening brackets cost 1 token; closing brackets are free
OPENING_BRACKETS = {"(", "[", "{"}
CLOSING_BRACKETS = {")", "]", "}"}

# Free punctuation
FREE_PUNCT = {",", ".", ":", ";"}

# Compound operators (matched greedily, longest first)
COMPOUND_OPS = sorted([
    "+=", "-=", "*=", "/=", "\\=", "%=", "^=",
    "..=", "|=", "&=", "^^=", "<<=", ">>=", ">>>=",
    "<<", ">>", ">>>", ">=", "<=", "~=", "!=", "==",
    "..", "&&", "||",
], key=len, reverse=True)

# Single-char operators (cost 1 token each)
SINGLE_OPS = {"+", "-", "*", "/", "\\", "%", "^", "#", "~", "<", ">", "=",
              "@", "$", "&", "|", "?"}


def extract_lua(text):
    """Extract all Lua code from a .p8 file (handles tabbed cartridges)."""
    lines = text.split("\n")
    lua_lines = []
    in_lua = False
    for line in lines:
        if line.startswith("__lua__"):
            in_lua = True
            continue
        if in_lua and re.match(r"^__[a-z]+__\s*$", line):
            in_lua = False
            continue
        if in_lua:
            lua_lines.append(line)
    return "\n".join(lua_lines)


def tokenize(lua_code):
    """Count tokens in PICO-8 Lua code. Returns token count."""
    pos = 0
    n = len(lua_code)
    count = 0
    prev_token_type = None  # track for unary minus/tilde

    while pos < n:
        # Skip whitespace
        if lua_code[pos] in " \t\r\n":
            pos += 1
            continue

        # Single-line comment
        if lua_code[pos:pos+2] == "--":
            if lua_code[pos+2:pos+4] == "[[":
                # Long comment --[[ ... ]]
                end = lua_code.find("]]", pos + 4)
                pos = end + 2 if end != -1 else n
            else:
                end = lua_code.find("\n", pos)
                pos = end if end != -1 else n
            continue

        # Long string [[ ... ]]
        if lua_code[pos:pos+2] == "[[" or re.match(r"\[=+\[", lua_code[pos:pos+10]):
            m = re.match(r"\[(=*)\[", lua_code[pos:])
            if m:
                eq = m.group(1)
                close = "]" + eq + "]"
                end = lua_code.find(close, pos + len(m.group(0)))
                pos = end + len(close) if end != -1 else n
                count += 1
                prev_token_type = "string"
                continue

        # String literals
        if lua_code[pos] in ('"', "'"):
            quote = lua_code[pos]
            pos += 1
            while pos < n and lua_code[pos] != quote:
                if lua_code[pos] == "\\":
                    pos += 1  # skip escaped char
                pos += 1
            pos += 1  # skip closing quote
            count += 1
            prev_token_type = "string"
            continue

        # Numbers (hex, binary, decimal with optional fractional/exponent)
        num_match = re.match(
            r"0[xX][0-9a-fA-F]*\.?[0-9a-fA-F]*|"
            r"0[bB][01]+|"
            r"[0-9]+\.?[0-9]*(?:[eE][+-]?[0-9]+)?|"
            r"\.[0-9]+(?:[eE][+-]?[0-9]+)?",
            lua_code[pos:]
        )
        if num_match and (not lua_code[pos].isalpha() or lua_code[pos] in "0."):
            if lua_code[pos] == "." and (pos + 1 >= n or not lua_code[pos+1].isdigit()):
                pass  # not a number, fall through to punctuation
            else:
                pos += num_match.end()
                count += 1
                prev_token_type = "number"
                continue

        # Identifiers and keywords
        id_match = re.match(r"[a-zA-Z_][a-zA-Z0-9_]*", lua_code[pos:])
        if id_match:
            word = id_match.group(0)
            pos += len(word)
            if word in FREE_KEYWORDS:
                prev_token_type = "keyword_free"
            elif word in KEYWORDS:
                count += 1
                prev_token_type = "keyword"
            else:
                count += 1
                prev_token_type = "identifier"
            continue

        # Brackets
        if lua_code[pos] in OPENING_BRACKETS:
            count += 1
            prev_token_type = "open_bracket"
            pos += 1
            continue

        if lua_code[pos] in CLOSING_BRACKETS:
            # free
            prev_token_type = "close_bracket"
            pos += 1
            continue

        # Free punctuation
        if lua_code[pos] in FREE_PUNCT:
            # Dot could be start of .. or ..= operator
            if lua_code[pos] == ".":
                matched_op = False
                for op in COMPOUND_OPS:
                    if lua_code[pos:pos+len(op)] == op:
                        # Check for unary minus/tilde before number
                        count += 1
                        prev_token_type = "operator"
                        pos += len(op)
                        matched_op = True
                        break
                if matched_op:
                    continue
            prev_token_type = "punct"
            pos += 1
            continue

        # Compound operators (check before single operators)
        matched_op = False
        for op in COMPOUND_OPS:
            if lua_code[pos:pos+len(op)] == op:
                count += 1
                prev_token_type = "operator"
                pos += len(op)
                matched_op = True
                break
        if matched_op:
            continue

        # Unary minus/tilde before a numeric literal = free
        if lua_code[pos] in "-~":
            # Check if this is unary (previous token is operator, open bracket,
            # keyword, comma, or start of expression)
            if prev_token_type in (None, "operator", "open_bracket", "keyword",
                                    "keyword_free", "punct", "compound_op"):
                # Look ahead past whitespace for a number
                ahead = pos + 1
                while ahead < n and lua_code[ahead] in " \t":
                    ahead += 1
                num_ahead = re.match(
                    r"0[xX][0-9a-fA-F]*\.?[0-9a-fA-F]*|"
                    r"0[bB][01]+|"
                    r"[0-9]+\.?[0-9]*(?:[eE][+-]?[0-9]+)?|"
                    r"\.[0-9]+(?:[eE][+-]?[0-9]+)?",
                    lua_code[ahead:]
                )
                if num_ahead:
                    # Free unary, skip it — the number will be counted
                    pos += 1
                    prev_token_type = "operator"
                    continue

        # Single-char operators
        if lua_code[pos] in SINGLE_OPS:
            count += 1
            prev_token_type = "operator"
            pos += 1
            continue

        # Unknown character — skip
        pos += 1

    return count


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/p8tokens.py <game.p8>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    try:
        with open(path) as f:
            text = f.read()
    except FileNotFoundError:
        print(f"Error: {path} not found", file=sys.stderr)
        sys.exit(1)

    lua = extract_lua(text)
    tokens = tokenize(lua)

    if tokens > TOKEN_LIMIT:
        print(f"TOKENS: {tokens}/{TOKEN_LIMIT} — OVER LIMIT")
        sys.exit(1)
    else:
        print(f"TOKENS: {tokens}/{TOKEN_LIMIT}")


if __name__ == "__main__":
    main()
