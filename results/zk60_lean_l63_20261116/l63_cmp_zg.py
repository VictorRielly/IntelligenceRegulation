#!/usr/bin/env python3
"""D63 lane L63 (2026-11-22, leg 21), ruling L63-15: the old theorems' statements are unchanged.

For each theorem the ruling turned into an instance of its new generic version, compare, between a git revision (the
lane's start of leg 21) and the worktree, (1) the statement text from `theorem X` to its ` := by`, (2) the
`include … in` line just above it (which decides the section variables it binds), (3) the section's variable block
and every `local notation` line of the file (the statement's abbreviations). Also: every declaration name of the old
file is still declared in the new one (nothing dropped), and each generic `X_zg` differs from `X`'s statement exactly
by the implicit `εzk`, the premise `hzkB` (absent for `shd_hdinX_blk_zg`) and the literal replaced by `εzk`.
Usage: l63_cmp_zg.py <worktree root> <revision>"""
import re
import subprocess
import sys

WT, REV = sys.argv[1], sys.argv[2]
LIT = "(ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds)"
EZK = "    {εzk : ℕ → ℕ → ℝ≥0∞}\n"
HZKB = "    (hzkB : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R')\n"
T = [("RunStgShieldClBlkLu", "sshC_productionReadyL_epP_blkLu_cl", True),
     ("RunStgShieldClBx", "sshC_productionReadyL_epP_blkIO_cl", True),
     ("RunStgShieldClBx", "sshC_productionReadyL_epP_blkIOv_cl", True),
     ("RunStgShieldClTopL", "sshC_productionReadyL_epP_blkCl", True),
     ("RunStgShieldClTopLO", "sshC_productionReadyL_epP_blkLO", True),
     ("RunStgShieldClTopOC", "sshC_productionReadyL_epP_blkOC", True),
     ("RunStgShieldClTopEF", "sshC_productionReadyL_epP_blkEF", True),
     ("RunStgShieldTopL", "shd_hdinX_blk", False)]
DECL = re.compile(r"^(?:private )?(?:noncomputable )?(?:theorem|lemma|def|abbrev|structure|inductive|instance) (\S+)", re.M)


def stmt(txt, name):
    k = txt.index("\ntheorem " + name + "\n") + 1
    assert txt.count("\ntheorem " + name + "\n") == 1
    e = txt.index(" := by\n", k) + len(" := by\n")
    # the include line belongs to this theorem only when it is in its lead (no blank line between)
    lead = txt[txt.rfind("\n\n", 0, k) + 2:k]
    inc = [l for l in lead.split("\n") if l.startswith("include ")]
    return txt[k:e], inc


def secmeta(txt):
    v = txt.find("\nvariable {Hdr Coins : Type}")
    blk = txt[v:txt.index("\n\n", v + 1)]
    notes = [l for l in txt.split("\n") if l.startswith("local notation")]
    return blk, notes


bad = 0
seen = set()
for mod, name, hz in T:
    p = "formal/ZK60Formal/" + mod + ".lean"
    old = subprocess.run(["git", "-C", WT, "show", REV + ":" + p], capture_output=True, text=True, check=True).stdout
    new = open(WT + "/" + p).read()
    so, io = stmt(old, name)
    sn, inn = stmt(new, name)
    ok1 = so == sn
    ok2 = io == inn
    sg, ig = stmt(new, name + "_zg")
    exp = so.replace("theorem " + name + "\n", "theorem " + name + "_zg\n", 1)
    o = exp.index("\n    (O : ClassifyOpenP") + 1
    d = 0
    for j in range(o + 4, len(exp)):
        d += {"(": 1, ")": -1}.get(exp[j], 0)
        if d == 0:
            oe = j + 1
            break
    exp = exp[:o] + EZK + exp[o:oe + 1].replace(LIT, "εzk") + (HZKB if hz else "") + exp[oe + 1:]
    ok3 = sg == exp and ig == io
    line = "%-38s statement %s, include %s, generic = old + {εzk} + %s: %s" % (
        name, "SAME" if ok1 else "CHANGED", "SAME" if ok2 else "CHANGED", "hzkB" if hz else "nothing",
        "yes" if ok3 else "NO")
    print(line)
    bad += (not ok1) + (not ok2) + (not ok3)
    if mod not in seen:
        seen.add(mod)
        bo, no = secmeta(old)
        bn, nn = secmeta(new)
        dold = set(DECL.findall(old))
        dnew = set(DECL.findall(new))
        okm = bo == bn and no == nn and dold <= dnew
        print("  %s: variable block %s, local notations %s (%d), old declarations kept %d of %d, new %s" % (
            mod, "SAME" if bo == bn else "CHANGED", "SAME" if no == nn else "CHANGED", len(nn),
            len(dold & dnew), len(dold), sorted(dnew - dold)))
        bad += not okm
print("l63_cmp_zg.py:", "OK" if bad == 0 else "%d differences" % bad)
sys.exit(1 if bad else 0)
