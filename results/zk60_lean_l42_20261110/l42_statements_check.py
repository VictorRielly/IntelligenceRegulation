#!/usr/bin/env python3
"""D63 lane L42 (2026-11-10): check that the D76 amendment of Statements.lean changes nothing but comments and adds
whole declarations. Read-only.

usage: python3 -I l42_statements_check.py <old Statements.lean> <new Statements.lean>

The Lean code of each version is its text with every comment removed (block comments `/- … -/`, which include the doc
comments `/-- … -/` and `/-! … -/`, and line comments `-- …`), blank lines dropped. The check:
  1. every code line of the old version is in the new one, in order and unchanged (so no definition, field, quantifier
     or error target of the approved text was edited or removed);
  2. every block of added code lines starts with a declaration at column 0 (`structure`, `def`, `noncomputable def`,
     `theorem`), so nothing was inserted INTO an old declaration;
and lists the added declarations. Exit code 0 only when 1 and 2 hold.
"""
import re
import sys


def code_lines(text):
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("/-", i):
            depth += 1
            i += 2
            continue
        if depth and text.startswith("-/", i):
            depth -= 1
            i += 2
            continue
        if depth == 0:
            out.append(text[i])
        i += 1
    lines = []
    for ln in "".join(out).splitlines():
        ln = re.sub(r"--.*$", "", ln).rstrip()
        if ln.strip():
            lines.append(ln)
    return lines


old = code_lines(open(sys.argv[1], encoding="utf-8").read())
new = code_lines(open(sys.argv[2], encoding="utf-8").read())
print(f"code lines: old {len(old)}, new {len(new)}")
# 1. greedy subsequence match, recording the added blocks
j, added, block = 0, [], []
for ln in new:
    if j < len(old) and ln == old[j]:
        if block:
            added.append(block)
            block = []
        j += 1
    else:
        block.append(ln)
if block:
    added.append(block)
ok1 = j == len(old)
print(f"1. every old code line kept, in order and unchanged: {'yes' if ok1 else 'NO (first missing: ' + old[j] + ')'}")
DECL = re.compile(r"^(?:noncomputable )?(structure|def|theorem|abbrev) (\S+)")
ok2 = all(DECL.match(b[0]) for b in added)
print(f"2. every added block starts with a declaration at column 0: {'yes' if ok2 else 'NO'}")
for b in added:
    names = [DECL.match(ln).group(2) for ln in b if DECL.match(ln)]
    print(f"   added block of {len(b)} code lines, declarations: {', '.join(names) if names else '(none)'}"
          + ("" if DECL.match(b[0]) else f"; FIRST LINE: {b[0]}"))
sys.exit(0 if ok1 and ok2 else 1)
