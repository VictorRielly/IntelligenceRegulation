"""Item-level comparison of a Rust file at main `4751b93` and in the snapshot.

Every named block item (`fn`, `impl`, `mod`, `struct`, `enum`, `trait`) and
every `const` / `static` / `use` statement is keyed by its path of enclosing
items, its text is compared after removing nothing (byte-for-byte), and each
is marked `cfg(test)` when it or an enclosing item carries `#[cfg(test)]`.

    python3 results/zk60_d22_preread_snapshot/items.py <path> [<path> ...]
            [--snapshot DIR] [--changed-only]

The scanner skips comments, strings (incl. raw strings), and char literals,
and asserts brace depth 0 at end of file, so a mis-parse cannot pass quietly.
"""
from __future__ import annotations

import argparse
import re
import subprocess

REPO = "/home/victor/IntelligenceRegulation"


def show(rev, path):
    r = subprocess.run(["git", "--no-pager", "show", f"{rev}:{path}"],
                       cwd=REPO, capture_output=True)
    return r.stdout.decode() if r.returncode == 0 else ""


def code_mask(src: str) -> str:
    """Same length as src; comments/strings/chars replaced by spaces."""
    out = list(src)
    i, n = 0, len(src)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif src.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth += 1
                    j += 2
                elif src.startswith("*/", j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            blank(i, j)
            i = j
        elif (c == "r" and re.match(r'r(#*)"', src[i:i + 10])
              and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == "_"))):
            m = re.match(r'r(#*)"', src[i:])
            hashes = m.group(1)
            end = src.find('"' + hashes, i + len(m.group(0)))
            j = end + 1 + len(hashes)
            blank(i, j)
            i = j
        elif c == "b" and src.startswith('b"', i) and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == "_")):
            i += 1  # the string branch below takes it
        elif c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            blank(i, j + 1)
            i = j + 1
        elif c == "'":
            m = re.match(r"'(\\.|\\x[0-9a-fA-F]{2}|\\u\{[0-9a-fA-F]+\}|[^\\'])'", src[i:])
            if m:
                blank(i, i + len(m.group(0)))
                i += len(m.group(0))
            else:
                i += 1  # a lifetime
        else:
            i += 1
    return "".join(out)


HEAD = re.compile(r"\b(fn|impl|mod|struct|enum|trait|union)\b")


def items(src: str):
    """-> dict key -> (text, is_test).  key = 'a::b::fn name#k'."""
    code = code_mask(src)
    res = {}
    stack = []  # (name, is_test, start)
    seen = {}
    depth = 0
    last_stmt_end = 0
    i = 0
    n = len(code)
    pdepth = 0  # ( and [ nesting: a `;` inside `[u8; 32]` ends nothing
    pstack = []
    while i < n:
        c = code[i]
        if c in "([":
            pdepth += 1
        elif c in ")]":
            pdepth -= 1
        if pdepth > 0 and c not in "{}":
            i += 1
            continue
        if c == "{":
            pstack.append(pdepth)
            pdepth = 0
            header = code[last_stmt_end:i]
            m = None
            for mm in HEAD.finditer(header):
                m = mm
                break
            name = None
            if m:
                kw = m.group(1)
                rest = header[m.end():]
                if kw == "impl":
                    nm = re.sub(r"\s+", " ", rest).strip()
                    nm = re.sub(r"\bwhere\b.*", "", nm).strip()
                    name = f"impl {nm}"
                else:
                    mn = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", rest)
                    name = f"{kw} {mn.group(1)}" if mn else None
            # attributes on the header
            is_test = bool(re.search(r"#\[cfg\(\s*test\s*\)\]", src[last_stmt_end:i]))
            parent_test = stack[-1][1] if stack else False
            stack.append((name, is_test or parent_test, last_stmt_end, name is not None
                          and (not stack or stack[-1][0] is not None and not stack[-1][0].startswith("fn "))))
            depth += 1
            last_stmt_end = i + 1
        elif c == "}":
            pdepth = pstack.pop()
            name, is_test, start, is_item = stack.pop()
            depth -= 1
            if is_item:
                path = "::".join(s[0] for s in stack if s[0]) + ("::" if stack and any(s[0] for s in stack) else "") + name
                k = seen.get(path, 0)
                seen[path] = k + 1
                res[f"{path}#{k}"] = (src[start:i + 1].strip(), is_test)
            last_stmt_end = i + 1
        elif c == ";":
            # a statement item at item level (not inside a fn body)
            if not stack or (stack[-1][0] and not stack[-1][0].startswith("fn ") and stack[-1][3]):
                stmt = src[last_stmt_end:i + 1].strip()
                cstmt = code[last_stmt_end:i + 1]
                mm = re.search(r"\b(const|static|use|type|mod)\s+([A-Za-z_][A-Za-z0-9_:{}, *]*)", cstmt)
                if mm:
                    kw, nm = mm.group(1), re.sub(r"\s+", "", mm.group(2))[:60]
                    parent = "::".join(s[0] for s in stack if s[0])
                    path = (parent + "::" if parent else "") + f"{kw} {nm}"
                    k = seen.get(path, 0)
                    seen[path] = k + 1
                    is_test = bool(re.search(r"#\[cfg\(\s*test\s*\)\]", stmt)) or (stack[-1][1] if stack else False)
                    res[f"{path}#{k}"] = (stmt, is_test)
            last_stmt_end = i + 1
        i += 1
    assert depth == 0 and not stack, f"brace depth {depth} at end of file"
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--snapshot", default="/tmp/claude-1000/d22-snapshot")
    ap.add_argument("--rev", default="4751b93")
    ap.add_argument("--changed-only", action="store_true")
    a = ap.parse_args()
    for path in a.paths:
        old = items(show(a.rev, path))
        new = items(open(f"{a.snapshot}/{path}").read())
        # strip the #k for display
        keys = list(dict.fromkeys(list(old) + list(new)))
        counts = {"identical": 0, "CHANGED": 0, "NEW": 0, "REMOVED": 0}
        lines = []
        for k in keys:
            o, nw = old.get(k), new.get(k)
            if o and nw:
                st = "identical" if o[0] == nw[0] else "CHANGED"
            elif nw:
                st = "NEW"
            else:
                st = "REMOVED"
            counts[st] += 1
            test = (nw or o)[1]
            if a.changed_only and st == "identical":
                continue
            lines.append(f"  {st:<9} {'[test]' if test else '[prod]'} {k}")
        print(f"== {path}  ({a.rev} -> snapshot): " + ", ".join(f"{v} {k}" for k, v in counts.items()))
        print("\n".join(lines))


if __name__ == "__main__":
    main()
