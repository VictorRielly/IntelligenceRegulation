#!/usr/bin/env python3
"""D63 lane L63 (2026-11-16): write formal/ZK60Formal/RunStgShieldC.lean, the per-slot-width IN-C slot polynomial
(`stgFRC`, `stgFstIC`) and its terminal theorem `stgFR_termAtC`, the twin of L57's `stgFR_termAt`
(RunStgAlgPoly.lean), whose proof is copied here with the three width-dependent steps changed (counted replacements).
Usage: l63_mk_c.py <worktree root> [--check]"""
import sys

WT = sys.argv[1]
src = open(WT + "/formal/ZK60Formal/RunStgAlgPoly.lean").read()
a = src.index("theorem stgFR_termAt ")
b = src.index("end Real", a)
thm = src[a:b]


def once(t, old, new):
    assert t.count(old) == 1, (t.count(old), old[:80])
    return t.replace(old, new)


VIEW = ("(stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)\n"
        "            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)\n"
        "              ++ Block.slotPreOps (Pof ch) k q)))")
thm = once(thm, "theorem stgFR_termAt ", "theorem stgFR_termAtC ")
thm = once(thm, "    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)\n",
           "    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)\n"
           "    (csv : StgVw L → Block.Cm → Block.ZClaim → K)\n")
thm = once(thm, "    (htrue : StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ) :\n"
                "    StgTermAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) G Lg τ := by",
           "    (htrue : StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ) :\n"
           "    StgTermAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) G Lg τ := by")
thm = once(thm, "  obtain ⟨hPv, hcl, hm⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq",
           "  obtain ⟨hPv, hclA, hclH, hclIO, hm⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq")
old_htr = thm[thm.index("      have htr : ∀ q' ∈ Block.slotClaimList (Pof ch)"):thm.index("      have hpoly := ")]
new_htr = ("      have htr : ∀ q' ∈ Block.slotClaimList (StageV.atLog (Pof ch) (elogv " + VIEW + " k)) r.rho r.es q.terms\n"
           "          df.tabs 0, csv " + VIEW + " q'.1 q'.2 = q'.2.value.toK U := by\n"
           "        intro q' hq'\n"
           "        obtain ⟨c1, z1⟩ := q'\n"
           "        have hdfk : (Pof ch).define k (Block.histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k))\n"
           "            r.draws = .ok df := hdf\n"
           "        cases c1 with\n"
           "        | a => exact hclA z1 (hclk (Block.Cm.a, z1) (StageV.ssh_scl_ah (Pof ch) _ r.rho r.es q.terms df.tabs 0 _ hq' (Or.inl rfl)))\n"
           "        | h => exact hclH z1 (hclk (Block.Cm.h, z1) (StageV.ssh_scl_ah (Pof ch) _ r.rho r.es q.terms df.tabs 0 _ hq' (Or.inr rfl)))\n"
           "        | inp => exact hclIO r df hr hdfk _ hq' (Or.inl rfl)\n"
           "        | out => exact hclIO r df hr hdfk _ hq' (Or.inr rfl)\n")
thm = once(thm, old_htr, new_htr)
thm = once(thm, "      have hpoly := stgPolyT_eval U hbij hU (Pof ch) (csv",
           "      have hpoly := stgPolyT_eval U hbij hU (StageV.atLog (Pof ch) (elogv " + VIEW + " k)) (csv")
thm = once(thm, "      show r.fin.toK U = stgPolyT U hbij (Pv _ ch) (csv _) k",
           "      show r.fin.toK U = stgPolyT U hbij (StageV.atLog (Pv _ ch) (elogv _ k)) (csv _) k")
thm = once(thm, "      have hp' : stgPolyT U hbij (Pof ch) (csv",
           "      have hp' : stgPolyT U hbij (StageV.atLog (Pof ch) (elogv " + VIEW + " k)) (csv")

head = open(WT + "/results/zk60_lean_l63_20261116/l63_c_head.lean.txt").read()
tail = open(WT + "/results/zk60_lean_l63_20261116/l63_c_tail.lean.txt").read()
text = head + thm + tail
dst = WT + "/formal/ZK60Formal/RunStgShieldC.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst)
