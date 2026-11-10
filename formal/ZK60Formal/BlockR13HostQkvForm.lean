/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 8: **lane L36's `FormAt` at hosts `15` (`SC_QZC`) and `16`
(`SC_KVZC`) at R13**, generic in the configuration (the R13 rung and every Shieldstral layer, through `QkvCfg`).

* `segFacts`, `getD_toK`, `getD_app2`: the hosts' draw lists' offsets, reading a list in the field;
* **`formAt_qzcR`**: for every algebra data `dt` whose host-15 tables are R13's named relations (`r13Cl 15` in the IR's
  batch order, `xcQzcR` past them, `r13Gh 15`, `r13Mm 15`), on every outcome whose verified slots passed their checks,
  `FormAt` holds at `15`;
* **`formAt_kvzcR`**: the same at `16` (`r13Cl 16`, `xcKvzcR`, `r13Gh 16`, `r13Mm 16`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvCube
import ZK60Formal.BlockR13HostQkvMm

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (formAt_two)
open ZK60.Exec.Block.Join.W16.Qkv (drs drs_getD eval_self eval_hist drs_map_hist)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## Tools -/

/-- **The two hosts' draw lists**: `μ` at `0` (`11`), `ν` at `11`, no `ζ`, `τ` at `13`. -/
theorem segFacts {l : List (Seg × ℕ)} {m : ℕ} (hl : l = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, m)]) :
    segOff l .mu = 0 ∧ segOff l .nu = 11 ∧ segOff l .tau = 13 ∧ segLn l .zeta = 0 ∧ segLn l .mu = 11
      ∧ segSum l = 13 + m := by
  subst hl
  refine ⟨rfl, rfl, rfl, rfl, rfl, ?_⟩
  simp only [segSum, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
  omega

theorem getD_toK {K : Type} [Field K] [Algebra GF K] (U : K) (l : List Fp2) (i : ℕ) :
    (l.map (Fp2.toK U)).getD i 0 = (l.getD i Fp2.zero).toK U := by
  rw [← Fp2.toK_zero U, ZK60.Exec.Slot.Compose.getD_map_f]

theorem getD_app2 {α : Type} (l1 l2 : List α) (n1 : ℕ) (h1 : l1.length = n1) (j : ℕ) (d : α) :
    (l1 ++ l2).getD j d = if j < n1 then l1.getD j d else l2.getD (j - n1) d := by
  subst h1
  rw [List.getD_eq_getElem?_getD]
  by_cases hj : j < l1.length
  · rw [ite_eq_left hj, List.getElem?_append_left hj, List.getD_eq_getElem?_getD]
  · rw [ite_eq_right hj, List.getElem?_append_right (by omega), List.getD_eq_getElem?_getD]

/-! ## `SC_QZC` -/

/-- **L36's `FormAt` at host `15` (`SC_QZC`) at R13**, generic in the configuration: for every algebra data `dt` whose
host-15 tables are R13's named relations (the RoPE clause and the three word decompositions in the IR's batch order,
LogUp's helper relations `xcQzcR` past them, the requantizations `r13Gh 15`, the contractions `r13Mm 15`), on every
outcome whose verified slots passed their checks. -/
theorem formAt_qzcR {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : QkvCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hS : PrecR c S) (_hW : ZK60.Layout.R13.R13Windows S ls) (hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 15 cu rt bga κ b = if (κ : ℕ) < r13Count 15
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 (clIx 15 κ) (encR G 15 b))
        else xcQzcR U c P D bga κ b)
    (hgh : ∀ i b, dt.gh 15 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 15 i (encR G 15 b)))
    (hmm : ∀ i b, dt.mm 15 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 i (encR G 15 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 15 := by
  obtain ⟨hoMu, hoNu, hoTau, hzeta, hlnMu, hsum⟩ := segFacts (l := (algShapeR c P hc).dl 15) hcfg.dQ
  have hQ : c.sh.logs .Q = c.sh.lt + (c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh) := G.logQ
  have hlq : c.sh.lq = c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh := G.lq
  have hle := G.lkv_le
  have hs15 : (slotShape P 15).1 = c.sh.logs .Q := by
    rw [hpf.slots 15 (by norm_num)]
    rfl
  obtain ⟨ak, hk', hslot⟩ := progR13_slot c ioIn ioOut 15 (by norm_num)
  have hprog15 : (DefR13.progR13 c ioIn ioOut).getD 15 SlotS.empty
      = DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk' (rawQ c) := by
    rw [hslot, hcfg.raw15]
  have hp5 : ((DefR13.progR13 c ioIn ioOut).getD 5 SlotS.empty).hosted = [] := by
    obtain ⟨m, h⟩ := prog_mm hcfg ioIn ioOut 5 (Or.inl rfl)
    exact (congrArg SlotS.hosted h).trans rfl
  have hp9 : ((DefR13.progR13 c ioIn ioOut).getD 9 SlotS.empty).hosted = [] := by
    obtain ⟨m1, m2, h⟩ := prog_pv hcfg ioIn ioOut
    exact (congrArg SlotS.hosted h).trans rfl
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D _ dt cu rt bga rs 15 (by decide) 5 9
    (.dr 15 11) (.dr 15 12) ((congrArg SlotS.hosted hprog15).trans rfl) hp5 hp9 (by norm_num) (by norm_num) hslots
    (fun r hr => ?_)
  have hlen : 15 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r5, hr5⟩ : ∃ r5, rs[5]? = some r5 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r9, hr9⟩ : ∃ r9, rs[9]? = some r9 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    rw [hdef] at hdf
    exact (defineS_ok hdf).1.2.2.2
  -- the three slots' sums
  have hsp15 := qzc_cubeR U G P D hX hrl hrlH Pb Lay B hLay hS hcfg pubs hpub (DefR13.aDataRows c)
    (DefR13.hDataRows c) ioIn ioOut ak hk' ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).beta,
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws rfl rfl (slotShape P 15).1 (slotShape P 15).2.1 hs15
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 15 (seenOf bga rs 15))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 15 r hr x, hprog15])
  have hsp5 := qmm_spSumR U G P D hX hrl Pb Lay B hcfg hpf pubs hpub ioIn ioOut bga rs r5 hr5 (hcan 5 r5 hr5)
  have hsp9 := pv_spSumR U G P D hrl hX Pb Lay B hcfg hpf pubs ioIn ioOut bga rs r9 hr9
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 15) with hhist
  rw [hostSp_Φ]
  unfold hostPhi
  rw [hsp5, hsp9]
  unfold spSum
  rw [hsp15]
  refine congrArg₂ (· - ·) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · have ha : (a : ℕ) < c.sh.logs .Q := a.isLt
      unfold segAt
      rw [dite_eq_left (by rw [hoTau, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .tau + a) Fp2.zero).toK U = _
      rw [hoTau, drs_getD _ 15 13 _ a ha, eval_self]
    · unfold batched
      have hz1 : ¬ (segLn ((algShapeR c P hc).dl 15) .zeta = 1) := by omega
      rw [ite_eq_right hz1, ite_eq_right hz1]
      simp only [zero_mul, add_zero]
      have hN : segLn ((algShapeR c P hc).dl 15) .mu - segLn ((algShapeR c P hc).dl 15) .zeta = 11 := by omega
      refine Fintype.sum_equiv (finCongr hN) _ _ (fun κ => ?_)
      have hv : ((finCongr hN κ : Fin 11) : ℕ) = κ := rfl
      have hκ : (κ : ℕ) < 11 := by
        have := κ.isLt
        omega
      rw [hv, hcl, show r13Count 15 = 4 from rfl, show clIx 15 κ = κ from rfl]
      congr 1
      unfold segAt
      rw [dite_eq_left (by rw [hoMu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .mu + κ) Fp2.zero).toK U = _
      rw [hoMu, getD_toK, drs_getD _ 15 0 11 κ hκ, eval_self]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
        show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .nu + 0) Fp2.zero).toK U = _
        rw [hoNu]
        rfl
      · unfold segAt
        rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
        show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .nu + 1) Fp2.zero).toK U = _
        rw [hoNu]
        rfl
    · have hj : (j : ℕ) < c.sh.logs .Q := j.isLt
      fin_cases i
      · show algDrawAt U hist 5 (ipStd c.sh.lt c.sh.lh 15 0 j)
          = (((drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq).map (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        have e := drs_append 5 0 c.sh.lt c.sh.lq
        rw [Nat.zero_add] at e
        rw [show ipStd c.sh.lt c.sh.lh 15 0 j = j from rfl,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5, e,
          drs_map_hist bga rs 15 5 r.draws r5 (by decide) hr5 0 _ hist, drs_getD _ 5 0 _ j (by omega), eval_self,
          Nat.zero_add]
      · show algDrawAt U hist 9 (ipStd c.sh.lt c.sh.lh 15 1 j)
          = (((drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh).map
            (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9, List.map_append, List.map_append,
          getD_app3 _ _ _ c.sh.lt c.sh.lh (by simp [drs_len]) (by simp [drs_len])]
        unfold ipStd
        rw [ite_eq_left (⟨rfl, rfl⟩ : 15 = 15 ∧ (1 : Fin 2) = 1)]
        by_cases h1 : (j : ℕ) < c.sh.lt
        · rw [ite_eq_left h1, ite_eq_left h1, drs_getD _ 9 _ _ _ h1,
            eval_hist bga rs 15 9 _ r.draws r9 (by decide) hr9]
        · rw [ite_eq_right h1, ite_eq_right h1]
          by_cases h2 : (j : ℕ) < c.sh.lt + c.sh.lh
          · rw [ite_eq_left h2, ite_eq_left h2, drs_getD _ 9 _ _ _ (by omega),
              eval_hist bga rs 15 9 _ r.draws r9 (by decide) hr9, Nat.zero_add]
          · rw [ite_eq_right h2, ite_eq_right h2, drs_getD _ 9 _ _ _ (by omega),
              eval_hist bga rs 15 9 _ r.draws r9 (by decide) hr9]
            exact congrArg (fun k => (r9.draws.getD k Fp2.zero).toK U) (by omega)
    · rw [algH_gh U _ dt 15 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeR c P hc) dt 15 cu rt i
        = fun b => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 i (encR G 15 b)) := fun i => by
      rw [algM_mm _ dt 15 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeR c P hc) 15 hist 0
        = fun t : Fin (segLn ((algShapeR c P hc).dl 15) .tau) => (r5.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 5 (ipStd c.sh.lt c.sh.lh 15 0 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5
    have hp1 : algPt U (algShapeR c P hc) 15 hist 1
        = fun t : Fin (segLn ((algShapeR c P hc).dl 15) .tau) =>
          (r9.draws.getD (ipStd c.sh.lt c.sh.lh 15 1 t) Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 9 (ipStd c.sh.lt c.sh.lh 15 1 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .nu + 0) Fp2.zero).toK U = _
      rw [hoNu]
      rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 15) .nu + 1) Fp2.zero).toK U = _
      rw [hoNu]
      rfl

/-! ## `SC_KVZC` -/

/-- **L36's `FormAt` at host `16` (`SC_KVZC`) at R13**, generic in the configuration: for every algebra data `dt` whose
host-16 tables are R13's named relations (`r13Cl 16` in the IR's batch order, `xcKvzcR` past them, `r13Gh 16`,
`r13Mm 16`), on every outcome whose verified slots passed their checks. -/
theorem formAt_kvzcR {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : QkvCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hS : PrecR c S) (_hW : ZK60.Layout.R13.R13Windows S ls) (hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 16 cu rt bga κ b = if (κ : ℕ) < r13Count 16
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 (clIx 16 κ) (encR G 16 b))
        else xcKvzcR U c P D bga κ b)
    (hgh : ∀ i b, dt.gh 16 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 16 i (encR G 16 b)))
    (hmm : ∀ i b, dt.mm 16 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 16 i (encR G 16 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 16 := by
  obtain ⟨hoMu, hoNu, hoTau, hzeta, hlnMu, hsum⟩ := segFacts (l := (algShapeR c P hc).dl 16) hcfg.dK
  have hK : c.sh.logs .Kv = c.sh.lt + (c.sh.lkv + c.sh.ldh) := G.logK
  have hkw : c.sh.lkvw = c.sh.lkv + c.sh.ldh := G.lkvw
  have hs16 : (slotShape P 16).1 = c.sh.logs .Kv := by
    rw [hpf.slots 16 (by norm_num)]
    rfl
  obtain ⟨ak, hk', hslot⟩ := progR13_slot c ioIn ioOut 16 (by norm_num)
  have hprog16 : (DefR13.progR13 c ioIn ioOut).getD 16 SlotS.empty
      = DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk' (rawKv c) := by
    rw [hslot, hcfg.raw16]
  have hp6 : ((DefR13.progR13 c ioIn ioOut).getD 6 SlotS.empty).hosted = [] := by
    obtain ⟨m, h⟩ := prog_mm hcfg ioIn ioOut 6 (Or.inr (Or.inl rfl))
    exact (congrArg SlotS.hosted h).trans rfl
  have hp7 : ((DefR13.progR13 c ioIn ioOut).getD 7 SlotS.empty).hosted = [] := by
    obtain ⟨m, h⟩ := prog_mm hcfg ioIn ioOut 7 (Or.inr (Or.inr rfl))
    exact (congrArg SlotS.hosted h).trans rfl
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D _ dt cu rt bga rs 16 (by decide) 6 7
    (.dr 16 11) (.dr 16 12) ((congrArg SlotS.hosted hprog16).trans rfl) hp6 hp7 (by norm_num) (by norm_num) hslots
    (fun r hr => ?_)
  have hlen : 16 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r5, hr5⟩ : ∃ r5, rs[5]? = some r5 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r6, hr6⟩ : ∃ r6, rs[6]? = some r6 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r7, hr7⟩ : ∃ r7, rs[7]? = some r7 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    rw [hdef] at hdf
    exact (defineS_ok hdf).1.2.2.2
  have hsp16 := kvzc_cubeR U G P D hX hrl hrlH Pb Lay B hLay hS hcfg pubs hpub (DefR13.aDataRows c)
    (DefR13.hDataRows c) ioIn ioOut ak hk' ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).beta,
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws rfl rfl (slotShape P 16).1 (slotShape P 16).2.1 hs16
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 16 (seenOf bga rs 16))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 16 r hr x, hprog16])
  have hsp6 := kvmm_spSumR U G P D hX hrl Pb Lay B hcfg hpf pubs ioIn ioOut 6 (Or.inl rfl) 0 bga rs r5 r6 hr5 hr6
    (fun cc => hpub.wk _ _ (hcan 6 r6 hr6) cc)
  have hsp7 := kvmm_spSumR U G P D hX hrl Pb Lay B hcfg hpf pubs ioIn ioOut 7 (Or.inr rfl) 1 bga rs r5 r7 hr5 hr7
    (fun cc => hpub.wv _ _ (hcan 7 r7 hr7) cc)
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 16) with hhist
  rw [hostSp_Φ]
  unfold hostPhi
  rw [hsp6, hsp7]
  unfold spSum
  rw [hsp16]
  refine congrArg₂ (· - ·) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · have ha : (a : ℕ) < c.sh.logs .Kv := a.isLt
      unfold segAt
      rw [dite_eq_left (by rw [hoTau, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .tau + a) Fp2.zero).toK U = _
      rw [hoTau, drs_getD _ 16 13 _ a ha, eval_self]
    · unfold batched
      have hz1 : ¬ (segLn ((algShapeR c P hc).dl 16) .zeta = 1) := by omega
      rw [ite_eq_right hz1, ite_eq_right hz1]
      simp only [zero_mul, add_zero]
      have hN : segLn ((algShapeR c P hc).dl 16) .mu - segLn ((algShapeR c P hc).dl 16) .zeta = 11 := by omega
      refine Fintype.sum_equiv (finCongr hN) _ _ (fun κ => ?_)
      have hv : ((finCongr hN κ : Fin 11) : ℕ) = κ := rfl
      have hκ : (κ : ℕ) < 11 := by
        have := κ.isLt
        omega
      rw [hv, hcl, show r13Count 16 = 4 from rfl, show clIx 16 κ = κ from rfl]
      congr 1
      unfold segAt
      rw [dite_eq_left (by rw [hoMu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .mu + κ) Fp2.zero).toK U = _
      rw [hoMu, getD_toK, drs_getD _ 16 0 11 κ hκ, eval_self]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
        show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .nu + 0) Fp2.zero).toK U = _
        rw [hoNu]
        rfl
      · unfold segAt
        rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
        show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .nu + 1) Fp2.zero).toK U = _
        rw [hoNu]
        rfl
    · have hj : (j : ℕ) < c.sh.logs .Kv := j.isLt
      fin_cases i
      · show (if (j : ℕ) < c.sh.lt then algDrawAt U hist 5 j else algDrawAt U hist 6 ((j : ℕ) - c.sh.lt))
          = (((drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6, List.map_append,
          getD_app2 _ _ c.sh.lt (by simp [drs_len])]
        by_cases h1 : (j : ℕ) < c.sh.lt
        · rw [ite_eq_left h1, ite_eq_left h1, drs_getD _ 5 _ _ _ h1,
            eval_hist bga rs 16 5 _ r.draws r5 (by decide) hr5, Nat.zero_add]
        · rw [ite_eq_right h1, ite_eq_right h1, drs_getD _ 6 _ _ _ (by omega),
            eval_hist bga rs 16 6 _ r.draws r6 (by decide) hr6, Nat.zero_add]
      · show (if (j : ℕ) < c.sh.lt then algDrawAt U hist 5 j else algDrawAt U hist 7 ((j : ℕ) - c.sh.lt))
          = (((drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7, List.map_append,
          getD_app2 _ _ c.sh.lt (by simp [drs_len])]
        by_cases h1 : (j : ℕ) < c.sh.lt
        · rw [ite_eq_left h1, ite_eq_left h1, drs_getD _ 5 _ _ _ h1,
            eval_hist bga rs 16 5 _ r.draws r5 (by decide) hr5, Nat.zero_add]
        · rw [ite_eq_right h1, ite_eq_right h1, drs_getD _ 7 _ _ _ (by omega),
            eval_hist bga rs 16 7 _ r.draws r7 (by decide) hr7, Nat.zero_add]
    · rw [algH_gh U _ dt 16 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeR c P hc) dt 16 cu rt i
        = fun b => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 16 i (encR G 16 b)) := fun i => by
      rw [algM_mm _ dt 16 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeR c P hc) 16 hist 0 = fun t : Fin (segLn ((algShapeR c P hc).dl 16) .tau) =>
        if (t : ℕ) < c.sh.lt
        then (r5.draws.getD t Fp2.zero).toK U else (r6.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < c.sh.lt then algDrawAt U hist 5 t else algDrawAt U hist 6 ((t : ℕ) - c.sh.lt)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6]
    have hp1 : algPt U (algShapeR c P hc) 16 hist 1 = fun t : Fin (segLn ((algShapeR c P hc).dl 16) .tau) =>
        if (t : ℕ) < c.sh.lt
        then (r5.draws.getD t Fp2.zero).toK U else (r7.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < c.sh.lt then algDrawAt U hist 5 t else algDrawAt U hist 7 ((t : ℕ) - c.sh.lt)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7]
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .nu + 0) Fp2.zero).toK U = _
      rw [hoNu]
      rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by rw [hoNu, hsum]; omega)]
      show (r.draws.getD (segOff ((algShapeR c P hc).dl 16) .nu + 1) Fp2.zero).toK U = _
      rw [hoNu]
      rfl

end ZK60.Exec.Block.Join.R13H.Qkv
