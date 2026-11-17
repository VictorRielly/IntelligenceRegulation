#!/usr/bin/env python3
"""D63 lane L63 (2026-11-16): write formal/ZK60Formal/RunStgShieldInAHRun.lean (stage IN-C's A/H claims on an accepted
run) by reusing the binder list and the proof of `ssh_run_AHO` (RunStgShieldClaims.lean) at part 0.
Usage: l63_mk_inahrun.py <worktree root> [--check]  (--check: compare with the file on disk, write nothing)"""
import sys

WT = sys.argv[1]
src = open(WT + "/formal/ZK60Formal/RunStgShieldClaims.lean").read()
i = src.index('section Run')
j = src.index('theorem ssh_run_AHO')
k = src.index('    (hA : ¬ (rtKA', j)
k2 = src.index('\n', src.index('(R.tr G (A.run G)))', k)) + 1
binders = src[j + len('theorem ssh_run_AHO'):k2].rstrip()
if binders.endswith(':'):
    binders = binders[:-1].rstrip()
assert binders.endswith(')')
hdr = src[i:src.rindex("/--", i, j)]
pj = src.index(':= by\n', k2)
proof = src[pj:src.index('end Run', pj)]
reps = [
    ('have hi : Lb + 1 < R.pf.parts.length := by omega', 'have hi : 0 < R.pf.parts.length := by omega'),
    ('(i := Lb + 1)', '(i := 0)'),
    ('hA (Lb + 1)\n    hi hn', 'hA 0\n    hi hn'),
    ('(Lb + 1)).gA', '0).gA'), ('(Lb + 1)).nA', '0).nA'), ('(Lb + 1)).gH', '0).gH'), ('(Lb + 1)).nH', '0).nH'),
    ('(rxAcc Win Wout Pk R.pf Lb (Lb + 1) hdr)', '(rxAcc Win Wout Pk R.pf Lb 0 hdr)'),
    ('[rxLsc lscIn lscOut Pk Lb (Lb + 1)]', '[rxLsc lscIn lscOut Pk Lb 0]'),
    ('    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv\n    rw [rxPs_out] at hv\n    exact hv',
     '    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv\n    exact hv'),
]
for a, b in reps:
    assert a in proof, a
    proof = proof.replace(a, b)
left = [l for l in proof.splitlines() if 'Lb + 1' in l and 'Lb + 2' not in l]
assert not left, left
concl = ''' :
    (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb 0
        ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA))).claims.a,
      claimSem U I.pA.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h I.pA.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA)) (R.pf.off 0 + 5))
          (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA)) (R.pf.off 0 + 5))))
        z = z.value.toK U)
    ∧ (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb 0
        ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))).claims.h,
      claimSem U I.pH.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h I.pH.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
            (R.pf.off 0 + (5 + (4 + mIn)))) (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
          (R.pf.off 0 + (5 + (4 + mIn)))))) z = z.value.toK U) '''
head = open(WT + "/results/zk60_lean_l63_20261116/l63_inahrun_head.lean.txt").read()
tail = open(WT + "/results/zk60_lean_l63_20261116/l63_inahrun_tail.lean.txt").read()
out = (head + hdr + "/-- **STAGE IN-C'S `A`/`H` CLAIMS ARE TRUE OF THE RUN'S EXTRACTED MATRICES** at their opening windows, on an "
       "accepted run\noutside `EvXR` with no doomed `opA` entrant. -/\ntheorem ssh_run_AHI" + binders + concl
       + proof.rstrip() + "\n\n/-- **STAGE IN-C'S `A`/`H` CLAIMS PART ON AN ACCEPTED RUN** outside `EvXR`, no doomed "
       "`opA` entrant. -/\ntheorem ssh_AHAtI" + binders + tail)
dst = WT + "/formal/ZK60Formal/RunStgShieldInAHRun.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == out
    print("RunStgShieldInAHRun.lean", "identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(out)
print("wrote")
