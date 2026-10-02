#!/usr/bin/env python3
"""Lightweight Lua block-structure checker.

Purpose: catch the block-nesting mistakes that make an REFramework probe fail to
load. This is NOT a full Lua parser; it validates block keyword balance after
removing comments and string literals, and reports the block stack on failure.

Usage: python check_lua_blocks.py <file.lua> [more.lua ...]
Exit code 0 = balanced, 1 = problem found.
"""
from __future__ import annotations

import re
import sys


def strip_comments_and_strings(src: str) -> str:
    """Replace comment and string contents with spaces, preserving newlines."""
    out: list[str] = []
    i = 0
    n = len(src)
    # Stack of open long-bracket levels, e.g. ']]' or ']==]'
    while i < n:
        ch = src[i]

        # Long bracket string or long comment: [[ ... ]] or [=*[
        if ch == "[":
            m = re.match(r"\[(=*)\[", src[i:])
            if m:
                eq = m.group(1)
                close = "]" + eq + "]"
                end = src.find(close, i + len(m.group(0)))
                if end == -1:
                    out.append(" " * (n - i))
                    break
                block = src[i:end + len(close)]
                out.append("".join("\n" if c == "\n" else " " for c in block))
                i = end + len(close)
                continue

        # Short comment
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                eq = m.group(1)
                close = "]" + eq + "]"
                end = src.find(close, i + len(m.group(0)))
                if end == -1:
                    out.append(" " * (n - i))
                    break
                block = src[i:end + len(close)]
                out.append("".join("\n" if c == "\n" else " " for c in block))
                i = end + len(close)
                continue
            end = src.find("\n", i)
            if end == -1:
                out.append(" " * (n - i))
                break
            out.append(" " * (end - i))
            i = end
            continue

        # Short string
        if ch in ("'", '"'):
            quote = ch
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == quote:
                    break
                if src[j] == "\n":
                    break
                j += 1
            j = min(j + 1, n)
            block = src[i:j]
            out.append("".join("\n" if c == "\n" else " " for c in block))
            i = j
            continue

        out.append(ch)
        i += 1

    return "".join(out)


# Words that open a block requiring 'end'
OPEN_END = {"function", "if", "for", "while", "do"}


def check(path: str) -> bool:
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()

    code = strip_comments_and_strings(raw)
    lines = code.split("\n")

    stack: list[tuple[str, int]] = []
    problems: list[str] = []

    for lineno, line in enumerate(lines, start=1):
        # Tokenize words only
        for m in re.finditer(r"\b[A-Za-z_][A-Za-z0-9_]*\b", line):
            word = m.group(0)
            if word in ("function", "if", "for", "while", "repeat"):
                stack.append((word, lineno))
            elif word == "do":
                # 'do' closes the header of for/while, so only push when it is a
                # standalone do-block (not preceded by for/while on the stack top
                # in this same statement). Simpler: treat for/while/do as one unit
                # by popping the for/while header here.
                if stack and stack[-1][0] in ("for", "while"):
                    pass  # header consumed; block opened by for/while itself
                else:
                    stack.append(("do", lineno))
            elif word == "then":
                # 'then' completes an 'if' header; the if already pushed.
                pass
            elif word == "end":
                if not stack:
                    problems.append(f"line {lineno}: 'end' with no open block")
                else:
                    stack.pop()
            elif word == "until":
                # repeat ... until
                if stack and stack[-1][0] == "repeat":
                    stack.pop()
                elif not stack:
                    problems.append(f"line {lineno}: 'until' with no open repeat")
                else:
                    problems.append(
                        f"line {lineno}: 'until' but top of stack is "
                        f"'{stack[-1][0]}' from line {stack[-1][1]}"
                    )

    if stack:
        for kind, lineno in stack:
            problems.append(f"unclosed '{kind}' opened at line {lineno}")

    if problems:
        print(f"FAIL {path}")
        for p in problems:
            print("   ", p)
        return False

    print(f"OK   {path} (block structure balanced)")
    return True


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    all_ok = True
    for path in argv[1:]:
        if not check(path):
            all_ok = False
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
