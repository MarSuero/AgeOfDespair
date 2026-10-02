#!/usr/bin/env python3
"""Static sanity checks for REFramework Lua probes.

Why this exists: this machine has no Lua interpreter, so a probe cannot be run
or fully parsed before it is deployed into the game. The block-structure checker
(tools/rsz_local/check_lua_blocks.py) only proves that end/if/for/do balance.

This script adds the two failure modes that actually bite during probe writing:

  1. Use of a global that was never defined (typo'd local name). In Lua a typo'd
     local silently becomes a nil global read, so the probe loads but misbehaves.
  2. Calls to a local function with the wrong number of arguments.

It is intentionally approximate: it strips comments and strings, collects
`local function` / `function` definitions and `local` bindings, and reports
identifier uses that resolve to nothing known. Lua standard globals and the
REFramework API surface are allowlisted.

Usage: python check_lua_sanity.py <file.lua> [...]
Exit code 0 = no findings, 1 = findings.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_lua_blocks import strip_comments_and_strings  # noqa: E402

# Lua standard library and keywords.
LUA_GLOBALS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
    "assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs",
    "load", "loadfile", "next", "pairs", "pcall", "print", "rawequal", "rawget",
    "rawlen", "rawset", "require", "select", "setmetatable", "tonumber",
    "tostring", "type", "xpcall", "coroutine", "debug", "io", "math", "os",
    "string", "table", "utf8", "_G", "_VERSION", "self", "arg", "unpack",
}

# REFramework Lua API surface used by this project.
REFRAMEWORK_GLOBALS = {
    "re", "sdk", "log", "json", "fs", "draw", "imgui", "d2d", "ValueType",
    "thread", "REPlus", "reframework",
}

KNOWN_GLOBALS = LUA_GLOBALS | REFRAMEWORK_GLOBALS

DEF_FUNC = re.compile(r"\blocal\s+function\s+([A-Za-z_]\w*)")
DEF_PLAIN_FUNC = re.compile(r"^\s*function\s+([A-Za-z_]\w*)\s*\(")
# local a, b, c = ...
DEF_LOCAL = re.compile(r"\blocal\s+([A-Za-z_][\w\s,]*?)\s*(?:=|$)", re.M)
FOR_VARS = re.compile(r"\bfor\s+([A-Za-z_][\w\s,]*?)\s+(?:=|in)\b")
PARAM_LIST = re.compile(r"\bfunction\s*[\w.:]*\s*\(([^)]*)\)")
IDENT = re.compile(r"\b([A-Za-z_]\w*)\b")


def collect_bindings(code: str) -> tuple[set[str], dict[str, int], dict[str, int]]:
    """Return (known names, function arity, function definition count).

    NOTE: `code` must be the STRIPPED text (comments/strings blanked). String
    arguments are blanked, so argument counting for call sites must instead be
    done on the raw text by the caller.
    """
    names: set[str] = set()
    arity: dict[str, int] = {}
    defined: dict[str, int] = {}

    for m in DEF_FUNC.finditer(code):
        names.add(m.group(1))

    for m in DEF_PLAIN_FUNC.finditer(code):
        names.add(m.group(1))

    # local declarations (may be comma separated, may be function values)
    for m in DEF_LOCAL.finditer(code):
        for part in m.group(1).split(","):
            part = part.strip()
            if re.fullmatch(r"[A-Za-z_]\w*", part):
                names.add(part)

    # loop variables
    for m in FOR_VARS.finditer(code):
        for part in m.group(1).split(","):
            part = part.strip()
            if re.fullmatch(r"[A-Za-z_]\w*", part):
                names.add(part)

    # function parameters
    for m in PARAM_LIST.finditer(code):
        for part in m.group(1).split(","):
            part = part.strip()
            if re.fullmatch(r"[A-Za-z_]\w*", part):
                names.add(part)

    # arity of local functions: `local function f(a, b)` or `= function(a, b)`.
    # Functions declared with `...` accept variable arguments; record them as
    # variadic (-1) so the arity check never flags a legitimate call.
    for m in re.finditer(r"\blocal\s+function\s+([A-Za-z_]\w*)\s*\(([^)]*)\)", code):
        name, params = m.group(1), m.group(2)
        parts = [p.strip() for p in params.split(",") if p.strip()]
        if "..." in parts:
            arity[name] = -1
        else:
            arity[name] = len(parts)
        defined[name] = defined.get(name, 0) + 1

    return names, arity, defined


def split_args(raw_args: str) -> list[str]:
    """Split a raw (unstripped) argument list on top-level commas.

    Strings and nested brackets are respected so that
    `lookup("a", "b")` yields 2 arguments rather than 0.
    """
    args: list[str] = []
    depth = 0
    quote: str | None = None
    current: list[str] = []
    i = 0
    while i < len(raw_args):
        ch = raw_args[i]
        if quote:
            current.append(ch)
            if ch == "\\":
                if i + 1 < len(raw_args):
                    current.append(raw_args[i + 1])
                    i += 2
                    continue
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            current.append(ch)
        elif ch in "([{":
            depth += 1
            current.append(ch)
        elif ch in ")]}":
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
        i += 1
    tail = "".join(current).strip()
    if tail:
        args.append(tail)
    return args


def extract_call_args(raw: str, name: str) -> list[tuple[int, str]]:
    """Find `name(...)` call sites in raw text; return (line, arg_blob)."""
    out: list[tuple[int, str]] = []
    for m in re.finditer(r"\b" + re.escape(name) + r"\s*\(", raw):
        # skip the definition site
        before = raw[max(0, m.start() - 22):m.start()]
        if "function" in before:
            continue
        # find the matching close paren, respecting strings and nesting
        start = m.end() - 1
        depth = 0
        quote = None
        i = start
        while i < len(raw):
            ch = raw[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
                i += 1
                continue
            if ch in ("'", '"'):
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        blob = raw[start + 1:i]
        line_no = raw[:m.start()].count("\n") + 1
        out.append((line_no, blob))
    return out


def check_file(path: str) -> bool:
    raw = Path(path).read_text(encoding="utf-8")
    code = strip_comments_and_strings(raw)

    names, arity, _ = collect_bindings(code)
    known = names | KNOWN_GLOBALS

    findings: list[str] = []

    # 1. Unknown identifiers that are used as values/method receivers.
    #    Only flag identifiers followed by '(', ':' or '.' to cut false positives,
    #    and never flag a name that is assigned anywhere with '='.
    assigned = set(re.findall(r"\b([A-Za-z_]\w*)\s*=[^=]", code))
    for m in re.finditer(r"\b([A-Za-z_]\w*)\s*[(:.]", code):
        name = m.group(1)
        if name in known or name in assigned:
            continue
        # skip table field accesses like obj.field(
        prefix = code[max(0, m.start() - 1):m.start()]
        if prefix in (".", ":"):
            continue
        line_no = code[:m.start()].count("\n") + 1
        findings.append(
            f"line {line_no}: '{name}' used but never defined "
            f"(typo'd local or missing declaration)")

    # 2. Local function arity mismatches, counted on the RAW text so that
    #    string arguments are not invisible.
    for name, expected in arity.items():
        if expected < 0:
            continue  # variadic; any argument count is acceptable
        for line_no, blob in extract_call_args(raw, name):
            # A call whose argument is an inline function body or a table
            # constructor spans structure this lightweight splitter does not
            # model; skip those rather than report a false mismatch.
            if re.search(r"\bfunction\b", blob):
                continue
            args = split_args(blob)
            if len(args) != expected:
                findings.append(
                    f"line {line_no}: '{name}' expects {expected} arg(s), "
                    f"called with {len(args)}")

    # De-duplicate while preserving order.
    seen = set()
    unique = []
    for f in findings:
        if f not in seen:
            seen.add(f)
            unique.append(f)

    if unique:
        print(f"FINDINGS {path}")
        for f in unique:
            print("   ", f)
        return False

    print(f"OK       {path} (no undefined identifiers or arity mismatches)")
    return True


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    ok = True
    for path in argv[1:]:
        if not check_file(path):
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
