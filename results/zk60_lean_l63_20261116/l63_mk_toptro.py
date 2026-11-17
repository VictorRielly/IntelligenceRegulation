#!/usr/bin/env python3
"""D63 lane L63 (2026-11-17): write formal/ZK60Formal/RunStgShieldTopTrO.lean, `sshC_productionReadyL_epP_trO`: the `trI`
top (below) with `hTrOIO` also PROVED (`ssh_trOIO_run`, RunStgShieldTrOIO.lean) and stage OUT-C's `B_out` matrix pinned:
`hcsO : csIOO = stgCsIOm U Oout.pX.rows 14 256 rE lcE Qe (bxUxV … Oout.pX.rows (off Lb + 2)) XE` (part `Lb + 1`'s
closing opening, the one `bndPlanes` reads for plane `Lb`), so the binders `rB lcB Qb XB hXBl` are gone and `hwB` reads
`∀ b, (F b).geo.bLogN ≤ 14`. `XE` (the output endpoint) stays free: the kinds data have no part after `Lb + 1`, and the
code refuses every output-endpoint claim (`ssh_outc_out_nil`), so `hTrOIO`'s `.out` half holds for every `XE`.

D63 lane L63 (2026-11-17): write formal/ZK60Formal/RunStgShieldTopTrI.lean, `sshC_productionReadyL_epP_trI`: the `io`
top (l63_mk_topio.py) with `hTrIIO` also PROVED (`ssh_trIIO_run`, RunStgShieldTrIIO.lean: stage IN-C's IO claims of the
code's accumulator are true of the pinned semantics on an accepted run outside the events with no doomed `opA`
entrant). No premise added. The `io` generator's description follows.

D63 lane L63 (2026-11-17): write formal/ZK60Formal/RunStgShieldTopIO.lean, lane L66's top theorem with stage IN-C's IO
semantics pinned to the matrices the run's openings check (`sshC_productionReadyL_epP_io`), from
`sshC_productionReadyL_epP_pinsHd` (RunBlkPinsHd.lean, not edited). A copy of l63_mk_toppd.py (the `pdz` top) with:
  I1  `hcsI` re-pinned: `csIOI = stgCsIOm U Rr 8 256 (pXk 0).rows 14 256 (epUxV … Rr) (bxUxV … (pXk 0).rows (off 0 + 2))`:
      the input endpoint's matrix is part 0's closing opening's (`ebOpen`, repair B) unchecked matrix decoded at the
      endpoint code (not `decodeIn` on L58's checked extractor: HANDOFF_20261117.md section 2), and `B_in`'s matrix is
      part 1's closing opening's (`rkOpen` at `rkR13 (pXk 0).rows (off 0 + 2)`, the opening `bndPlanes` reads for plane
      0) decoded at R13's code. So the binders `rO lcO QO XO` and `hXOl` are gone, and `hwO` reads `Vi.geo.bLogN ≤ 14`;
  I2  `hdzW` re-proved through `ssh_hdzW_coreU` (`ssh_ep_bridge`: on `decodeIn`'s existence branch the decoded unchecked
      matrix is the `decodeIn` rows; off it `decodeIn` is 0).
Everything else as in l63_mk_toppd.py: removed `hIOI`, `hIOlI`, `hdzW`, `hCsIO`, `hIOO`, `hIOlO`; added `hcsO` (OUT-C's IO
semantics on `XB`, `XE`, still free) with `rB lcB Qb rE lcE Qe XB XE hXBl hXEl hwB`, and after `hLay` `hVi`, `hPlace`.
Usage: l63_mk_toptro.py <worktree root> [--check]"""
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


src = open(F + "RunBlkPinsHd.lean").read()
a = src.index("variable {Hdr Coins : Type}", src.index("section SshTopPinsHd"))
pre = src[src.index("section SshTopPinsHd"):a]
t0 = src.index("\ntheorem sshC_productionReadyL_epP_pinsHd\n") + 1
vars_ = src[a:src.index("private theorem", a)]
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
drop = {"hIOI", "hIOlI", "hdzW", "hCsIO", "hIOO", "hIOlO", "hTrIIO", "hTrOIO"}
XBP = "ZK60.ProtocolClassify.bxUxV tag Lq h64 Oout.pX.rows ((RtRun.pf Rn).off Lb + 2)"
SHD = ("U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut\n"
       "          pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut\n"
       "          Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn\n"
       "          (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)\n"
       "          (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)\n"
       "          (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO")
X8 = "_ _ _ _ _ _ _ _"
XOP = "ZK60.ProtocolClassify.bxUxV tag Lq h64 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2)"
XIP = "ZK60.ProtocolClassify.epUxV tag Lq h64 key domain hs hL Rr"
kept = []
for (j, e, b) in binders:
    nm = b[1:-1].split(" : ", 1)[0].split()
    if set(nm) & drop:
        assert len(nm) == 1, nm
        continue
    kept.append(b)
    if nm == ["csIOI", "csIOO"]:
        kept += [
            "(hcsI : csIOI = ZK60.ProtocolClassify.stgCsIOm U Rr 8 256 (pXk 0).rows 14 256\n"
            "      (" + XIP + ")\n      (" + XOP + "))",
            "(hwO : Vi.geo.bLogN ≤ 14)",
            "(rE lcE Qe : ℕ)",
            "(XE : ZK60.ProtocolClassify.StgVw Lq → Fin rE → Fin (2 ^ lcE + Qe) → K)",
            "(hcsO : csIOO = ZK60.ProtocolClassify.stgCsIOm U Oout.pX.rows 14 256 rE lcE Qe\n"
            "      (" + XBP + ") XE)",
            "(hXEl : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) XE)",
            "(hwB : ∀ b, (F b).geo.bLogN ≤ 14)"]
    if nm == ["hLay"]:
        kept += [
            "(hVi : Vi.pub.epLogN = 8 ∧ 2 ^ ZK60.Exec.StageV.clog2 Vi.pub.inEpWords = Vi.pub.inEpWords\n"
            "      ∧ 0 < P0in.geom.slots.length)",
            "(hPlace : ∀ k : Fin dR, (place k).val = k.val)"]
assert "hcsI" in " ".join(kept) and "hPlace" in " ".join(kept)
concl = stmt[concl_start:]
head = stmt[:binders[0][0]]
newstmt = head.replace("theorem sshC_productionReadyL_epP_pinsHd", "theorem sshC_productionReadyL_epP_trO") + \
    "".join("\n    " + b for b in kept) + concl
secvars = ["Rr", "dR", "hpos", "place", "hplace", "tag", "dPos0"]
args = ["(%s := %s)" % (n, n) for n in secvars] + ["(%s := %s)" % (n, n) for n in names if n not in drop]
HE = ("rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck "
      "bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'")
proofs = [
    "(hIOI := by rw [hcsI]; exact ZK60.ProtocolClassify.stgCsIOm_value U Rr 8 256 _ 14 256 _ _)",
    "(hIOlI := by\n      rw [hcsI]\n      exact ZK60.ProtocolClassify.vwLoc_stgCsIOm U Rr 8 256 _ 14 256 _ _ _\n"
    "        (ZK60.ProtocolClassify.vwLoc_epUxV tag Lq h64 key domain hs hL Rr _ (by omega))\n"
    "        (ZK60.ProtocolClassify.vwLoc_bxUxV tag Lq h64 _ _ _ (by omega)))",
    "(hIOO := by rw [hcsO]; exact ZK60.ProtocolClassify.stgCsIOm_value U Oout.pX.rows 14 256 rE lcE Qe _ XE)",
    "(hIOlO := by\n      rw [hcsO]\n"
    "      exact ZK60.ProtocolClassify.vwLoc_stgCsIOm U Oout.pX.rows 14 256 rE lcE Qe _ _ XE\n"
    "        (ZK60.ProtocolClassify.vwLoc_bxUxV tag Lq h64 _ _ _\n"
    "          (by have := (RtRun.pf Rn).off_le Lb; omega)) hXEl)",
    "(hCsIO := by\n      rw [hcsI, hcsO]\n"
    "      exact ⟨ZK60.ProtocolClassify.ssh_hIO0m U hbij hU Vi Rr 8 256 _ 14 256 _ _ (by rw [hVi.1]),\n"
    "        ZK60.ProtocolClassify.ssh_hIO1m U hbij hU Vi Rr 8 256 _ 14 256 _ _ hwO,\n"
    "        ZK60.ProtocolClassify.ssh_hIOOm U hbij hU F Oout.pX.rows 14 256 rE lcE Qe _ XE hwB⟩)",
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
    "      exact ZK60.ProtocolClassify.ssh_hdzW_coreU U hbij tag h64 hU key domain hs hL P0in Vi\n"
    "        (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch))\n"
    "        (fun ch => by rw [hinc]) _ _ _ _ _ _ _ _ _ Rr dR hpos place (ZK60.ProtocolClassify.epxMsg Rr dR place pos)\n"
    "        (ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace) ZK60.ProtocolClassify.EpxSalt.pads\n"
    "        ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths ClsStmt.inRoot tag\n"
    "        _ _ _ _ _ _ _ _ _ G _ _ (A.run G).1.inRoot (fun ch => hPin _ _) (fun ch k' hk' => (Iin.hgeomL _ _ k' hk').1)\n"
    "        (fun ch => Iin.hgt _) hVi.2.2 hlcStg.1 hVi.1 hVi.2.1\n"
    "        (fun a ha => ZK60.ProtocolClassify.ab_rdIn_at1 hw Rn hRn G (A.run G).1 (A.run G).2 hE0 a ha)\n"
    "        x0 hT hlt hR hnz)",
    "(hTrIIO := fun A G hDV hv' hx' _ _ hA => by\n"
    "      have hE0 := " + HE + "\n"
    "      rw [OC.runLog_fst] at hE0\n"
    "      rw [hcsI]\n"
    "      exact ZK60.ProtocolClassify.ssh_trIIO_run U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk\n"
    "        sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv hw hRn cx0 pin pout Iin bp wXk gXk mXk hσ hgeo\n"
    "        hXep hfitX pXk hXk hwX0 hmX0 hfitXk hLb1 Vi hinc (ZK60.ProtocolClassify.vdWout F)\n"
    "        (shdRkBase " + SHD + ")\n"
    "        _ _ _ _ _\n"
    "        ((shdRkBase_gX_nX " + SHD + " 0).1.trans\n"
    "          (shdRkBaseX_0_gX (K := K) Lq Lb (RtRun.pf Rn) " + X8 + ").1)\n"
    "        ((shdRkBase_gX_nX " + SHD + " 0).2.trans\n"
    "          (shdRkBaseX_0_gX (K := K) Lq Lb (RtRun.pf Rn) " + X8 + ").2)\n"
    "        ((shdRkBase_gX_nX " + SHD + " 1).1.trans\n"
    "          (shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn) " + X8 + ").1)\n"
    "        ((shdRkBase_gX_nX " + SHD + " 1).2.trans\n"
    "          (shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn) " + X8 + ").2)\n"
    "        _ hDV (shdRkD_eq_ebData " + SHD + ") _\n"
    "        (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (· + 2) (O.blocks.2 : Lb = Rp.blks.length))))\n"
    "        A G hE0 hx' hA Rr mIn hRr _ _ _ _ _ _ _)",
    "(hTrOIO := fun A G hDV hv' hx' _ _ hA => by\n"
    "      have hE0 := " + HE + "\n"
    "      rw [OC.runLog_fst] at hE0\n"
    "      have hW2 := ZK60.ProtocolClassify.vd_hW Rp Lb preA preB start inc incG\n"
    "        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768\n"
    "        key domain Rn hw hRn Vi F hinc houtc hchk hLb1 pin pout A G hv'\n"
    "      rw [hcsO]\n"
    "      exact ZK60.ProtocolClassify.ssh_trOIO_run U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk\n"
    "        sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout Oout bp wXk gXk mXk hσ hgeo\n"
    "        hOX hwXo hfitXo hLb1 hPkD.toShieldRunAt.lb_le (ZK60.ProtocolClassify.vdWin Vi)\n"
    "        (ZK60.ProtocolClassify.vdWout F)\n"
    "        (shdRkBase " + SHD + ")\n"
    "        _ _ _ _ _\n"
    "        (fun k hk => (shdRkBase_gX_nX " + SHD + " (k + 1 + 1)).1.trans\n"
    "          (shdRkBaseX_out_gX (K := K) Lq Lb (RtRun.pf Rn) " + X8 + " k hk).1)\n"
    "        (fun k hk => (shdRkBase_gX_nX " + SHD + " (k + 1 + 1)).2.trans\n"
    "          (shdRkBaseX_out_gX (K := K) Lq Lb (RtRun.pf Rn) " + X8 + " k hk).2)\n"
    "        _ hDV (shdRkD_eq_ebData " + SHD + ") _\n"
    "        (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (· + 2) (O.blocks.2 : Lb = Rp.blks.length))))\n"
    "        A G hE0 hW2.2 hx' hA rE lcE Qe XE _ _ _ _ _ _ _)",
]
body = ("  exact sshC_productionReadyL_epP_pinsHd " + "\n    ".join(
    [" ".join(args[x:x + 6]) for x in range(0, len(args), 6)]) + "\n    " + "\n    ".join(proofs) + "\n")
doc = ("/-- **L66'S TOP THEOREM WITH THE STAGES' IO SEMANTICS PINNED TO THE RUN'S OPENINGS AND `hTrIIO`, `hTrOIO` PROVED**\n"
       "(D63 lane L63): lane L66's `sshC_productionReadyL_epP_pinsHd` with `csIOI` pinned (`hcsI`): a claim on the input\n"
       "endpoint is its functional on part 0's closing opening's decoded unchecked matrix (`epUxV`), a claim on `B_in` its\n"
       "functional on part 1's closing opening's (`bxUxV` at `rkR13 (pXk 0).rows (off 0 + 2)`); `csIOO` pinned on `.inp`\n"
       "(`hcsO`): a claim on `B_out` is its functional on part `Lb + 1`'s closing opening's (`bxUxV` at\n"
       "`rkR13 Oout.pX.rows (off Lb + 2)`); the output endpoint's matrix `XE` is free (the code refuses every claim on it).\n"
       "`hdzW`, `hCsIO`, `hIOI`, `hIOO`, `hIOlI`, `hIOlO`, `hTrIIO`, `hTrOIO` are PROVED (`ssh_trIIO_run`, `ssh_trOIO_run`).\n"
       "New premises: `hcsI`, `hwO`, `hcsO`, `hXEl`, `hwB`, `hVi`, `hPlace`. -/\n")
text = ("/-\nD63 lane L63 (2026-11-17), part 45: **L66's top theorem with the stages' IO semantics pinned to the run's\n"
        "openings and `hTrIIO`, `hTrOIO` PROVED** (`sshC_productionReadyL_epP_trO`). Generated by\n"
        "`results/zk60_lean_l63_20261116/l63_mk_toptro.py` from lane L66's `sshC_productionReadyL_epP_pinsHd`\n"
        "(RunBlkPinsHd.lean, not edited).\n\n"
        "Only `propext`, `Classical.choice`, `Quot.sound`.\n-/\n"
        "import ZK60Formal.RunBlkPinsHd\nimport ZK60Formal.RunStgShieldTrOIO\n\n"
        "set_option autoImplicit false\nset_option linter.constructorNameAsVariable false\n\n"
        "namespace ZK60.ProtocolClassify\n\nnamespace RunShapeP\n\n"
        + pre.replace("section SshTopPinsHd", "section SshTopTrO") + vars_ + doc + newstmt + " := by\n" + body
        + "\nend SshTopTrO\n\nend RunShapeP\n\nend ZK60.ProtocolClassify\n")
dst = F + "RunStgShieldTopTrO.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("RunStgShieldTopTrO.lean", "identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst, len(kept), "binder groups; names", len(names))
