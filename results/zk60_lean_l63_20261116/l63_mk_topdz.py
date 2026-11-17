#!/usr/bin/env python3
"""D63 lane L63 (2026-11-17): write formal/ZK60Formal/RunStgShieldTopDz.lean, the combined top theorem with `hdzW`
PROVED (`sshC_productionReadyL_epP_dz`), from lane L64's `sshC_productionReadyL_epP_blkAlive`
(RunBlkAliveR13.lean, not edited):

  D1  binders removed: `hIOI`, `hIOlI` (PROVED from the concrete `csIOI`), `hdzW` (PROVED: `ssh_hdzW_core`);
  D2  binders added after `csIOI csIOO`: `rO lcO QO`, `XO` (stage IN-C's `B_in` matrix over the view, still free),
      `hcsI : csIOI = stgCsIOm … (epDecX … (CinS).decodeIn) XO` (stage IN-C's IO semantics pinned: a claim on the input
      endpoint is its functional on the rows the input commitment's `decodeIn` decodes from L58's checked extractor at
      the header's input root), `hXOl` (`XO` reads the view below the slot phase), and after `hLay`: `hVi` (stage IN-C's
      profile: `lt ≤ 12`, `epLogN = 8`, `in_ep_words` a power of two, a non-empty slot list) and `hPlace` (the input
      commitment's data rows come first, the code's `ep_mask_row = ep_data_rows`);
  D3  the proof: `sshC_productionReadyL_epP_blkAlive` with every binder passed by name and the three removed ones proved.
Usage: l63_mk_topdz.py <worktree root> [--check]"""
import re
import sys

WT = sys.argv[1]
F = WT + "/formal/ZK60Formal/"


def rep(t, old, new, n=1):
    assert t.count(old) == n, (t.count(old), n, old[:100])
    return t.replace(old, new)


def balanced_from(s, i):
    assert s[i] in "([{", s[i:i + 20]
    op = s[i]
    cl = {"(": ")", "[": "]", "{": "}"}[op]
    d = 0
    for j in range(i, len(s)):
        if s[j] in "([{":
            d += 1
        elif s[j] in ")]}":
            d -= 1
            if d == 0:
                return j + 1
    raise AssertionError("unbalanced")


src = open(F + "RunBlkAliveR13.lean").read()
a = src.index("variable {Hdr Coins : Type}", src.index("section SshTopBlkAlive"))
pre = src[src.index("section SshTopBlkAlive"):a]
t0 = src.index("theorem sshC_productionReadyL_epP_blkAlive")
doc0 = src.rindex("/--", 0, t0)
vars_ = src[a:doc0]
stmt_end = src.index(" :=\n", t0)
stmt = src[t0:stmt_end]
# binders
binders = []
i = stmt.index("\n    ")
while True:
    j = stmt.find("\n    ", i)
    if j < 0:
        break
    k = j + 5
    if stmt[k] not in "([{":
        break
    e = balanced_from(stmt, k)
    binders.append((j, e, stmt[k:e]))
    i = e
concl_start = binders[-1][1]
names = []
for (_, _, b) in binders:
    if b.startswith("["):
        continue
    inner = b[1:-1]
    nm = inner.split(" : ", 1)[0].split()
    names += nm
drop = {"hIOI", "hIOlI", "hdzW"}
kept = []
for (j, e, b) in binders:
    nm = b[1:-1].split(" : ", 1)[0].split()
    if set(nm) & drop:
        assert len(nm) == 1, nm
        continue
    kept.append(b)
    if nm == ["csIOI", "csIOO"]:
        kept += [
            "(rO lcO QO : ℕ)",
            "(XO : StgVw Lq → Fin rO → Fin (2 ^ lcO + QO) → K)",
            "(hcsI : csIOI = ZK60.ProtocolClassify.stgCsIOm U Rr 8 256 rO lcO QO\n"
            "      (ZK60.ProtocolClassify.epDecX tag Lq h64 key domain hs hL ZK60.ProtocolClassify.abRdIn 11 1 Rr 8 256 (2 ^ 11)\n"
            "        (fun ops => (CinS).decodeIn ops 768)) XO)",
            "(hXOl : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) XO)"]
    if nm == ["hLay"]:
        kept += [
            "(hVi : Vi.pub.lt ≤ ogStage.lc ∧ Vi.pub.epLogN = 8 ∧ 2 ^ ZK60.Exec.StageV.clog2 Vi.pub.inEpWords = Vi.pub.inEpWords\n"
            "      ∧ 0 < P0in.geom.slots.length)",
            "(hPlace : ∀ k : Fin dR, (place k).val = k.val)"]
assert "hcsI" in " ".join(kept) and "hPlace" in " ".join(kept)
concl = stmt[concl_start:]
head = stmt[:binders[0][0]]
newstmt = head.replace("theorem sshC_productionReadyL_epP_blkAlive", "theorem sshC_productionReadyL_epP_dz") + \
    "".join("\n    " + b for b in kept) + concl
secvars = ["Rr", "dR", "hpos", "place", "hplace", "tag"]
args = ["(%s := %s)" % (n, n) for n in secvars] + ["(%s := %s)" % (n, n) for n in names if n not in drop]
HE = ("rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck "
      "bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'")
proofs = [
    "(hIOI := by rw [hcsI]; exact ZK60.ProtocolClassify.stgCsIOm_value U Rr 8 256 rO lcO QO _ XO)",
    "(hIOlI := by\n      rw [hcsI]\n      exact ZK60.ProtocolClassify.vwLoc_stgCsIOm U Rr 8 256 rO lcO QO _ _ XO\n"
    "        (ZK60.ProtocolClassify.vwLoc_epDecX tag Lq h64 key domain hs hL ZK60.ProtocolClassify.abRdIn 11 1 Rr 8 256 (2 ^ 11) _\n"
    "          (by omega) _) hXOl)",
    "(hdzW := fun A G hv' hx' hz => by\n"
    "      obtain ⟨k, i, hT, hlt, hnz⟩ := hz\n"
    "      have hE0 := " + HE + "\n"
    "      rw [OC.runLog_fst] at hE0\n"
    "      rw [OC.runLog_fst] at hnz\n"
    "      obtain ⟨x0, hx0d⟩ : ∃ x0, x0 = k.val * 2 ^ 8 + i.val := ⟨_, rfl⟩\n"
    "      rw [← hx0d] at hT hlt\n"
    "      have hk : x0 / 2 ^ 8 = k.val := by\n"
    "        have := i.isLt; rw [hx0d, Nat.add_comm, Nat.add_mul_div_right _ _ (by norm_num), Nat.div_eq_of_lt this, zero_add]\n"
    "      have hi : x0 % 2 ^ 8 = i.val := by\n"
    "        have := i.isLt; rw [hx0d, Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt this]\n"
    "      have hR : x0 / 2 ^ 8 < Rr := by rw [hk, ← hPlace k]; exact (place k).isLt\n"
    "      have e1 : (CinS).place k = ⟨x0 / 2 ^ 8, hR⟩ := Fin.ext (by\n"
    "        show (place k).val = x0 / 2 ^ 8; rw [hPlace k, hk])\n"
    "      have e2 : i = ⟨x0 % 2 ^ 8, Nat.mod_lt _ (Nat.two_pow_pos 8)⟩ := Fin.ext hi.symm\n"
    "      rw [e1] at hnz\n"
    "      rw [e2] at hnz\n"
    "      subst hcsI\n"
    "      exact ZK60.ProtocolClassify.ssh_hdzW_core U hbij tag h64 hU key domain hs hL P0in Vi\n"
    "        (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch))\n"
    "        (fun ch => by rw [hinc]) _ _ _ _ _ _ _ _ _ Rr rO lcO QO XO (fun ops => (CinS).decodeIn ops 768) _ _ _ _ _ G _ _\n"
    "        (A.run G).1.inRoot (fun ch => hPin _ _) (fun ch k' hk' => (Iin.hgeomL _ _ k' hk').1) (fun ch => Iin.hgt _)\n"
    "        hVi.2.2.2 hVi.1 hVi.2.1 hVi.2.2.1\n"
    "        (fun a ha => ZK60.ProtocolClassify.ab_rdIn_at1 hw Rn hRn G (A.run G).1 (A.run G).2 hE0 a ha)\n"
    "        x0 hT hlt hR hnz)",
]
body = ("  exact sshC_productionReadyL_epP_blkAlive " + "\n    ".join(
    [" ".join(args[x:x + 6]) for x in range(0, len(args), 6)]) + "\n    " + "\n    ".join(proofs) + "\n")
doc = ("/-- **THE COMBINED TOP THEOREM WITH `hdzW` PROVED** (D63 lane L63): lane L64's `sshC_productionReadyL_epP_blkAlive`\n"
       "with stage IN-C's IO semantics pinned (`hcsI`: a claim on the input endpoint is its functional on the rows the\n"
       "input commitment's `decodeIn` decodes from L58's checked extractor at the header's input root; `B_in`'s matrix `XO`\n"
       "still free), so `hIOI`, `hIOlI` and `hdzW` are PROVED (`stgCsIOm_value`, `vwLoc_stgCsIOm`, `ssh_hdzW_core`).\n"
       "New premises: `hcsI`, `hXOl`, `hVi`, `hPlace`. -/\n")
text = ("/-\nD63 lane L63 (2026-11-17), part 36: **the combined top theorem with `hdzW` PROVED**\n"
        "(`sshC_productionReadyL_epP_dz`). Generated by `results/zk60_lean_l63_20261116/l63_mk_topdz.py` from lane L64's\n"
        "`sshC_productionReadyL_epP_blkAlive` (RunBlkAliveR13.lean, not edited).\n\n"
        "Only `propext`, `Classical.choice`, `Quot.sound`.\n-/\n"
        "import ZK60Formal.RunBlkAliveR13\nimport ZK60Formal.RunStgShieldDzRun\n\n"
        "set_option autoImplicit false\nset_option linter.constructorNameAsVariable false\n\n"
        "namespace ZK60.ProtocolClassify\n\nnamespace RunShapeP\n\n"
        + pre.replace("section SshTopBlkAlive", "section SshTopDz") + vars_ + doc + newstmt + " := by\n" + body
        + "\nend SshTopDz\n\nend RunShapeP\n\nend ZK60.ProtocolClassify\n")
dst = F + "RunStgShieldTopDz.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("RunStgShieldTopDz.lean", "identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst, len(kept), "binder groups; names", len(names))
