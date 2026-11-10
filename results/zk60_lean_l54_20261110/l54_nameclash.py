#!/usr/bin/env python3
"""D63 lane L54 (2026-11-10; a copy of results/zk60_lean_l52_20261110/l52_nameclash.py): compare the declaration
names this lane introduces with those of every other Lean file under formal/ZK60Formal in every git worktree of the
repository (committed or not). Two lanes that declare the same fully qualified name both build alone and fail once the
library root imports both (finding L27-6). Read-only.

This lane's names are (1) every declaration of its new files (the file prefixes given) and (2) every declaration it
ADDED to the existing files it edited under its brief's exception (the declarations of the edited file now, minus
those of the same file at the base commit).

usage: python3 -I l54_nameclash.py <this worktree> <main checkout> <prefixes, comma separated> <base commit>
         <edited module> [<edited module> ...]

The root-level name `main` is left out (every agreement checker defines it; the root imports none of them).
Prints the count of this lane's names, any name declared twice inside the lane, and one line per clash; exits 1 if
there is a clash.
"""
import glob
import os
import re
import subprocess
import sys

wt, main, prefs, base = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
edited = sys.argv[5:]
prefixes = prefs.split(",")
DECL = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:private |protected |noncomputable |partial |unsafe )*"
                  r"(?:theorem|lemma|def|abbrev|structure|inductive|class|instance|opaque)\s+(\S+)")


def decls_text(text):
    out, stack = set(), []
    for raw in text.splitlines():
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
    out.discard("main")
    return out


def decls(path):
    return decls_text(open(path, encoding="utf-8").read())


mine = {}
for f in sorted(g for p in prefixes for g in glob.glob(f"{wt}/formal/ZK60Formal/{p}*.lean")):
    for n in decls(f):
        mine.setdefault(n, []).append(os.path.basename(f))
added = 0
for m in edited:
    now = decls(f"{wt}/formal/ZK60Formal/{m}.lean")
    old = subprocess.run(["git", "-C", wt, "show", f"{base}:formal/ZK60Formal/{m}.lean"], capture_output=True,
                         text=True).stdout
    for n in sorted(now - decls_text(old)):
        mine.setdefault(n, []).append(f"{m}.lean (added)")
        added += 1
print(f"names of this lane: {len(mine)} ({added} added to the edited files)")
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
        if os.path.realpath(w) == os.path.realpath(wt) and b[:-5] in edited:
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
