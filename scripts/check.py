#!/usr/bin/env python3
"""Static checks to run before every commit (no Swift toolchain needed).

  python3 scripts/check.py            # every tracked + untracked, non-ignored file
  python3 scripts/check.py FILE...    # only these files

Checks:
  * Swift files parse (tree-sitter-swift). Needs: pip install tree-sitter tree-sitter-swift
  * JavaScript files pass `node --check`.
  * JSON files load; .plist / .entitlements files load.
  * No Thai text inside code comments (Swift, JS, Python). Thai belongs in
    string literals, localization files, test data and docs only.

Exits non-zero if anything fails. A clean run does not mean the iOS app
compiles: only Xcode can confirm that.
"""

import io
import json
import plistlib
import re
import subprocess
import sys
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THAI = re.compile(r"[฀-๿]")
JS_EXT = {".js", ".mjs", ".cjs"}


def repo_files():
    out = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    return [ROOT / p for p in out.splitlines() if (ROOT / p).is_file()]


# In JS a "/" after one of these (or at the start) begins a regex literal,
# not a division, e.g. `if (!/^wss?:\/\//.test(url))`.
REGEX_PREV = set("(,=:[!&|?{};+-*%<>~^")


def c_like_comments(src, swift):
    """Yield (line, text) for every // and /* */ comment, skipping strings
    (and, for JS, regex literals)."""
    i, n, line = 0, len(src), 1
    state, buf, start = "code", "", 1
    quotes = {"dq": '"', "sq": "'", "tpl": "`"}
    prev, in_class = "", False
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if state == "code":
            if c == "/" and nxt == "/":
                state, buf, start = "line", "", line
                i += 2
                continue
            if c == "/" and nxt == "*":
                state, buf, start = "block", "", line
                i += 2
                continue
            if not swift and c == "/" and (prev == "" or prev in REGEX_PREV):
                state, in_class = "regex", False
                i += 1
                continue
            if swift and src.startswith('"""', i):
                state = "triple"
                i += 3
                continue
            if c == '"':
                state = "dq"
            elif c == "'" and not swift:
                state = "sq"
            elif c == "`" and not swift:
                state = "tpl"
            if not c.isspace():
                prev = c
        elif state == "regex":
            if c == "\\":
                i += 2
                continue
            if c == "[":
                in_class = True
            elif c == "]":
                in_class = False
            elif (c == "/" and not in_class) or c == "\n":
                state, prev = "code", "/"
        elif state == "line":
            if c == "\n":
                yield start, buf
                state = "code"
            else:
                buf += c
        elif state == "block":
            if c == "*" and nxt == "/":
                yield start, buf
                state = "code"
                i += 2
                continue
            buf += c
        elif state in quotes:
            if c == "\\":
                if nxt == "\n":
                    line += 1
                i += 2
                continue
            if c == quotes[state] or (c == "\n" and state != "tpl"):
                state = "code"
        elif state == "triple":
            if src.startswith('"""', i):
                state = "code"
                i += 3
                continue
        if c == "\n":
            line += 1
        i += 1
    if state in ("line", "block"):
        yield start, buf


def python_comments(src):
    try:
        for tok in tokenize.generate_tokens(io.StringIO(src).readline):
            if tok.type == tokenize.COMMENT:
                yield tok.start[0], tok.string
    except (tokenize.TokenError, IndentationError):
        return


def check_thai_comments(path, src, problems):
    if path.suffix == ".swift":
        comments = c_like_comments(src, swift=True)
    elif path.suffix in JS_EXT:
        comments = c_like_comments(src, swift=False)
    elif path.suffix == ".py":
        comments = python_comments(src)
    else:
        return
    for line, text in comments:
        if THAI.search(text):
            problems.append(f"{rel(path)}:{line}: Thai text in a comment")


def swift_parser():
    try:
        import tree_sitter_swift
        from tree_sitter import Language, Parser
    except ImportError:
        return None
    return Parser(Language(tree_sitter_swift.language()))


def first_error(node):
    if node.type == "ERROR" or node.is_missing:
        return node
    for child in node.children:
        if child.has_error or child.is_missing:
            found = first_error(child)
            if found:
                return found
    return None


def rel(path):
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main(argv):
    files = [Path(a).resolve() for a in argv] if argv else repo_files()
    problems, counts = [], {"swift": 0, "js": 0, "json": 0, "plist": 0}
    parser = None
    need_swift = any(p.suffix == ".swift" for p in files)
    if need_swift:
        parser = swift_parser()
        if parser is None:
            problems.append("tree-sitter-swift not installed: pip install tree-sitter tree-sitter-swift")

    for path in files:
        suffix = path.suffix
        if suffix in (".swift", ".py", ".json", ".plist", ".entitlements") or suffix in JS_EXT:
            src = path.read_text(encoding="utf-8")
        else:
            continue
        check_thai_comments(path, src, problems)

        if suffix == ".swift" and parser:
            counts["swift"] += 1
            tree = parser.parse(src.encode("utf-8"))
            if tree.root_node.has_error:
                err = first_error(tree.root_node)
                where = f"{err.start_point[0] + 1}:{err.start_point[1] + 1}" if err else "?"
                problems.append(f"{rel(path)}:{where}: Swift parse error")
        elif suffix in JS_EXT:
            counts["js"] += 1
            r = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
            if r.returncode != 0:
                problems.append(f"{rel(path)}: node --check failed\n{r.stderr.strip()}")
        elif suffix == ".json":
            counts["json"] += 1
            try:
                json.loads(src)
            except ValueError as e:
                problems.append(f"{rel(path)}: invalid JSON ({e})")
        elif suffix in (".plist", ".entitlements"):
            counts["plist"] += 1
            try:
                plistlib.loads(src.encode("utf-8"))
            except Exception as e:  # plistlib raises several types
                problems.append(f"{rel(path)}: invalid plist ({e})")

    summary = ", ".join(f"{v} {k}" for k, v in counts.items())
    if problems:
        print("\n".join(problems))
        print(f"\nFAILED ({len(problems)} problem(s); checked {summary})")
        return 1
    print(f"OK (checked {summary}; no Thai in comments)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
