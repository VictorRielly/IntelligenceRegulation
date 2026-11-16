#!/usr/bin/env python3
"""D63 lane L63 (2026-11-16): write formal/ZK60Formal/RunStgShieldDefC.lean, the per-slot-width twins of this lane's
define chain (deliverable 1): `stgSpTC`, `stgSpTC_take`, `stgΦBC`, `stgΦRC`, `ssh_ΦB_zeroC`, `ssh_defAtVC`, `sshΦIC`,
`ssh_hDIC`, by counted text replacements in the originals (RunStgShieldDef.lean, RunStgShieldRd.lean,
RunStgShieldInst.lean). Usage: l63_mk_defc.py <worktree root> [--check]"""
import sys

WT = sys.argv[1]
F = WT + "/formal/ZK60Formal/"
dsrc = open(F + "RunStgShieldDef.lean").read()
rsrc = open(F + "RunStgShieldRd.lean").read()
isrc = open(F + "RunStgShieldInst.lean").read()


def rep(t, old, new, n=1):
    assert t.count(old) == n, (t.count(old), n, old[:90])
    return t.replace(old, new)


def between(t, a, b):
    i = t.index(a)
    return t[i:t.index(b, i)]


# --- stgSpT, stgSpT_take, stgΦB, stgΦR (section Def of RunStgShieldDef.lean) ---
sp = between(dsrc, "/-- **Slot `j`'s unmasked slot polynomial**", "end Def")
sp = rep(sp, "noncomputable def stgSpT (P0 P : Block.BlockParams) (cs",
         "noncomputable def stgSpTC (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs")
sp = rep(sp, "  fun x => stgPolyT U hbij P cs j (stgSnD bga ds) x",
         "  fun x => stgPolyT U hbij (StageV.atLog P (elog j)) cs j (stgSnD bga ds) x")
sp = rep(sp, "theorem stgSpT_take (P0 P : Block.BlockParams) (cs", "theorem stgSpTC_take (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs")
sp = rep(sp, "    stgSpT U hbij P0 P cs bga ds j = stgSpT U hbij P0 P cs bga ds' j := by",
         "    stgSpTC U hbij P0 P elog cs bga ds j = stgSpTC U hbij P0 P elog cs bga ds' j := by")
sp = rep(sp, "  refine stgPolyT_congr U hbij P cs j _ _ ?_ ?_ x",
         "  refine stgPolyT_congr U hbij (StageV.atLog P (elog j)) cs j _ _ ?_ ?_ x")
sp = rep(sp, "noncomputable def stgΦB (P0 P : Block.BlockParams) (cs", "noncomputable def stgΦBC (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs")
sp = rep(sp, "stgSpT U hbij P0 P cs bga", "stgSpTC U hbij P0 P elog cs bga", 5)
sp = rep(sp, "noncomputable def stgΦR (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)\n",
         "noncomputable def stgΦRC (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)\n"
         "    (elogv : StgVw L → ℕ → ℕ)\n")
sp = rep(sp, "  fun v k h y => stgΦB U hbij P0 (Pv v h.1) (csv v) (bgaOf h.1) h.2 k (stgWords U hbij y)",
         "  fun v k h y => stgΦBC U hbij P0 (Pv v h.1) (elogv v) (csv v) (bgaOf h.1) h.2 k (stgWords U hbij y)")

# --- ssh_ΦB_zero (section Zero) ---
zr = between(dsrc, "open Classical in\n/-- **ON AN ACCEPTING SLOT LOOP", "end Zero")
zr = rep(zr, "theorem ssh_ΦB_zero (hU : U ^ 2 = algebraMap GF K 7) (P0 P : Block.BlockParams) (cs",
         "theorem ssh_ΦB_zeroC (hU : U ^ 2 = algebraMap GF K 7) (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs")
n = zr.count("stgSpT U hbij P0 P cs bga")
zr = rep(zr, "stgSpT U hbij P0 P cs bga", "stgSpTC U hbij P0 P elog cs bga", n)
zr = rep(zr, "stgSpT_take U hbij P0 P cs bga", "stgSpTC_take U hbij P0 P elog cs bga")
zr = rep(zr, "stgΦB U hbij P0 P cs bga", "stgΦBC U hbij P0 P elog cs bga")
zr = rep(zr, "  unfold stgΦB\n", "  unfold stgΦBC\n")

# --- ssh_defAtV (section Main of RunStgShieldRd.lean) ---
dv = between(rsrc, "/-- **THE REAL STAGE DEFINE POLYNOMIAL VANISHES AT EVERY READING**", "end Main")
dv = rep(dv, "theorem ssh_defAtV ", "theorem ssh_defAtVC ")
dv = rep(dv, "    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)\n",
         "    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)\n"
         "    (csv : StgVw L → Block.Cm → Block.ZClaim → K)\n")
dv = rep(dv, "    (hlP : VwLoc nl Pv) (hlC : VwLoc nl csv)", "    (hlP : VwLoc nl Pv) (hlE : VwLoc nl elogv) (hlC : VwLoc nl csv)")
dv = rep(dv, "stgFR U hbij P0 Pv bgaOf csv Rv", "stgFRC U hbij P0 Pv elogv bgaOf csv Rv", dv.count("stgFR U hbij P0 Pv bgaOf csv Rv"))
dv = rep(dv, "    (htrue : StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ)",
         "    (htrue : StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ)")
dv = rep(dv, "    StgDefAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgΦR U hbij P0 Pv bgaOf csv) G Lg τ := by",
         "    StgDefAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgΦRC U hbij P0 Pv elogv bgaOf csv) G Lg τ := by")
dv = rep(dv, "  obtain ⟨hPv, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq",
         "  obtain ⟨hPv, -, -, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq")
dv = rep(dv, "  show stgΦB U hbij P0 (Pv _ ch) (csv _) (bgaOf ch)",
         "  show stgΦBC U hbij P0 (Pv _ ch) (elogv _) (csv _) (bgaOf ch)")
dv = rep(dv, "  rw [hwinD Pv hlP, hwinD csv hlC, hPv]", "  rw [hwinD Pv hlP, hwinD elogv hlE, hwinD csv hlC, hPv]")
dv = rep(dv, "  refine ssh_ΦB_zero U hbij hU P0 (Pof ch) (csv (stgVw absOf Lg τ))",
         "  refine ssh_ΦB_zeroC U hbij hU P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ))")
n = dv.count("stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ))")
dv = rep(dv, "stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ))",
         "stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ))", n)
dv = rep(dv, "      show stgPolyT U hbij (Pv (stgVw absOf Lg tj) ch) (csv (stgVw absOf Lg tj))",
         "      show stgPolyT U hbij (StageV.atLog (Pv (stgVw absOf Lg tj) ch) (elogv (stgVw absOf Lg tj) j))\n"
         "          (csv (stgVw absOf Lg tj))")
dv = rep(dv, "      rw [hW Pv hlP, hW csv hlC, hW Rv hlR, hPv,", "      rw [hW Pv hlP, hW elogv hlE, hW csv hlC, hW Rv hlR, hPv,")
dv = rep(dv, "      refine stgPolyT_congr U hbij (Pof ch) _ j _ _ ?_ ?_ x",
         "      refine stgPolyT_congr U hbij (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg τ) j)) _ j _ _ ?_ ?_ x")

# --- sshΦI, ssh_hDI (RunStgShieldInst.lean) ---
ph = between(isrc, "/-- **THE REAL `ΦI`**", "/-- **THE REAL `ΦO`**")
ph = rep(ph, "noncomputable def sshΦI ", "noncomputable def sshΦIC ")
ph = rep(ph, "  stgΦR U hbij P0 (fun v ch => (vdWin Vi (v.2.take n0)).bp (incCtx (vdWin Vi (v.2.take n0)).pub ch))\n",
         "  stgΦRC U hbij P0 (fun v ch => (vdWin Vi (v.2.take n0)).bp (incCtx (vdWin Vi (v.2.take n0)).pub ch))\n"
         "    (fun v k => StageV.incElog (vdWin Vi (v.2.take n0)).pub (vdWin Vi (v.2.take n0)).geo.bLogN k)\n")
ph = rep(ph, "/-- **THE REAL `ΦI`**", "/-- **THE REAL `ΦI`, REPAIRED** (finding L63-5, slot `k` at its own IO width)")
hd = between(isrc, "/-- **`hDI_stg` AT THE REAL `ΦI`**", "/-- **`hDO_stg` AT THE REAL `ΦO`**")
hd = rep(hd, "theorem ssh_hDI ", "theorem ssh_hDIC ")
hd = rep(hd, "(stgFstI U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO)",
         "(stgFstIC U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO)", 2)
hd = rep(hd, "    (htrue : StgTrueAt U key domain Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))\n"
             "      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))\n"
             "      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch))\n",
         "    (htrue : StgTrueAtC U key domain Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))\n"
         "      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))\n"
         "      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch))\n"
         "      (fun v k => StageV.incElog ((vdWin Vi) (v.2.take n0)).pub ((vdWin Vi) (v.2.take n0)).geo.bLogN k)\n")
hd = rep(hd, "(sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO)", "(sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO)")
hd = rep(hd, "  exact ssh_defAtV U hbij hU key domain P0 Pof m hdrLen _ stgHostIn _ _ _ (stgRv",
         "  exact ssh_defAtVC U hbij hU key domain P0 Pof m hdrLen _ stgHostIn _ _ _ _ (stgRv")
hd = rep(hd, "(hdrLen + (7 + m)) le_rfl (vwLoc_vdWin Vi n0 _)\n",
         "(hdrLen + (7 + m)) le_rfl (vwLoc_vdWin Vi n0 _) (fun _ _ _ _ => rfl)\n")

head = open(WT + "/results/zk60_lean_l63_20261116/l63_defc_head.lean.txt").read()
text = (head + sp + "end Def\n\nsection Zero\n\nvariable {K : Type} [Field K] [Algebra GF K] (U : K) "
        "(hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))\n\n" + zr + "end Zero\n\nsection Main\n\n"
        "variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))\n"
        "  {L : ℕ}\n\n" + dv + "end Main\n\nsection Phi\n\nvariable {K : Type} [Field K] [Algebra GF K] (U : K) "
        "(hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))\n  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)\n\n" + ph
        + "end Phi\n\nsection Run\n\nvariable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]\n"
        "variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)\n"
        "  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)\n"
        "  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))\n"
        "  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)\n"
        "  (tag : MTag) (h64 : 64 ≤ Lq)\n\n" + hd + "end Run\n\nend ZK60.ProtocolClassify\n")
dst = F + "RunStgShieldDefC.lean"
if len(sys.argv) > 2 and sys.argv[2] == "--check":
    ok = open(dst).read() == text
    print("identical" if ok else "DIFFERS")
    sys.exit(0 if ok else 1)
open(dst, "w").write(text)
print("wrote", dst)
