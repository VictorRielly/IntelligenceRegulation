#!/usr/bin/env python3
"""D63 lane L63, leg 12 (2026-11-19): register new lane files (idempotent).

usage: l63_reg.py <WT> <Module> [<Module> ...]

For each module name M (e.g. RunStgShieldOutCube) it makes sure that
  * formal/ZK60Formal.lean has `import ZK60Formal.M` (appended after the last `import ZK60Formal.RunStgShield` line);
  * check_l63merge.sh lists M in NEW_SINCE_BASE and MINE_NEW (appended at the end of each list);
  * gen_axioms.py lists "M.lean" in its files list and "import ZK60Formal.M" in its import lines.
Nothing else is changed. Each change is printed.
"""
import re
import sys

wt = sys.argv[1]
mods = sys.argv[2:]
out = wt + "/results/zk60_lean_l63_20261116"

root = wt + "/formal/ZK60Formal.lean"
src = open(root).read()
lines = src.split("\n")
for m in mods:
    imp = "import ZK60Formal." + m
    if imp in lines:
        continue
    last = max(i for i, l in enumerate(lines) if l.startswith("import ZK60Formal.RunStgShield"))
    lines.insert(last + 1, imp)
    print("root: added", imp)
open(root, "w").write("\n".join(lines))

chk = out + "/check_l63merge.sh"
s = open(chk).read()
for var in ("NEW_SINCE_BASE", "MINE_NEW"):
    mo = re.search(r'^' + var + r'="([^"]*)"', s, re.M)
    assert mo, var
    names = mo.group(1).split()
    changed = False
    for m in mods:
        if m not in names:
            names.append(m)
            changed = True
            print("check:", var, "added", m)
    if changed:
        s = s[:mo.start(1)] + " ".join(names) + s[mo.end(1):]
open(chk, "w").write(s)

ga = out + "/gen_axioms.py"
g = open(ga).read()
for m in mods:
    f = '"' + m + '.lean"'
    if f not in g:
        i = g.index('"RunStgShieldOutZero.lean"')
        j = g.index("]", i)
        g = g[:j] + ", " + f + g[j:]
        print("gen_axioms: file added", m)
    imp = '"import ZK60Formal.' + m + '"'
    if imp not in g:
        i = g.index('"import ZK60Formal.RunStgShieldOutZero"')
        j = i + len('"import ZK60Formal.RunStgShieldOutZero"')
        g = g[:j] + ", " + imp + g[j:]
        print("gen_axioms: import added", m)
open(ga, "w").write(g)
