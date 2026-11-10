#!/usr/bin/env python3
"""D63 lane L43 (2026-11-10; a copy of results/zk60_lean_l39_20261110/l39_nameclash.py, prefixes given on the command
line: RunKindsData,RunHal,RunCoverPAlive,RunCoverPSomeL,RunCoverPRk; the brief's pattern RunCoverP* would also match
L39's RunCoverParse.lean): compare the declaration names of this lane's Lean files with those of every other Lean
file under formal/ZK60Formal in every git worktree of the repository (committed or not). Two lanes that declare the same
fully qualified name both build alone and fail once the library root imports both (finding L27-6). Read-only.

usage: python3 -I l39_nameclash.py <this worktree> <main checkout> [file prefixes, comma separated; default RunCover]

The root-level name `main` is left out (every agreement checker defines it; the root imports none of them).

Prints the count of this lane's declarations, any name declared twice inside the lane, and one line per clash; exits 1
if there is a clash.
"""
import glob
import os
import re
import subprocess
import sys

wt, main = sys.argv[1], sys.argv[2]
prefixes = (sys.argv[3] if len(sys.argv) > 3 else "RunCover").split(",")
prefix = "{" + ",".join(prefixes) + "}"
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
    out.discard("main")  # a checker's entry point: the checkers are never imported by the root
    return out


mine = {}
for f in sorted(g for p in prefixes for g in glob.glob(f"{wt}/formal/ZK60Formal/{p}*.lean")):
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
        if any(b.startswith(p) for p in prefixes):
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
