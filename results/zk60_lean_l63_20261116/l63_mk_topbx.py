#!/usr/bin/env python3
"""D63 lane L63 (2026-11-18): write formal/ZK60Formal/RunStgShieldTopBx.lean, lane L68a's joined top theorem
`sshC_productionReadyL_epP_blkLu` (RunShieldBlkInst.lean, Antigravity's, not edited) with the run extractor wrapped
by `epxIOE` (RunStgShieldEpxIO.lean; the coordinator's ruling: `tokW := epW`, `xC` from the extracted boundary plane
`Lb = 26`, both by construction):

  X  `sshC_productionReadyL_epP_blkIO`: blkLu's statement (its `section BlkLuTop` variables and notations, copied) with
     `hdinS`, `hdoutS` replaced by `hdinX`, `hdoutX`: the same doom conclusions under the reduced hypotheses
     `¬ InSat Rp.inp epW (bndPlanes … 0)` resp. `¬ (b ≤ 1 ∧ OutCSat Rp.out (bndPlanes … 26 (Rp.row, ·)) b)`, which are
     what `¬ InOkP`, `¬ OutOkP` say on the wrapped extractor (`epxIO_inOkP`, `epxIO_outOkP`; the conjuncts
     `epW = tokW` and `xC = B_26(row, ·)` hold by definition). `E0b` (an explicit binder for the section variable `E0`):
     the wrapper's base, whose only field the composed extractor still reads is `r'`. Proof: blkLu at `E0 := epxIOE … E0b`.
Usage: l63_mk_topbx.py <worktree root> [--check]"""
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


src = open(F + "RunShieldBlkInst.lean").read()
o0 = src.index("open scoped ENNReal Polynomial\n")
o1 = src.index("\n\n/-! ## 1.", o0)
OPENS = src[o0:o1 + 1]
s0 = src.index("section BlkLuTop\n")
s1 = src.index("/-- **JOINED CONCRETE SHIELDSTRAL T128 R13 TOP THEOREM")
header = src[s0:s1]
t0 = src.index("theorem sshC_productionReadyL_epP_blkLu\n")
t1 = src.index(" := by\n", t0)
stmt = src[t0:t1]

binders = []
i = len("theorem sshC_productionReadyL_epP_blkLu")
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


names = [bname(b) for b in binders]
assert names[0] == ["ι"] and names[1] == ["Fintype", "ι"], names
assert names[2:] == [["site"], ["kOf"], ["δOf"], ["O"], ["hLI_stg"], ["hLO_stg"], ["hdinS"], ["hdoutS"]], names

# the old hypotheses, and their replacements
EXT = ("(epxE (CinB)\n"
       "        (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos\n"
       "        (epxOps tag Lq (le64_of_le20 hL20) key DomB HsB HLB abRdIn 11 6 (N := 2 ^ 11))\n"
       "        (epxBndE shdP_U tag Lq (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf (RnB).rd RkDLB shieldDPos0 E0))\n"
       "        (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)")
din = binders[8]
old_in = "¬ InOkP Rp (" + EXT + " →"
assert din.count(old_in) == 1, din
new_in = ("¬ InSat Rp.inp ((EXTB E0b) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).tokW\n"
          "        (((EXTB E0b) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes 0) →")
dinX = din.replace(old_in, new_in).replace("(hdinS :", "(hdinX :", 1)
dout = binders[9]
EXT2 = EXT.replace("\n        ", "\n          ")
old_out = "¬ OutOkP Rp ((ProtoClampedB).ypub (A.runLog G).1.1)\n        (" + EXT2 + " →"
assert dout.count(old_out) == 1, dout
# `PubOut` is not reducibly `ℕ` (no `LE` instance is found): the verdict is written `s.verdict` (`ypub s := s.verdict`)
new_out = ("¬ ((A.runLog G).1.1.verdict ≤ 1\n"
           "        ∧ OutCSat Rp.out ((EXTB E0b) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC\n"
           "          (A.runLog G).1.1.verdict) →")
doutX = dout.replace(old_out, new_out).replace("(hdoutS :", "(hdoutX :", 1)
# `E0` no longer occurs in the statement (only `r'` of it is read): an explicit binder `E0b`, the wrapper's base (a
# notation naming the section variable `E0` would capture it hygienically)
E0B = "(E0b : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (EpxSalt 6))"
keptX = binders[:6] + [E0B] + binders[6:8] + [dinX, doutX]
stmtX = "theorem sshC_productionReadyL_epP_blkIO" + "".join("\n    " + b for b in keptX) + "\n    " + concl

NOTS = ('\nlocal notation "OpsB" => epxOps (Hdr := Hdr) tag Lq (le64_of_le20 hL20) key DomB HsB HLB abRdIn 11 6 (N := 2 ^ 11)\n\n'
        '-- the composed run extractor at the wrapper\'s base `E0b` (a theorem binder, so it is passed explicitly)\n'
        'local notation "EXTB" e:max =>\n'
        '  epxE (CinB) (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos\n'
        '    (OpsB) (epxBndE shdP_U tag Lq (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf (RnB).rd RkDLB shieldDPos0\n'
        '      (epxIOE (CinB) shdP_epPos (OpsB) shdP_U tag (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf (RnB).rd RkDLB\n'
        '        shieldDPos0 26 Rp.row e))\n')
hdr2 = header.replace("section BlkLuTop\n", "section BlkIOTop\n", 1) + NOTS + "\n"

VARS = ["tag", "Lq", "hL20", "hL64", "key", "Rp", "hR", "hw", "hhdrFit", "preA", "preB", "check0", "paths", "digest",
        "bndCheck", "ioIn", "ioOut", "checkOpening", "embDigest", "embFold", "bInRow", "wDigest", "bOutRow", "P",
        "epBase"]
BINDS = ["site", "kOf", "δOf", "O", "hLI_stg", "hLO_stg"]
args = ["(Hdr := Hdr)", "(Coins := Coins)"] + ["(%s := %s)" % (n, n) for n in VARS + BINDS]
# `epW = tokW` and `xC = B_26(row, ·)` by the wrapper's equation lemmas (`epxIO_epW_tokW`, `epxIO_xC_planes`): a direct
# `rfl` on the concrete extractor exceeds the elaborator's maximum recursion depth
bodyX = ("  exact sshC_productionReadyL_epP_blkLu\n    "
         + "\n    ".join(" ".join(args[x:x + 8]) for x in range(0, len(args), 8))
         + "\n    (E0 := epxIOE (CinB) shdP_epPos (OpsB) shdP_U tag (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf\n"
         "      (RnB).rd RkDLB shieldDPos0 26 Rp.row E0b)\n"
         "    (hdinS := fun A G hv hb hn => hdinX A G hv hb (fun h => hn ⟨h, fun _ => epxIO_epW_tokW ..⟩))\n"
         "    (hdoutS := fun A G hv hb hn => hdoutX A G hv hb (fun h => hn ⟨h.1, h.2, fun _ =>\n"
         "      epxIO_xC_planes (hLb := shdP_blks_length hR) (hrow := rfl) ..⟩))\n")

doc = ("/-- **THE CONCRETE TOP THEOREM ON THE WRAPPED EXTRACTOR** (D63 lane L63): lane L68a's\n"
       "`sshC_productionReadyL_epP_blkLu` at `E0 := epxIOE … E0b` (`tokW` := the decoded input endpoint words, `xC i` :=\n"
       "the extracted boundary plane `26` at `(Rp.row, i)`, by construction). `hdinS`, `hdoutS` are replaced by `hdinX`,\n"
       "`hdoutX`: the same dooms under `¬ InSat Rp.inp epW B_0` resp. `¬ (b ≤ 1 ∧ OutCSat Rp.out B_26(row, ·) b)`, which is\n"
       "what `¬ InOkP`, `¬ OutOkP` say on the wrapped extractor (`epxIO_inOkP`, `epxIO_outOkP`; here by definition). -/\n")
pre = ("/-\nD63 lane L63 (2026-11-18), part 49: **lane L68a's concrete top theorem on the wrapped run extractor**\n"
       "(`sshC_productionReadyL_epP_blkIO`). Generated by `results/zk60_lean_l63_20261116/l63_mk_topbx.py` from\n"
       "`sshC_productionReadyL_epP_blkLu` (RunShieldBlkInst.lean, not edited): its `section BlkLuTop` variables and\n"
       "notations are copied (the private `zero_lt_26_blk` renamed `bx_zero_lt_26_blk`), its binder list is kept except\n"
       "`hdinS hdoutS`, which become `hdinX hdoutX`; the section variable `E0` is replaced by the explicit binder `E0b` after `O`.\n\n"
       "Changes against blkLu: `E0b` (for `E0`) is the base of the wrapper `epxIOE` (RunStgShieldEpxIO.lean; the coordinator's\n"
       "ruling: `tokW := epW`, `xC` from plane `26`, by construction); `hdinS`'s hypothesis `¬ InOkP Rp (…)` is now\n"
       "`¬ InSat Rp.inp epW (bndPlanes … 0)`, `hdoutS`'s `¬ OutOkP Rp b (…)` is now\n"
       "`¬ (b ≤ 1 ∧ OutCSat Rp.out (bndPlanes … 26 (Rp.row, ·)) b)`; nothing added. The conclusion is blkLu's.\n"
       "Remaining premises: `hLI_stg hLO_stg hdinX hdoutX` and blkLu's instantiation leftovers.\n"
       "`sshC_productionReadyL_epP_blkIOv`: further `hdoutX` -> `hdoutC` (hypothesis `¬ OutCSat …` alone; `b ≤ 1` is PROVED\n"
       "from acceptance: the block-0 check `vdChk check0` refuses a verdict above 1).\n\n"
       "Only `propext`, `Classical.choice`, `Quot.sound`.\n-/\n"
       "import ZK60Formal.RunShieldBlkInst\nimport ZK60Formal.RunStgShieldEpxIO\n\n"
       "set_option autoImplicit false\nset_option linter.constructorNameAsVariable false\n\n"
       "namespace ZK60.ProtocolClassify\n\n"
       + OPENS + "open ZK60.Out (OutCSat)\n\n")

# --- V: the verdict bound discharged (an accepted run passed `vdChk`, which refuses a verdict above 1)
old_v = ("¬ ((A.runLog G).1.1.verdict ≤ 1\n"
         "        ∧ OutCSat Rp.out ((EXTB E0b) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC\n"
         "          (A.runLog G).1.1.verdict) →")
assert doutX.count(old_v) == 1, doutX
new_v = ("¬ OutCSat Rp.out ((EXTB E0b) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC\n"
         "        (A.runLog G).1.1.verdict →")
doutC = doutX.replace(old_v, new_v).replace("(hdoutX :", "(hdoutC :", 1)
keptV = keptX[:-1] + [doutC]
stmtV = "theorem sshC_productionReadyL_epP_blkIOv" + "".join("\n    " + b for b in keptV) + "\n    " + concl
argsV = ["(Hdr := Hdr)", "(Coins := Coins)"] + ["(%s := %s)" % (n, n) for n in VARS + BINDS + ["E0b", "hdinX"]]
bodyV = ("  have hvd : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),\n"
         "      (ProtoClampedB).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → (A.runLog G).1.1.verdict ≤ 1 :=\n"
         "    fun A G hv => vdChk_le check0 _\n"
         "      (vd_check0_of_accept _ _ _ _ (rc_uexecP_E (h := hv) ..) (Nat.succ_pos 25))\n"
         "  exact sshC_productionReadyL_epP_blkIO\n    "
         + "\n    ".join(" ".join(argsV[x:x + 8]) for x in range(0, len(argsV), 8))
         + "\n    (hdoutX := fun A G hv hb hn => hdoutC A G hv hb (fun h => hn ⟨hvd A G hv, h⟩))\n")
docV = ("/-- **THE VERDICT BOUND DISCHARGED** (D63 lane L63): `sshC_productionReadyL_epP_blkIO` with `hdoutX` replaced by\n"
        "`hdoutC`, the same doom under `¬ OutCSat Rp.out B_26(row, ·) b` alone: on an accepted run `b ≤ 1` holds, since the\n"
        "block-0 statement check is `vdChk check0`, which refuses a verdict above `1` (`vd_check0_of_accept`, `vdChk_le`). -/\n")
text = (pre + hdr2 + doc + stmtX + " := by\n" + bodyX + "\n" + docV + stmtV + " := by\n" + bodyV
        + "\nend BlkIOTop\n\nend ZK60.ProtocolClassify\n")
assert text.count("zero_lt_26_blk") >= 2
text = text.replace("zero_lt_26_blk", "bx_zero_lt_26_blk")
dst = F + "RunStgShieldTopBx.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("RunStgShieldTopBx.lean", "identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst, "binders", len(keptX), "of", len(binders))
