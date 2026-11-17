#!/usr/bin/env python3
"""D63 lane L27 (2026-11-09): compare the declaration names of this lane's Lean files with those of every other Lean
file under formal/ZK60Formal in every git worktree of the repository (committed or not). Two lanes that declare the same
fully qualified name both build alone and fail once the library root imports both (finding L27-6). Read-only.

usage: python3 -I l27_nameclash.py <this worktree> <main checkout> [file prefix, default RunChain]

Prints the count of this lane's declarations, any name declared twice inside the lane, and one line per clash; exits 1
if there is a clash.
"""
import glob
import os
import re
import subprocess
import sys

wt, main = sys.argv[1], sys.argv[2]
prefix = sys.argv[3] if len(sys.argv) > 3 else "RunChain"
DECL = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:private |protected |noncomputable |partial |unsafe )*"
                  r"(?:theorem|lemma|def|abbrev|structure|inductive|class|instance|opaque)\s+(\S+)")


def decls(path):
    out, stack = set(), []
    for raw in open(path, encoding="utf-8"):
        m = re.match(r"^namespace (\S+)", raw)
        if m:
            stack.append(m.group(1))
            continue
        m = re.match(r"^end (\S+)", raw)
        if m and stack and stack[-1] == m.group(1):
            stack.pop()
            continue
        m = DECL.match(raw)
        if m:
            n = m.group(1)
            out.add(n[len("_root_."):] if n.startswith("_root_.") else ".".join(stack + [n]))
    return out


mine = {}
for f in sorted(glob.glob(f"{wt}/formal/ZK60Formal/{prefix}*.lean")):
    for n in decls(f):
        mine.setdefault(n, []).append(os.path.basename(f))
print(f"declarations in {prefix}*.lean: {len(mine)}")
print("declared twice inside the lane:", sorted(n for n, v in mine.items() if len(v) > 1) or "none")
listing = subprocess.run(["git", "-C", main, "worktree", "list", "--porcelain"], capture_output=True, text=True).stdout
wts = [line.split(" ", 1)[1] for line in listing.splitlines() if line.startswith("worktree ")]
print(f"worktrees read: {len(wts)}")
files = 0
clash = {}
for w in wts:
    for f in glob.glob(f"{w}/formal/ZK60Formal/*.lean"):
        b = os.path.basename(f)
        if b.startswith(prefix):
            continue
        files += 1
        for n in decls(f):
            if n in mine:
                clash.setdefault((n, b), set()).add(os.path.basename(w))
print(f"other Lean files read (with repeats across worktrees): {files}")
for (n, b), ws in sorted(clash.items()):
    print(f"CLASH {n}: {mine[n][0]} and {b} (in {len(ws)} worktree(s), e.g. {sorted(ws)[0]})")
print(f"clashes: {len(clash)}")
sys.exit(1 if clash else 0)
