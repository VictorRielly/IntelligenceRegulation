/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 7: **`SC_SZC`'s named identity at R13** (lane L36's `FormAt` at host
`17`, hosting `SC_RS` at `ν₀·per_row` and `SC_SCORE` at `ν₁`), generic in the configuration: the R13 rung
(`cfgRungR13`, `ls = 2`) and every layer of the app's Shieldstral T128 R13 block (`cfgShieldR13 L`, `ls = 1`), with
the configuration facts `SzcCfg` proved at both (`BlockR13HostSzcCfg.lean`).

* `segFacts`: `SC_SZC`'s draw list at R13 (`τ`, `μ` of `13 + ls`, `ν`, no `ζ`);
* **`szcR_hostPhi`**: `SC_SZC`'s certified polynomial at its draws: `Z̃(τ) + ν₀·h̃₀(P₀) + ν₁·(h̃₁(P₁) − M̃₁(P₁))`;
* `algPt_scoreR`, **`algH0_mleR`**: the hosted `SC_RS` function at its claim point, `per_row·(Ã(p_ht) + λ·B̃(p_ht))`;
* **`formAt_szcR`**: lane L36's `FormAt` at host `17` for every algebra data whose `SC_SZC` tables are R13's relation
  tables of the extracted planes (`r13Cl 17` in the IR's batch order, `xcSzcR` past them, `r13Gh 17`, `r13Mm 17`,
  `SC_RS`'s `r13RsA` / `r13RsB`, the scale `per_row`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcCube
import ZK60Formal.BlockR13HostSzcCfg

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPhi_eq batched segAt mleAt_rowOnly mleAt_lin2 mleAt_castCube)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl formAt_two)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum segOff_le)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## `SC_SZC`'s certified polynomial at its draws -/

section Host

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)
  {L : ℕ} {c : W16Cfg} {ls : ℕ} (P : BlockParams) (hc : ShOkR c.sh P)

/-- `SC_SZC` draws no `ζ` at R13. -/
theorem seg17_zeta (hcfg : SzcCfg c ls) : segLn ((algShapeR c P hc).dl 17) .zeta = 0 := by
  show (if ZK60.Exec.Slot.W16R2.padOn c.sh 17 = true then 1 else 0) = 0
  rw [hcfg.pad]
  rfl

/-- `SC_SZC`'s `μ` has `13 + ls` entries at R13. -/
theorem seg17_mu (hcfg : SzcCfg c ls) : segLn ((algShapeR c P hc).dl 17) .mu = 13 + ls := by
  show 5 + c.sh.helpers .S + 1 + (if ZK60.Exec.Slot.W16R2.padOn c.sh 17 = true then 1 else 0) = 13 + ls
  rw [hcfg.pad, hcfg.help]
  simp only [Bool.false_eq_true, ↓reduceIte]
  omega

/-- `SC_SZC`'s `ν` starts at `lS + 13 + ls`. -/
theorem seg17_offNu (hcfg : SzcCfg c ls) :
    segOff ((algShapeR c P hc).dl 17) .nu = c.sh.logs .S + (13 + ls) := by
  show c.sh.logs .S + ((5 + c.sh.helpers .S + 1 + (if ZK60.Exec.Slot.W16R2.padOn c.sh 17 = true then 1 else 0)) + 0)
    = _
  rw [hcfg.pad, hcfg.help]
  simp only [Bool.false_eq_true, ↓reduceIte]
  omega

include hcard in
/-- **`SC_SZC`'s certified polynomial at its draws**: `Z̃(τ) + ν₀·h̃₀(P₀) + ν₁·(h̃₁(P₁) − M̃₁(P₁))` over the block's
tables (`hostPhi_eq`), the batch's weights read off the draws. -/
theorem szcR_hostPhi (hcfg : SzcCfg c ls) (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hist : Hist) (dr : List Fp2) :
    (hostSp U (algShapeR c P hc) dt hcard 17 W16.Szc.mem17 cu rt hist).Φ (fun i => (dr.getD i.val Fp2.zero).toK U)
      = mleAt (fun b => ∑ κ : Fin (segLn ((algShapeR c P hc).dl 17) .mu - segLn ((algShapeR c P hc).dl 17) .zeta),
            (dr.getD (c.sh.logs .S + (κ : ℕ)) Fp2.zero).toK U * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b)
          (fun t : Fin (c.sh.logs .S) => (dr.getD t Fp2.zero).toK U)
        + (dr.getD (c.sh.logs .S + (13 + ls)) Fp2.zero).toK U
          * mleAt (algH U (algShapeR c P hc) dt 17 cu rt hist 0) (algPt U (algShapeR c P hc) 17 hist 0)
        + (dr.getD (c.sh.logs .S + (13 + ls) + 1) Fp2.zero).toK U
          * (mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeR c P hc) 17 hist 1)
            - mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeR c P hc) 17 hist 1)) := by
  have hk : (17 : ℕ) ∈ algHosts := W16.Szc.mem17
  have hseg : ∀ (g : Seg) (i : ℕ), segOff ((algShapeR c P hc).dl 17) g + i < segSum ((algShapeR c P hc).dl 17) →
      segAt ((algShapeR c P hc).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
        (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) g i
        = (dr.getD (segOff ((algShapeR c P hc).dl 17) g + i) Fp2.zero).toK U := by
    intro g i hi
    unfold segAt
    rw [dite_eq_left hi]
    rfl
  have hbd : ∀ g, segOff ((algShapeR c P hc).dl 17) g + segLn ((algShapeR c P hc).dl 17) g
      ≤ segSum ((algShapeR c P hc).dl 17) := fun g => segOff_le _ g
  have hz := seg17_zeta P hc hcfg
  have hM0 : mleAt (algM (algShapeR c P hc) dt 17 cu rt 0) (algPt U (algShapeR c P hc) 17 hist 0) = 0 := by
    unfold algM mleAt
    simp
  rw [hostSp_Φ, hostPhi_eq, Fin.sum_univ_two, hM0, algH_gh U _ dt 17 cu rt hist 1 (by decide),
    algM_mm _ dt 17 cu rt 1 (by decide)]
  have hbat : batched (dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw 17 cu rt)
      ((if segLn ((algShapeR c P hc).dl 17) .zeta = 1 then segAt ((algShapeR c P hc).dl 17)
          (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
            (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .zeta 0 else 0,
        if segLn ((algShapeR c P hc).dl 17) .zeta = 1 then segAt ((algShapeR c P hc).dl 17)
          (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
            (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .mu
            (segLn ((algShapeR c P hc).dl 17) .mu - segLn ((algShapeR c P hc).dl 17) .zeta) else 0),
        fun κ => segAt ((algShapeR c P hc).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
          (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .mu κ)
      = fun b => ∑ κ : Fin (segLn ((algShapeR c P hc).dl 17) .mu - segLn ((algShapeR c P hc).dl 17) .zeta),
          (dr.getD (c.sh.logs .S + (κ : ℕ)) Fp2.zero).toK U * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b := by
    funext b
    unfold batched
    simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
    refine Finset.sum_congr rfl (fun κ _ => ?_)
    have hκ := κ.isLt
    rw [hseg .mu κ (by have := hbd .mu; omega)]
    rfl
  have htau : (fun t : Fin (segLn ((algShapeR c P hc).dl 17) .tau) => segAt ((algShapeR c P hc).dl 17)
      (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
        (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .tau t)
      = fun t : Fin (c.sh.logs .S) => (dr.getD t Fp2.zero).toK U := by
    funext t
    have ht := t.isLt
    rw [hseg .tau t (by have := hbd .tau; omega)]
    show (dr.getD (0 + (t : ℕ)) Fp2.zero).toK U = _
    rw [Nat.zero_add]
  have hnu0 : segAt ((algShapeR c P hc).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
      (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .nu ((0 : Fin 2) : ℕ)
      = (dr.getD (segOff ((algShapeR c P hc).dl 17) .nu + 0) Fp2.zero).toK U :=
    hseg .nu 0 (by have := hbd .nu; have h2 : segLn ((algShapeR c P hc).dl 17) .nu = 2 := rfl; omega)
  have hnu1 : segAt ((algShapeR c P hc).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
      (Fin.cast ((algShapeR c P hc).hsum 17 hk) j)) .nu ((1 : Fin 2) : ℕ)
      = (dr.getD (segOff ((algShapeR c P hc).dl 17) .nu + 1) Fp2.zero).toK U :=
    hseg .nu 1 (by have := hbd .nu; have h2 : segLn ((algShapeR c P hc).dl 17) .nu = 2 := rfl; omega)
  rw [seg17_offNu P hc hcfg, Nat.add_zero] at hnu0
  rw [seg17_offNu P hc hcfg] at hnu1
  rw [hbat, htau, hnu0, hnu1]
  simp only [one_mul, sub_zero]
  exact (add_assoc _ _ _).symm

omit [Fintype K] [DecidableEq K] in
/-- `SC_SCORE`'s claim point, read off the history. -/
theorem algPt_scoreR (hist : Hist) (t : Fin (segLn ((algShapeR c P hc).dl 17) .tau)) :
    algPt U (algShapeR c P hc) 17 hist 1 t = algDrawAt U hist 8 t := by
  unfold algPt
  rw [ite_eq_right (by decide), ite_eq_right (by decide)]
  rfl

omit [Fintype K] [DecidableEq K] in
/-- **`SC_SZC`'s hosted `SC_RS` function at its claim point**: `per_row·(Ã(p_ht) + λ·B̃(p_ht))`. -/
theorem algH0_mleR (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO) (hist : Hist)
    (A B : (Fin (c.sh.logs .Ht) → Bool) → K) (hA : ∀ b, dt.rsA cu rt b = A b) (hB : ∀ b, dt.rsB cu rt b = B b)
    (p : Fin (c.sh.logs .Ht) → K) (hp : ∀ t : Fin (c.sh.logs .Ht), algDrawAt U hist 4 t = p t) :
    mleAt (algH U (algShapeR c P hc) dt 17 cu rt hist 0) (algPt U (algShapeR c P hc) 17 hist 0)
      = dt.rsScale * (mleAt A p + algDrawAt U hist 4 (c.sh.logs .Ht) * mleAt B p) := by
  have hS17 : segLn ((algShapeR c P hc).dl 17) .tau = c.sh.logs .Ht + c.sh.lt := hc.hS17
  have e1 : algH U (algShapeR c P hc) dt 17 cu rt hist 0
      = fun z => (fun w : Fin (c.sh.logs .Ht + c.sh.lt) → Bool =>
          (fun r => dt.rsScale * (A r + algDrawAt U hist 4 (c.sh.logs .Ht) * B r)) (fun i => w (Fin.castAdd c.sh.lt i)))
        (fun t => z (Fin.cast hS17.symm t)) := by
    funext z
    unfold algH
    rw [dite_eq_left ⟨rfl, rfl⟩, hA, hB]
    rfl
  have e2 : (fun t : Fin (c.sh.logs .Ht + c.sh.lt) => algPt U (algShapeR c P hc) 17 hist 0 (Fin.cast hS17.symm t))
      = Fin.append p (fun _ : Fin c.sh.lt => (0 : K)) := by
    funext t
    unfold algPt
    rw [ite_eq_left ⟨rfl, rfl⟩]
    refine Fin.addCases (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left, ite_eq_left (by show (i : ℕ) < c.sh.logs .Ht; exact i.isLt)]
      exact hp i
    · rw [Fin.append_right, ite_eq_right (by show ¬ (c.sh.logs .Ht + (i : ℕ) < c.sh.logs .Ht); omega)]
  rw [e1]
  refine (mleAt_castCube hS17.symm (fun w : Fin (c.sh.logs .Ht + c.sh.lt) → Bool =>
      (fun r => dt.rsScale * (A r + algDrawAt U hist 4 (c.sh.logs .Ht) * B r)) (fun i => w (Fin.castAdd c.sh.lt i)))
    (algPt U (algShapeR c P hc) 17 hist 0)).trans ?_
  rw [e2]
  exact (mleAt_rowOnly _ p (fun _ : Fin c.sh.lt => 0)).trans (mleAt_lin2 A B _ _ p)

end Host

/-! ## `SC_SZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_SZC`'s named identity at R13** (lane L36's `FormAt` at host `17`), generic in the configuration: for every
algebra data whose `SC_SZC` tables are R13's relation tables of the extracted planes (`r13Cl 17` in the IR's batch
order, `xcSzcR` past the five named clauses, `r13Gh 17`, `r13Mm 17`, `SC_RS`'s row differences `r13RsA`, `r13RsB`,
the scale `per_row`), on every outcome whose verified slots are hosts exactly when their definitions host slots,
`SC_SZC`'s certified polynomial at the drawn challenges is its unmasked residual
`Σ Poly₁₇ − (per_row·ν₀·Σ Poly₄ + ν₁·Σ Poly₈)`. The configuration facts `hcfg` hold at the R13 rung (`szcCfg_rung`)
and at every Shieldstral layer (`szcCfg_shield`). -/
theorem formAt_szcR (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : SzcCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR c S) (hW : ZK60.Layout.R13.R13Windows S ls) (hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 17 cu rt bga κ b = if (κ : ℕ) < r13Count 17
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 (clIx 17 κ) (encR G 17 b))
        else xcSzcR U G P D B bga κ b)
    (hgh : ∀ i b, dt.gh 17 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 i (encR G 17 b)))
    (hmm : ∀ i b, dt.mm 17 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 17 i (encR G 17 b)))
    (hrsA : ∀ b, dt.rsA cu rt b = algebraMap GF K (r13RsA Pb Lay B (xtR U c P D ls) (encHtR G b)))
    (hrsB : ∀ b, dt.rsB cu rt b = algebraMap GF K (r13RsB Pb Lay B (xtR U c P D ls) (encHtR G b)))
    (hsc : dt.rsScale = (c.sh.perRow : K))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 17 := by
  have hk : (17 : ℕ) ∈ algHosts := W16.Szc.mem17
  have hls : ls ≤ 2 := by have := hW.wrho; have := hW.wrho24; omega
  have hfp : c.p.fp ≤ 15 := by have := hW.fp; rw [hS.fp] at this; omega
  have hsc' : c.p.score ≤ 24 := by have := hW.ss; rw [hS.ss] at this; omega
  have hlQ : 0 < c.sh.logs .Q := by
    have := G.lt_pos
    rw [G.logQ]
    show 0 < c.sh.lt + (nH c + c.sh.ldh)
    omega
  have hlK : 0 < c.sh.logs .Kv := by
    have := G.lt_pos
    rw [G.logK]
    show 0 < c.sh.lt + (c.sh.lkv + c.sh.ldh)
    omega
  have hkv := G.lkv_le
  have hpr2 : (c.sh.perRow : K) = 2 ^ c.sh.lt := by
    rw [hcfg.perRow]
    push_cast
    rfl
  -- the slot programs
  obtain ⟨ak17, hk17, hslot17⟩ := progR13_slot c ioIn ioOut 17 (by norm_num)
  obtain ⟨ak4, hk4, hslot4⟩ := progR13_slot c ioIn ioOut 4 (by norm_num)
  obtain ⟨ak8, hk8, hslot8⟩ := progR13_slot c ioIn ioOut 8 (by norm_num)
  rw [hcfg.raw17] at hslot17
  rw [hcfg.raw4] at hslot4
  rw [hcfg.raw8] at hslot8
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D _ dt cu rt bga rs 17 hk 4 8
    (.mul (.dr 17 (c.sh.logs .S + (13 + ls))) (.base c.sh.perRow)) (.dr 17 (c.sh.logs .S + (13 + ls) + 1))
    (by rw [hslot17]; rfl) (by rw [hslot4]; rfl) (by rw [hslot8]; rfl) (by norm_num) (by norm_num) hslots
    (fun r hr => ?_)
  have hlen : 17 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r4, hr4⟩ : ∃ r4, rs[4]? = some r4 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r8, hr8⟩ : ∃ r8, rs[8]? = some r8 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hs17 : (slotShape P 17).1 = c.sh.logs .S := by rw [hpf.slots 17 (by norm_num)]; rfl
  have hs4 : (slotShape P 4).1 = c.sh.logs .S := by rw [hpf.slots 4 (by norm_num)]; rfl
  have hs8 : (slotShape P 8).1 = c.sh.lkv + c.sh.ldh := by rw [hpf.slots 8 (by norm_num)]; rfl
  -- the three slots' sums
  have hsp17 := szcR_cube U G P D hX hrl Pb B hLay hS hls hfp hsc' hcfg.lk (DefR13.aDataRows c) (DefR13.hDataRows c)
    ioIn ioOut ak17 hk17 (slotShape P 17).1 (slotShape P 17).2.1 hs17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17))
    r.draws (pubs 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) r.draws) (hpub.szcMask _ _)
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 17 (seenOf bga rs 17))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 17 r hr x, hslot17]; rfl)
  have hsp4 := rs_cubeR U c P D hrl (lS_pos G) (hS_split G) (DefR13.aDataRows c) (DefR13.hDataRows c)
    ioIn ioOut ak4 hk4 (slotShape P 4).1 (slotShape P 4).2.1 hs4 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws
    (pubs 4 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws) (fun b => algebraMap GF K (B.mask (xS G b)))
    (fun b => by rw [← msbIndex_castB G.logS b]; exact hpub.rsMask _ _ _)
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 4 (seenOf bga rs 4))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 4 r4 hr4 x, hslot4]; rfl)
  have hsp8 := score_cubeR U c P D hrl G.logQ hlQ G.logK hlK (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak8
    hk8 (slotShape P 8).1 (slotShape P 8).2.1 hs8 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws
    (pubs 8 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws)
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 8 (seenOf bga rs 8))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 8 r8 hr8 x, hslot8]; rfl)
  beta_reduce at hsp4
  rw [szcR_hostPhi U hcard P hc hcfg dt cu rt _ r.draws]
  unfold spSum
  rw [hsp17, hsp4, hsp8]
  -- the batch
  have hmuz : segLn ((algShapeR c P hc).dl 17) .mu - segLn ((algShapeR c P hc).dl 17) .zeta = 13 + ls := by
    rw [seg17_mu P hc hcfg, seg17_zeta P hc hcfg, Nat.sub_zero]
  have eZ : mleAt (fun b => ∑ κ : Fin (segLn ((algShapeR c P hc).dl 17) .mu
          - segLn ((algShapeR c P hc).dl 17) .zeta), (r.draws.getD (c.sh.logs .S + (κ : ℕ)) Fp2.zero).toK U
        * dt.cl 17 cu rt ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta,
          (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b)
        (fun t : Fin (c.sh.logs .S) => (r.draws.getD t Fp2.zero).toK U)
      = mleAt (fun b : Fin (c.sh.logs .S) → Bool => ∑ κ ∈ Finset.range (13 + ls),
          (((drsR 17 (c.sh.logs .S) (13 + ls)).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map
            (Fp2.toK U)).getD κ 0
          * (if κ < 5 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 κ (.s (xS G b)))
            else xcSzcR U G P D B ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta,
              (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b))
        (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 17 0 (c.sh.logs .S)) := by
    rw [W16.Szc.ptv_own]
    congr 1
    · funext b
      simp only [hcl]
      rw [Fin.sum_univ_eq_sum_range (fun κ => (r.draws.getD (c.sh.logs .S + κ) Fp2.zero).toK U
        * (if κ < r13Count 17 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 (clIx 17 κ) (encR G 17 b))
          else xcSzcR U G P D B ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta,
            (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b)),
        hmuz]
      refine Finset.sum_congr rfl (fun κ hκ => ?_)
      rw [Finset.mem_range] at hκ
      rw [drsRK_getD U _ 17 _ (13 + ls) κ hκ, W16.Szc.ev_own]
      rfl
    · funext t
      rw [Nat.zero_add]
  -- `SC_RS`'s hosted function
  have eH0 : mleAt (algH U (algShapeR c P hc) dt 17 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      (algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      = 2 ^ c.sh.lt * ((mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r)
            (fun i => (r4.draws.getD i Fp2.zero).toK U)
          - mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => ∑ j : Fin c.sh.lt → Bool,
              algebraMap GF K (B.mask (xS G (castB (hS_split G).symm (Fin.append r j))))
                * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))
        + (r4.draws.getD (c.sh.logs .Ht) Fp2.zero).toK U
          * (1 - mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => ∑ j : Fin c.sh.lt → Bool,
              aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))) := by
    rw [algH0_mleR U P hc dt cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17))
      (fun r : Fin (c.sh.logs .Ht) → Bool => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r - ∑ j : Fin c.sh.lt → Bool,
        algebraMap GF K (B.mask (xS G (castB (hS_split G).symm (Fin.append r j))))
          * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)))
      (fun r : Fin (c.sh.logs .Ht) → Bool => 1 - ∑ j : Fin c.sh.lt → Bool,
        aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) (castB (hS_split G).symm (Fin.append r j)))
      (fun b => (hrsA b).trans (rsA_algR U G P D hX Pb B hLay b))
      (fun b => (hrsB b).trans (rsB_algR U G P D hX Pb B hLay b))
      (fun i => (r4.draws.getD i Fp2.zero).toK U)
      (fun t => algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 t r4 (by decide) hr4),
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 (c.sh.logs .Ht) r4 (by decide) hr4,
      W16.Szc.mleAt_sub' (fun r : Fin (c.sh.logs .Ht) → Bool => aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) r),
      W16.Szc.mleAt_c_sub, hsc, hpr2]
  -- `SC_SCORE`'s claim point and the hosted terms
  have hP8 : algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1
      = fun t : Fin (c.sh.logs .S) => (r8.draws.getD t Fp2.zero).toK U := by
    funext t
    rw [algPt_scoreR U P hc, algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 t r8 (by decide) hr8]
  have eH1 : mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = mleAt (fun b : Fin (c.sh.logs .S) → Bool => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))))
        (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 8 0 (c.sh.logs .S)) := by
    rw [hP8, W16.Szc.ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 r8 (by decide) hr8]
    exact congrArg₂ mleAt (funext fun b => hgh 1 b) (funext fun t => by rw [Nat.zero_add])
  have hpt8 : (fun t : Fin (nS c) => (r8.draws.getD (Fin.cast G.logS.symm t : Fin (c.sh.logs .S)) Fp2.zero).toK U)
      = (Fin.append (Fin.append (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 c.sh.lkv)
          (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 c.sh.lkv (c.sh.lh - c.sh.lkv)))
        (Fin.append (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 c.sh.lh c.sh.lt)
          (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 (c.sh.lh + c.sh.lt) c.sh.lt))
        : Fin (nS c) → K) := by
    rw [W16.Szc.ptv_own, W16.Szc.ptv_own, W16.Szc.ptv_own, W16.Szc.ptv_own]
    funext t
    refine Fin.addCases (m := nH c) (n := c.sh.lt + c.sh.lt) (fun t4 => ?_) (fun t10 => ?_) t
    · rw [Fin.append_left]
      refine Fin.addCases (m := c.sh.lkv) (n := c.sh.lh - c.sh.lkv) (fun t3 => ?_) (fun t1 => ?_) t4
      · rw [Fin.append_left]
        show (r8.draws.getD (t3 : ℕ) Fp2.zero).toK U = (r8.draws.getD (0 + (t3 : ℕ)) Fp2.zero).toK U
        rw [Nat.zero_add]
      · rw [Fin.append_right]
        show (r8.draws.getD (c.sh.lkv + (t1 : ℕ)) Fp2.zero).toK U = _
        rfl
    · rw [Fin.append_right]
      refine Fin.addCases (m := c.sh.lt) (n := c.sh.lt) (fun t5 => ?_) (fun t5' => ?_) t10
      · rw [Fin.append_left]
        show (r8.draws.getD (nH c + (t5 : ℕ)) Fp2.zero).toK U = (r8.draws.getD (c.sh.lh + (t5 : ℕ)) Fp2.zero).toK U
        rw [show nH c + (t5 : ℕ) = c.sh.lh + t5 by show c.sh.lkv + (c.sh.lh - c.sh.lkv) + (t5 : ℕ) = _; omega]
      · rw [Fin.append_right]
        show (r8.draws.getD (nH c + (c.sh.lt + (t5' : ℕ))) Fp2.zero).toK U
          = (r8.draws.getD (c.sh.lh + c.sh.lt + (t5' : ℕ)) Fp2.zero).toK U
        rw [show nH c + (c.sh.lt + (t5' : ℕ)) = c.sh.lh + c.sh.lt + t5' by
          show c.sh.lkv + (c.sh.lh - c.sh.lkv) + (c.sh.lt + (t5' : ℕ)) = _; omega]
  have eM1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = ∑ g : Fin c.sh.lkv → Bool, ∑ d : Fin c.sh.ldh → Bool,
        eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 c.sh.lkv)
          (fun i => bit (g i))
        * ((∑ t : Fin c.sh.lt → Bool, ∑ jj : Fin (c.sh.lh - c.sh.lkv) → Bool,
            eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 c.sh.lh c.sh.lt)
              (fun i => bit (t i))
            * eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 c.sh.lkv
                (c.sh.lh - c.sh.lkv)) (fun i => bit (jj i))
            * aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) (castB G.logQ.symm (Fin.append t (Fin.append (Fin.append g jj) d))))
          * (∑ t' : Fin c.sh.lt → Bool,
            eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 (c.sh.lh + c.sh.lt)
              c.sh.lt) (fun i => bit (t' i))
            * aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) (castB G.logK.symm (Fin.append t' (Fin.append g d))))) := by
    refine Eq.trans ?_ (W16.Szc.score_gen
      (fun g : Fin c.sh.lkv → Bool => eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8
        r8.draws) 8 0 c.sh.lkv) (fun i => bit (g i)))
      (fun jj : Fin (c.sh.lh - c.sh.lkv) → Bool => eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
        (rs.take 8)) 8 r8.draws) 8 c.sh.lkv (c.sh.lh - c.sh.lkv)) (fun i => bit (jj i)))
      (fun t : Fin c.sh.lt → Bool => eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8
        r8.draws) 8 c.sh.lh c.sh.lt) (fun i => bit (t i)))
      (fun t : Fin c.sh.lt → Bool => eqPoly (W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8
        r8.draws) 8 (c.sh.lh + c.sh.lt) c.sh.lt) (fun i => bit (t i)))
      (fun g jj t (d : Fin c.sh.ldh → Bool) => aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q)
        (castB G.logQ.symm (Fin.append t (Fin.append (Fin.append g jj) d))))
      (fun g t (d : Fin c.sh.ldh → Bool) => aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv)
        (castB G.logK.symm (Fin.append t (Fin.append g d))))).symm
    have e1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
        = mleAt (fun w : Fin (nS c) → Bool => dt.mm 17 cu rt 1 (castB G.logS.symm w))
          (fun t => algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1
            (Fin.cast G.logS.symm t)) :=
      mleAt_castCube G.logS.symm (fun w : Fin (nS c) → Bool => dt.mm 17 cu rt 1 (castB G.logS.symm w))
        (algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
    have e2 : (fun t : Fin (nS c) => algPt U (algShapeR c P hc) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1
        (Fin.cast G.logS.symm t))
        = fun t : Fin (nS c) => (r8.draws.getD (Fin.cast G.logS.symm t : Fin (c.sh.logs .S)) Fp2.zero).toK U := by
      funext t
      rw [algPt_scoreR U P hc, algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 _ r8 (by decide) hr8]
      rfl
    rw [e1, e2, hpt8, W16.Szc.mleAt_eq4]
    refine Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun jj _ => Finset.sum_congr rfl
      (fun t _ => Finset.sum_congr rfl (fun t' _ => ?_))))
    simp only [hmm 1]
    congr 1
    exact mm171_algR U G P D hX Pb B g jj t t'
  -- the weights and `λ`
  have hpr64 : (c.sh.perRow : ℤ) < 2 ^ 64 := by
    have h3 : (c.sh.perRow : ℤ) < 2 ^ 63 := by exact_mod_cast hcfg.perRowLt
    linarith [show (2 : ℤ) ^ 63 < 2 ^ 64 by norm_num]
  have es0 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws
      (.mul (.dr 17 (c.sh.logs .S + (13 + ls))) (.base c.sh.perRow))).toK U
      = (r.draws.getD (c.sh.logs .S + (13 + ls)) Fp2.zero).toK U * 2 ^ c.sh.lt := by
    rw [W16.Szc.ev_mul, Fp2.toK_mul U hU, W16.Szc.ev_own, W16.Szc.ev_base, Fp2.toK_fromBase,
      Fp.toGF_fromI64 _ (by have : (0 : ℤ) ≤ c.sh.perRow := by positivity
                            linarith) hpr64, map_intCast, Int.cast_natCast, hpr2]
  have es1 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 (c.sh.logs .S + (13 + ls) + 1))).toK U
      = (r.draws.getD (c.sh.logs .S + (13 + ls) + 1) Fp2.zero).toK U := by rw [W16.Szc.ev_own]
  have enu0 : (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17
      r.draws)).map (Fp2.toK U)).getD 0 0 = (r.draws.getD (c.sh.logs .S + (13 + ls)) Fp2.zero).toK U := by
    rw [drsRK_getD U _ 17 _ 2 0 (by norm_num), W16.Szc.ev_own, Nat.add_zero]
  have enu1 : (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17
      r.draws)).map (Fp2.toK U)).getD 1 0 = (r.draws.getD (c.sh.logs .S + (13 + ls) + 1) Fp2.zero).toK U := by
    rw [drsRK_getD U _ 17 _ 2 1 (by norm_num), W16.Szc.ev_own]
  have el17 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 4 (c.sh.logs .Ht))).toK U
      = (r4.draws.getD (c.sh.logs .Ht) Fp2.zero).toK U :=
    W16.Szc.ev_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 (c.sh.logs .Ht) r4 (by decide) hr4 r.draws
  have el4 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws (.dr 4 (c.sh.logs .Ht))).toK U
      = (r4.draws.getD (c.sh.logs .Ht) Fp2.zero).toK U := by rw [W16.Szc.ev_own]
  have ep4 : W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 4 0 (c.sh.logs .Ht)
      = fun i : Fin (c.sh.logs .Ht) => (r4.draws.getD i Fp2.zero).toK U := by
    rw [W16.Szc.ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 r4 (by decide) hr4]
    funext i
    rw [Nat.zero_add]
  have ep4' : W16.Szc.ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws) 4 0 (c.sh.logs .Ht)
      = fun i : Fin (c.sh.logs .Ht) => (r4.draws.getD i Fp2.zero).toK U := by
    rw [W16.Szc.ptv_own]
    funext i
    rw [Nat.zero_add]
  rw [eZ, eH0, eH1, eM1, es0, es1, enu0, enu1, el17, el4, ep4, ep4']
  ring

end Form

end ZK60.Exec.Block.Join.R13H.Szc
