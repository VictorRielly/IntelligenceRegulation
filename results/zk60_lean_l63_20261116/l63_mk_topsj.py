#!/usr/bin/env python3
"""D63 lane L63 (2026-11-17): write formal/ZK60Formal/RunStgShieldTopSJ.lean, the JOIN of lane L67's concrete Shieldstral
T128 R13 instantiation (`sshC_productionReadyL_epP_shieldInst`, RunShieldInstP.lean, not edited) with this lane's stage
proofs (`sshC_productionReadyL_epP_trO`, RunStgShieldTopTrO.lean), and its LogUp instantiation:

  J  `sshC_productionReadyL_epP_shieldJ`: shieldInst's statement (its `section ShieldTop` variables and notations,
     copied) without `hIOI hIOO hIOlI hIOlO hCsIO hTrIIO hTrOIO hdzW`, with `csIOI`, `csIOO` pinned as in `trO`
     (`hcsI`, `hcsO`, and `rE lcE Qe XE hXEl` for the free output-endpoint matrix). Proof: shieldInst's own proof with
     its head `sshC_productionReadyL_epP_pinsHd` replaced by `sshC_productionReadyL_epP_trO` (the same named argument
     list, the dropped premises' arguments removed, trO's added premises given: `hwO`, `hwB`, `hVi`, `hPlace` by
     L67's `shdP_hwO`, `shdP_hwB`, `shdP_hVi`, `shdP_epPlace_val`). So J's conclusion is shieldInst's (the kernel checks
     the conclusion of trO at shieldInst's arguments against J's statement) and J's remaining premises are shieldInst's
     verbatim.
  L  `sshC_productionReadyL_epP_shieldLu`: J at `eI := shdP_eI`, `eO := shdP_eO`, `ΛI := shd_ΛI … Rp.inp (shdP_incPub …)
     (shdEpad Rp.inp) (off 0 + 2) (off 0 + 5)`, `ΛO := shd_ΛO … (shdP_outcPub Rp wDigest) (off 27 + 2)`, `hLuStg` PROVED
     by `shd_hLuStg`; added premise `hV : Rp.inp.V ≤ 2 ^ 17` (a fact about the public input data, part of
     `Rp.inp.Valid`).
Usage: l63_mk_topsj.py <worktree root> [--check]"""
import re
import sys

WT = sys.argv[1]
F = WT + "/formal/ZK60Formal/"


def balanced_from(s, i):
    assert s[i] in "([{", s[i:i + 20]
    d = 0
    for j in range(i, len(s)):
        if s[j] in "([{":
            d += 1
        elif s[j] in ")]}":
            d -= 1
            if d == 0:
                return j + 1
    raise AssertionError("unbalanced")


src = open(F + "RunShieldInstP.lean").read()
s0 = src.index("section ShieldTop\n")
s1 = src.index("/-- **CONCRETE SHIELDSTRAL T128 R13 VERIFIER")
header = src[s0:s1]
t0 = src.index("theorem sshC_productionReadyL_epP_shieldInst\n")
t1 = src.index(" := by\n", t0)
stmt = src[t0:t1]
p1 = src.index("\nend ShieldTop", t1)
body = src[t1 + len(" := by\n"):p1 + 1]

# binders: one or more per line
binders = []
i = len("theorem sshC_productionReadyL_epP_shieldInst")
while True:
    while stmt[i] in " \n":
        i += 1
    if stmt[i] not in "([{":
        break
    e = balanced_from(stmt, i)
    binders.append(stmt[i:e])
    i = e
concl = stmt[i:]
assert concl.startswith(":\n    ProductionReadyL"), concl[:40]


def bname(b):
    return b[1:-1].split(" : ", 1)[0].split()


drop = ["hIOI", "hIOO", "hIOlI", "hIOlO", "hCsIO", "hTrIIO", "hTrOIO", "hdzW"]
H64 = "(le64_of_le20 hL20)"
NEWJ = [
    "(hcsI : csIOI = stgCsIOm U 6 8 256 (PXkS 0).rows 14 256\n"
    "      (epUxV tag Lq " + H64 + " key domain hs hL 6)\n"
    "      (bxUxV tag Lq " + H64 + " (PXkS 0).rows ((RnS).pf.off 0 + 2)))",
    "(rE lcE Qe : ℕ)",
    "(XE : StgVw Lq → Fin rE → Fin (2 ^ lcE + Qe) → K)",
    "(hcsO : csIOO = stgCsIOm U (OoutS).pX.rows 14 256 rE lcE Qe\n"
    "      (bxUxV tag Lq " + H64 + " (OoutS).pX.rows ((RnS).pf.off 26 + 2)) XE)",
    "(hXEl : VwLoc ((RnS).pf.off 27 + 2 + (7 + 2)) XE)",
]
keptJ = []
seen = set()
for b in binders:
    nm = bname(b)
    if set(nm) & set(drop):
        assert len(nm) == 1, nm
        seen |= set(nm)
        continue
    keptJ.append(b)
    if nm == ["hzk"]:
        keptJ += NEWJ
assert seen == set(drop), seen
stmtJ = "theorem sshC_productionReadyL_epP_shieldJ" + "".join("\n    " + b for b in keptJ) + "\n    " + concl

bodyJ = body.replace("exact RunShapeP.sshC_productionReadyL_epP_pinsHd\n",
                     "exact RunShapeP.sshC_productionReadyL_epP_trO\n")
assert bodyJ != body
n0 = len(bodyJ)
for d in drop:
    bodyJ, k = re.subn(r"\(%s := %s\) ?" % (d, d), "", bodyJ)
    assert k == 1, d
bodyJ = re.sub(r" +\n", "\n", bodyJ).rstrip("\n") + "\n"
tail = "(hzk := hzk)\n"
assert bodyJ.endswith(tail), bodyJ[-60:]
bodyJ = bodyJ[:-len(tail)] + (
    "(hzk := hzk)\n"
    "    (hcsI := hcsI) (hwO := shdP_hwO tag Rp embDigest embFold bInRow)\n"
    "    (rE := rE) (lcE := lcE) (Qe := Qe) (XE := XE) (hcsO := hcsO) (hXEl := hXEl)\n"
    "    (hwB := shdP_hwB tag Rp wDigest bOutRow)\n"
    "    (hVi := (shdP_hVi tag Rp embDigest embFold bInRow).2) (hPlace := shdP_epPlace_val)\n")


# --- L: the LogUp instantiation, from J's binder list
def subst_lu(t):
    t = re.sub(r"(?<![A-Za-z0-9_'.])RkDS(?![A-Za-z0-9_'])", "RkDL", t)
    t = re.sub(r"(?<![A-Za-z0-9_'.])ΛI(?![A-Za-z0-9_'])", "(ΛIc)", t)
    t = re.sub(r"(?<![A-Za-z0-9_'.])ΛO(?![A-Za-z0-9_'])", "(ΛOc)", t)
    t = re.sub(r"(?<![A-Za-z0-9_'.])eI(?![A-Za-z0-9_'])", "shdP_eI", t)
    t = re.sub(r"(?<![A-Za-z0-9_'.])eO(?![A-Za-z0-9_'])", "shdP_eO", t)
    return t


keptL = []
for b in keptJ:
    nm = bname(b)
    if nm == ["hLuStg"]:
        keptL.append("(hV : Rp.inp.V ≤ 2 ^ 17)")
        continue
    keptL.append(subst_lu(b))
stmtL = "theorem sshC_productionReadyL_epP_shieldLu" + "".join("\n    " + b for b in keptL) + "\n    " + concl
for tok in ["ΛI ", "ΛO ", " eI ", " eO ", "RkDS"]:
    assert tok not in stmtL.replace("(ΛIc)", "").replace("(ΛOc)", ""), tok
VARS = ["U", "hbij", "tag", "dPos0", "Lq", "hL20", "hL64", "key", "domain", "hs", "hL", "Rp", "hw", "hhdrFit",
        "preA", "preB", "check0", "paths", "digest", "bndCheck", "embDigest", "embFold", "bInRow", "wDigest",
        "bOutRow", "Pk0", "hPk0", "P", "epBase", "E0", "csIOI", "csIOO"]
BINDS = ["hU", "site", "kOf", "δOf", "O", "hzk", "hcsI", "rE", "lcE", "Qe", "XE", "hcsO", "hXEl",
         "hLI_stg", "hLO_stg", "hdinS", "hdoutS"]
argsL = ["(%s := %s)" % (n, n) for n in VARS + BINDS]
bodyL = ("  exact sshC_productionReadyL_epP_shieldJ\n    "
         + "\n    ".join(" ".join(argsL[x:x + 8]) for x in range(0, len(argsL), 8))
         + "\n    (eI := shdP_eI) (eO := shdP_eO) (ΛI := ΛIc) (ΛO := ΛOc)\n"
         "    (hLuStg := shd_hLuStg U tag " + H64 + " AbsS Rp.inp hV (shdP_incPub Rp embDigest embFold)\n"
         "      (shdEpad Rp.inp) (shdP_outcPub Rp wDigest) ((RnS).pf.off 0 + 2) ((RnS).pf.off 0 + 5)\n"
         "      ((RnS).pf.off 27 + 2))\n")

NOTS = ('\nlocal notation "ΛIc" =>\n'
        "  shd_ΛI (K := K) U tag " + H64 + " Rp.inp (shdP_incPub Rp embDigest embFold) (shdEpad Rp.inp)\n"
        "    ((RnS).pf.off 0 + 2) ((RnS).pf.off 0 + 5)\n\n"
        'local notation "ΛOc" =>\n'
        "  shd_ΛO (K := K) U tag " + H64 + " (shdP_outcPub Rp wDigest) ((RnS).pf.off 27 + 2)\n")
rk0 = header.index('local notation "RkDS" =>')
rk1 = header.index("\n\n", rk0)
rkds = header[rk0:rk1]
assert rkds.endswith("P0inS P0outS csIOI csIOO eI eO ΛI ΛO"), rkds[-60:]
rkdl = rkds.replace('"RkDS"', '"RkDL"').replace("csIOI csIOO eI eO ΛI ΛO", "csIOI csIOO shdP_eI shdP_eO (ΛIc) (ΛOc)")
hdr2 = header[:rk1] + "\n" + NOTS + "\n" + rkdl + header[rk1:]
hdr2 = hdr2.replace("section ShieldTop\n", "section ShieldTopSJ\n", 1)

docJ = ("/-- **L67'S CONCRETE SHIELDSTRAL T128 R13 TOP THEOREM WITH THE LANE'S STAGE FACTS** (D63 lane L63, the join):\n"
        "`sshC_productionReadyL_epP_shieldInst` without `hIOI hIOO hIOlI hIOlO hCsIO hTrIIO hTrOIO hdzW`, PROVED here through\n"
        "`sshC_productionReadyL_epP_trO` at shieldInst's arguments. `csIOI`, `csIOO` are pinned (`hcsI`, `hcsO`) to the\n"
        "matrices the run's closing openings check: the input endpoint (`epUxV`, part 0's `ebOpen`, rows 6), `B_in` (`bxUxV`\n"
        "at rows 38, position `off 0 + 2`), `B_out` (`bxUxV` at rows 38, position `off 26 + 2`); the output endpoint's matrix\n"
        "`XE` is free (`rE lcE Qe XE hXEl`): the code refuses every claim on it. trO's premises `hwO hwB hVi hPlace` are\n"
        "discharged by L67's `shdP_hwO shdP_hwB shdP_hVi shdP_epPlace_val`. Remaining: shieldInst's `hLuStg hLI_stg hLO_stg\n"
        "hdinS hdoutS` (verbatim) and its instantiation leftovers. -/\n")
docL = ("/-- **THE JOIN WITH THE CONCRETE STAGE LOGUP PREDICATES** (D63 lane L63): `sshC_productionReadyL_epP_shieldJ` at\n"
        "`eI := shdP_eI = 2^19`, `eO := shdP_eO = 2^16`, `ΛI := shd_ΛI` (IN-C's cleared LogUp numerator vanishing at the\n"
        "challenges read so far, on the data `shdIncData` reads at the view: `A_TOK` and `A_MULT` of `A_in` at `off 0 + 5`,\n"
        "`B_in` at `off 0 + 2` = the matrix `hcsI` pins, the public table `shdEpad Rp.inp`) and `ΛO := shd_ΛO` (OUT-C's byte\n"
        "LogUp state on `A_out` at `off 27 + 2`); `hLuStg` PROVED by lane L67b's `shd_hLuStg`. Added premise:\n"
        "`hV : Rp.inp.V ≤ 2 ^ 17` (the vocabulary class of the public input data, `InPublic.Valid.V2`; true at the\n"
        "registered `V = 131072`). -/\n")
pre = ("/-\nD63 lane L63 (2026-11-17), part 47: **the join of lane L67's concrete Shieldstral instantiation with the lane's\n"
       "stage facts, and the concrete stage LogUp predicates** (`sshC_productionReadyL_epP_shieldJ`,\n"
       "`sshC_productionReadyL_epP_shieldLu`). Generated by `results/zk60_lean_l63_20261116/l63_mk_topsj.py` from\n"
       "`sshC_productionReadyL_epP_shieldInst` (RunShieldInstP.lean, not edited): its `section ShieldTop` variables and\n"
       "notations are copied, its statement is filtered, its proof is re-headed on `sshC_productionReadyL_epP_trO`.\n\n"
       "Premises of shieldInst GONE in `shieldJ`: `hIOI hIOO hIOlI hIOlO hCsIO hTrIIO hTrOIO hdzW` (8). ADDED: `hcsI`, `hcsO`\n"
       "(the pins of `csIOI`, `csIOO`, which stay section variables) with `rE lcE Qe XE hXEl` (the free output-endpoint\n"
       "matrix and its view locality). REMAINING from shieldInst: `hLuStg hLI_stg hLO_stg hdinS hdoutS`, `hU`, `O`, `hzk`\n"
       "and the instantiation leftovers (`hPk0 dPos0 Pk0`, `hhdrFit hw`, `U hbij`, `tag`, `Lq hL20 hL64`, `key domain hs\n"
       "hL`, `Rp`, `preA preB check0 paths digest bndCheck`, `embDigest embFold bInRow wDigest bOutRow`, `P epBase`, `E0`,\n"
       "`site kOf δOf εzk`), plus the data `csIOI csIOO eI eO ΛI ΛO`.\n"
       "`shieldLu` further: `eI eO ΛI ΛO` instantiated and `hLuStg` GONE; ADDED `hV : Rp.inp.V ≤ 2 ^ 17`.\n\n"
       "Only `propext`, `Classical.choice`, `Quot.sound`.\n-/\n"
       "import ZK60Formal.RunShieldInstP\nimport ZK60Formal.RunStgShieldTopTrO\nimport ZK60Formal.RunStgShieldLuRd\n\n"
       "set_option autoImplicit false\nset_option linter.constructorNameAsVariable false\n\n"
       "namespace ZK60.ProtocolClassify\n\n"
       "open scoped ENNReal\n"
       "open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape\n"
       "open Code\n"
       "open ZK60.Exec.StageV ZK60.Exec.StageCheck\n"
       "open ZK60.Circuit (gP GF)\n"
       "open ZK60.Block (BlockShape BlockPublic)\n"
       "open ZK60.Exec.Block (BlockParams Cm Cuts3 RootsO HdrX SlotRec SlotKind SlotS SlotDef PubTabs\n"
       "  defineS defineS_ok cmCount cmCountS cmCount_eval blockSlots_claims sumFrom slotShape slotTerms)\n"
       "open ZK60.ProtocolClassify.RunShapeP\n"
       "open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldCal shieldS0 shieldShape)\n\n")
text = (pre + hdr2 + docJ + stmtJ + " := by\n" + bodyJ + "\n" + docL + stmtL + " := by\n" + bodyL
        + "\nend ShieldTopSJ\n\nend ZK60.ProtocolClassify\n")
# the copied private `zero_lt_26` is renamed: the lane's name-clash check reads private names too
assert text.count("zero_lt_26") >= 3
text = text.replace("zero_lt_26", "sj_zero_lt_26")
dst = F + "RunStgShieldTopSJ.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("RunStgShieldTopSJ.lean", "identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst, "J binders", len(keptJ), "L binders", len(keptL), "of", len(binders))
