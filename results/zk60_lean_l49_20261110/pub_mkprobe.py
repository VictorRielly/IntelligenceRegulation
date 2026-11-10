#!/usr/bin/env python3
"""D63 lane L49, sub-agent pub: while the lane's foundation BlockR13HostBase.lean does not build (its `shS.logs`
notation, iter2/pub_iter1), write ONE probe file that is the foundation (with only `shS.` spelled out in full),
then BlockR13HostPub.lean, then BlockR13HostExportCheck.lean, so that this sub-agent's module and checker can be
elaborated and run against the corpora before the lane's fix lands. Nothing in the repository is edited.

usage: python3 -I pub_mkprobe.py <worktree> <out file>
"""
import re
import sys

wt, out = sys.argv[1], sys.argv[2]
F = f"{wt}/formal/ZK60Formal"


def body(path):
    txt = open(path, encoding="utf-8").read()
    imports = re.findall(r"^import (\S+)$", txt, flags=re.M)
    rest = re.sub(r"^import \S+\n", "", txt, flags=re.M)
    return imports, rest


bi, base = body(f"{F}/BlockR13HostBase.lean")
base = base.replace('local notation "shS" => ZK60.Exec.Slot.R13.shShieldR13\n', "")
base = re.sub(r"\bshS\.", "ZK60.Exec.Slot.R13.shShieldR13.", base)
pi, pub = body(f"{F}/BlockR13HostPub.lean")
ci, chk = body(f"{F}/BlockR13HostExportCheck.lean")
imports = []
for m in bi + pi + ci:
    if m not in ("ZK60Formal.BlockR13HostBase", "ZK60Formal.BlockR13HostPub") and m not in imports:
        imports.append(m)
with open(out, "w", encoding="utf-8") as f:
    f.write("".join(f"import {m}\n" for m in imports))
    f.write("/- D63 lane L49, sub-agent pub: probe = the foundation (shS spelled out) + BlockR13HostPub + the checker. -/\n")
    f.write(base)
    f.write("\n")
    f.write(pub)
    f.write("\n")
    f.write(chk)
print("wrote", out, "imports", imports)
